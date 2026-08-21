# frozen_string_literal: true
# rbs_inline: enabled

class Minitwin
  # Instance construction and low-level helpers used by the DSL-generated
  # accessors. Filters unknown keys on initialize and seeds nested block
  # properties so that validations on nested twins can run.
  module Initialization
    # Cache constant references for JIT optimization
    ALIASES_VAR = Minitwin::DYNAMIC_ALIASES_VAR
    ALIASES_REV_VAR = Minitwin::DYNAMIC_ALIASES_REV_VAR

    # Forbidden method names that should never be aliased for security reasons
    FORBIDDEN_ALIAS_NAMES = %i[
      eval instance_eval class_eval module_eval
      send __send__ public_send
      method_missing respond_to_missing?
      define_method remove_method undef_method
      instance_variable_get instance_variable_set
      instance_variables instance_variable_defined?
      const_get const_set
      class_variable_get class_variable_set
      binding tap then yield_self to_proc
      freeze __id__ object_id
      == equal? eql? hash <=>
    ].freeze

    #: (**untyped) -> instance
    def initialize(**args)
      allowed_keys = self.class.send(:allowed_attribute_keys)

      deferred = args.reject { |arg, _| allowed_keys.include?(arg.to_sym) } if self.class.dynamic_aliases?

      args.select! { |arg, _| allowed_keys.include?(arg.to_sym) }

      getter_defaults = {}
      self.class.block_properties.each do |method|
        getter_defaults[method] = {} if allowed_keys.include?(method)
      end

      attrs = getter_defaults.merge(args)

      # Skip per-setter alias recomputation during bulk init; recompute once after
      @__skip_alias_recompute__ = true
      if Minitwin.send(:active_model_initialized?, self.class)
        super(attrs)
      else
        # :nocov: (exercised only without ActiveModel; covered by subprocess test)
        attrs.each { |k, v| assign_attribute(method: k, value: v) }
        # :nocov:
      end
      @__skip_alias_recompute__ = false

      return unless self.class.dynamic_aliases?

      __recompute_dynamic_aliases__
      __assign_dynamic_alias_keys__(deferred)
    end

    #: () -> Hash[Symbol, Symbol]
    def dynamic_aliases
      return {} unless instance_variable_defined?(ALIASES_REV_VAR) && instance_variable_get(ALIASES_REV_VAR)

      instance_variable_get(ALIASES_REV_VAR).dup
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
      self.class.send(:allowed_attribute_keys_array)
    end

    def define_instance_variable(name:, value:)
      instance_variable_set(Minitwin::Utils.ivar_name(name), value)
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

    def __assign_dynamic_alias_keys__(hash, allowed: nil)
      return if hash.nil? || hash.empty?

      hash.each do |key, value|
        target = __dynamic_alias_target__(key)
        next if target.nil?
        next if allowed && !allowed.include?(target)
        next unless respond_to?("#{target}=", true)

        send("#{target}=", value)
      end
    end

    def __dynamic_alias_target__(key)
      return nil unless instance_variable_defined?(ALIASES_REV_VAR)

      target = instance_variable_get(ALIASES_REV_VAR)[key.to_sym]
      return nil if target.nil?
      return target unless target.to_s.start_with?(Minitwin::NESTED_READER_PREFIX)

      entry = self.class.dynamic_nested_aliases.find { |e| e[:target] == target }
      entry && entry[:path].last
    end

    def __compute_alias_name__(as_proc)
      instance_exec(&as_proc)
    rescue StandardError
      # Expected: Dynamic alias proc may fail or return invalid names.
      # Return nil to skip this alias definition.
      nil
    end

    def __compute_nested_alias_name__(entry)
      obj = send(entry[:group])
      obj = Minitwin::Utils.traverse_path(obj, entry[:path][0..-2])
      obj.instance_exec(&entry[:as])
    rescue StandardError
      # Expected: Nested path traversal or dynamic alias proc may fail.
      # Return nil to skip this alias definition.
      nil
    end

    def __apply_dynamic_alias__(target_method, alias_name)
      unless alias_name.is_a?(String) || alias_name.is_a?(Symbol)
        raise ArgumentError, "Invalid alias name #{alias_name.inspect}: must be a String or Symbol"
      end

      alias_key = alias_name.to_sym
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
  end
end
