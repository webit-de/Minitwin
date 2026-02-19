class MiniTwin
  # Instance construction and low-level helpers used by the DSL-generated
  # accessors. Filters unknown keys on initialize and seeds nested block
  # properties so that validations on nested twins can run.
  module Initialization
    # Cache constant references for JIT optimization
    ALIASES_VAR = MiniTwin::DYNAMIC_ALIASES_VAR
    ALIASES_REV_VAR = MiniTwin::DYNAMIC_ALIASES_REV_VAR
    def initialize(**args)
      # Filter only attributes that have corresponding writer methods on this class
      allowed_keys = if self.class.respond_to?(:allowed_attribute_keys, true)
        self.class.send(:allowed_attribute_keys)
      else
        self.class.instance_methods(false).grep(/=\z/).map { |m| m.to_s.delete_suffix("=").to_sym }.to_set
      end

      args.select! { |arg, _| allowed_keys.include?(arg.to_sym) }

      getter_defaults =
        self.
          class.
          block_properties.
          select { |method| allowed_keys.include?(method) }.
          index_with { {} }

      super(getter_defaults.merge(args))

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
      instance_variable_set(MiniTwin::Utils.ivar_name(name), value)
    end

    # Define or update per-instance alias methods for properties/collections
    # where `as:` was provided as a Proc. The Proc is executed in the context
    # of the instance to compute the alias name.
    def __recompute_dynamic_aliases__
      instance_variable_set(ALIASES_VAR, {}) unless instance_variable_defined?(ALIASES_VAR)
      instance_variable_set(ALIASES_REV_VAR, {}) unless instance_variable_defined?(ALIASES_REV_VAR)

      # Handle scalar properties and collections
      __recompute_aliases_for_collection__(:properties)
      __recompute_aliases_for_collection__(:collections)

      # Handle nested dynamic aliases (registered by DSL#nested)
      __recompute_nested_aliases__
    end

    def __recompute_aliases_for_collection__(collection_method)
      return unless self.class.respond_to?(collection_method)

      self.class.public_send(collection_method).each do |key, meta|
        as_meta = meta[:as]
        next unless as_meta.is_a?(Proc)

        alias_name = __compute_alias_name__(as_meta)
        next if alias_name.nil?

        __apply_dynamic_alias__(key, alias_name)
      end
    end

    def __recompute_nested_aliases__
      return unless self.class.respond_to?(:dynamic_nested_aliases)

      self.class.dynamic_nested_aliases.each do |entry|
        as_meta = entry[:as]
        target = entry[:target]

        if as_meta.is_a?(Proc)
          alias_name = __compute_nested_alias_name__(entry)
          next if alias_name.nil?
          __apply_dynamic_alias__(target, alias_name)
        else
          # Static alias recorded by nested to support protected inner readers
          __apply_dynamic_alias__(target, as_meta)
        end
      end
    end

    def __compute_alias_name__(as_proc)
      instance_exec(&as_proc)
    rescue StandardError => e
      # Expected: Dynamic alias proc may fail or return invalid names.
      # Return nil to skip this alias definition.
      nil
    end

    def __compute_nested_alias_name__(entry)
      obj = public_send(entry[:group])
      entry[:path][0..-2].each { |seg| obj = obj.public_send(seg) }
      obj.instance_exec(&entry[:as])
    rescue StandardError => e
      # Expected: Nested path traversal or dynamic alias proc may fail.
      # Return nil to skip this alias definition.
      nil
    end

    # Forbidden method names that should never be aliased for security reasons
    FORBIDDEN_ALIAS_NAMES = %i[
      eval instance_eval class_eval module_eval
      send __send__ public_send
      method_missing respond_to_missing?
      define_method remove_method undef_method
      instance_variable_get instance_variable_set
      const_get const_set
      class_variable_get class_variable_set
    ].freeze

    def __apply_dynamic_alias__(target_method, alias_name)
      alias_key = begin
        alias_name.to_sym
      rescue NoMethodError
        alias_name
      end
      aliases = instance_variable_get(ALIASES_VAR)
      aliases_rev = instance_variable_get(ALIASES_REV_VAR)

      # Security check: prevent aliasing to forbidden method names
      if FORBIDDEN_ALIAS_NAMES.include?(alias_key)
        raise ArgumentError, "Cannot define dynamic alias '#{alias_key}': forbidden method name for security reasons"
      end

      prev = aliases[target_method]
      if prev && prev != alias_key
        begin
          singleton_class.send(:remove_method, prev)
        rescue NameError
          # Expected: method may not exist if previously failed to define
        end
        aliases_rev.delete(prev)
      end

      # Collision checks: alias already used by another target or an existing method
      if aliases_rev.key?(alias_key) && aliases_rev[alias_key] != target_method
        raise ArgumentError, "Dynamic alias '#{alias_key}' already defined for '#{aliases_rev[alias_key]}'"
      end

      if respond_to?(alias_key, true) && aliases_rev[alias_key] != target_method
        raise ArgumentError, "Cannot define dynamic alias '#{alias_key}': method already exists"
      end

      # Define forwarding method on the singleton class
      singleton_class.send(:define_method, alias_key) do
        send(target_method)
      end

      aliases[target_method] = alias_key
      aliases_rev[alias_key] = target_method
    end

    # Public: expose current dynamic aliases as a Hash of alias_name => target_method
    def dynamic_aliases
      return {} unless instance_variable_defined?(ALIASES_REV_VAR) && instance_variable_get(ALIASES_REV_VAR)
      instance_variable_get(ALIASES_REV_VAR).dup
    end
  end
end
