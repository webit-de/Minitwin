class MiniTwin
  # Instance construction and low-level helpers used by the DSL-generated
  # accessors. Filters unknown keys on initialize and seeds nested block
  # properties so that validations on nested twins can run.
  module Initialization
    def initialize(**args)
      # Filter only attributes that have corresponding writer methods on this class
      allowed_keys = (
        if self.class.respond_to?(:allowed_attribute_keys)
          self.class.allowed_attribute_keys
        else
          self.class.instance_methods(false).grep(/=\z/).map { |m| m.to_s.delete_suffix("=").to_sym }.to_set
        end
      )
      args.select! { |arg, _| allowed_keys.include?(arg.to_sym) }

      getter_defaults =
        self.
          class.
          block_properties.
          select { |method| allowed_keys.include?(method) }.
          index_with { {} }

      super(**getter_defaults.merge(args))

      # Establish any dynamic alias methods after initialization
      __recompute_dynamic_aliases__ if respond_to?(:__recompute_dynamic_aliases__, true)
    end

    private

    def assign_attribute(method:, value:)
      if respond_to?("#{method}=")
        send("#{method}=", value)
      else
        instance_variable_set("@#{method}", value)
      end
    end

    def attribute_methods
      # Prefer class-level cache of allowed attribute keys (setter names
      # without the trailing '='). This ensures aliased properties (where the
      # original reader is protected) are still considered assignable.
      if self.class.respond_to?(:allowed_attribute_keys, true)
        self.class.send(:allowed_attribute_keys).to_a
      else
        public_methods(false).select do |method|
          method_name = method.to_s
          next false if method_name.end_with?("=", "?", "!")

          respond_to?(:"#{method}=")
        end
      end
    end

    def define_instance_variable(name:, value:)
      instance_variable_set("@#{name}".delete_suffix("?"), value)
    end

    # Define or update per-instance alias methods for properties/collections
    # where `as:` was provided as a Proc. The Proc is executed in the context
    # of the instance to compute the alias name.
    def __recompute_dynamic_aliases__
      @__dynamic_aliases__ ||= {}
      @__dynamic_aliases_rev__ ||= {}

      # Handle scalar properties
      if self.class.respond_to?(:properties)
        self.class.properties.each do |prop, meta|
          as_meta = meta[:as]
          next unless as_meta.is_a?(Proc)

          begin
            alias_name = instance_exec(&as_meta)
          rescue StandardError
            next
          end
          next if alias_name.nil?

          __apply_dynamic_alias__(prop, alias_name)
        end
      end

      # Handle collections
      if self.class.respond_to?(:collections)
        self.class.collections.each do |coll, meta|
          as_meta = meta[:as]
          next unless as_meta.is_a?(Proc)

          begin
            alias_name = instance_exec(&as_meta)
          rescue StandardError
            next
          end
          next if alias_name.nil?

          __apply_dynamic_alias__(coll, alias_name)
        end
      end

      # Handle nested dynamic aliases (registered by DSL#nested)
      if self.class.respond_to?(:dynamic_nested_aliases)
        self.class.dynamic_nested_aliases.each do |entry|
          as_meta = entry[:as]
          target = entry[:target]
          if as_meta.is_a?(Proc)
            begin
              obj = public_send(entry[:group])
              entry[:path][0..-2].each { |seg| obj = obj.public_send(seg) }
              alias_name = obj.instance_exec(&as_meta)
            rescue StandardError
              next
            end
            next if alias_name.nil?
            __apply_dynamic_alias__(target, alias_name)
          else
            # Static alias recorded by nested to support protected inner readers
            __apply_dynamic_alias__(target, as_meta)
          end
        end
      end
    end

    def __apply_dynamic_alias__(target_method, alias_name)
      alias_key = alias_name.to_sym rescue alias_name

      prev = @__dynamic_aliases__[target_method]
      if prev && prev != alias_key
        begin
          singleton_class.send(:remove_method, prev)
        rescue NameError
        end
        @__dynamic_aliases_rev__.delete(prev)
      end

      # Collision checks: alias already used by another target or an existing method
      if @__dynamic_aliases_rev__.key?(alias_key) && @__dynamic_aliases_rev__[alias_key] != target_method
        raise ArgumentError, "Dynamic alias '#{alias_key}' already defined for '#{@__dynamic_aliases_rev__[alias_key]}'"
      end

      if (respond_to?(alias_key, true) || respond_to?(alias_key, false)) && @__dynamic_aliases_rev__[alias_key] != target_method
        raise ArgumentError, "Cannot define dynamic alias '#{alias_key}': method already exists"
      end

      # Define forwarding method on the singleton class
      singleton_class.send(:define_method, alias_key) do
        send(target_method)
      end

      @__dynamic_aliases__[target_method] = alias_key
      @__dynamic_aliases_rev__[alias_key] = target_method
    end

    # Public: expose current dynamic aliases as a Hash of alias_name => target_method
    def dynamic_aliases
      return {} unless instance_variable_defined?(:@__dynamic_aliases_rev__) && @__dynamic_aliases_rev__
      @__dynamic_aliases_rev__.dup
    end
  end
end
