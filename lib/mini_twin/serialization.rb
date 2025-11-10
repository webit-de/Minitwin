class MiniTwin
  # Serialization to Hash/JSON and ActiveModel validation aggregation.
  # Converts nested twins recursively and preserves array items (dropping only
  # nil). When ActiveModel validations are available, nested errors are
  # surfaced on the parent using dot/bracket notation.
  module Serialization
    private

    def transform_value_for_serialization(value)
      case value
      when MiniTwin
        value.to_hash
      when Array
        value.filter_map { |item| item.respond_to?(:to_hash) ? item.to_hash : item }
      else
        value
      end
    end

    public

    def to_hash(render_nil: false)
      klass = defined?(HashWithIndifferentAccess) ? HashWithIndifferentAccess : Hash
      hash = klass.new

      methods_to_serialize = if self.class.respond_to?(:serializable_getters, true)
        self.class.send(:serializable_getters)
      else
        self.class.instance_methods(false).reject { |m| (s = m.to_s).end_with?("=", "?", "_attributes") }
      end

      methods_to_serialize.each do |method|
        value = send(method)
        next if value.nil? && !render_nil

        hash[method] = transform_value_for_serialization(value)
      end

      # Include dynamic alias keys (defined per instance via `as: -> { ... }`).
      dynamic_aliases_var = MiniTwin::DYNAMIC_ALIASES_VAR
      if instance_variable_defined?(dynamic_aliases_var)
        aliases = instance_variable_get(dynamic_aliases_var)
        if aliases && !aliases.empty?
          aliases.each do |target_method, alias_method|
            # Skip nested proxy aliases at the top level; nested groups
            # serialize under their container key only.
            next if target_method.is_a?(Symbol) && target_method.to_s.start_with?(MiniTwin::NESTED_READER_PREFIX)

            # Read the value from the original target method to avoid issues if
            # the alias method is overridden. Apply the same transformation rules
            # as above for nested twins and arrays.
            value = send(target_method)
            next if value.nil? && !render_nil

            hash[alias_method] = transform_value_for_serialization(value)
          end
        end
      end

      hash
    end

    alias_method :to_h, :to_hash

    def to_json(**opts)
      to_hash(**opts).to_json
    end

    def attributes
      # Use setter-based attribute names and read via `send` to allow
      # accessing protected original readers when aliases (`as:`) are used.
      attribute_methods.each_with_object({}) do |m, h|
        h[m] = send(m) if respond_to?(m, true)
      end
    end

    def valid?
      # If ActiveModel validations are available and included, run them and
      # aggregate nested errors. Otherwise, consider the twin valid.
      if defined?(ActiveModel::Validations) && self.class.ancestors.include?(ActiveModel::Validations)
        super

        self.class.block_properties.each do |property|
          child = self.send(property)
          next unless child.respond_to?(:valid?)
          child.valid?
          child.errors.each do |attribute|
            errors.add("#{property}.#{attribute.attribute}", attribute.message)
          end
        end

        self.class.collection_properties.each do |property|
          self.send(property).each_with_index do |value, index|
            next unless value.respond_to?(:valid?)
            value.valid?
            value.errors.each do |attribute|
              errors.add("#{property}[#{index}].#{attribute.attribute}", attribute.message)
            end
          end
        end

        errors.empty?
      else
        true
      end
    end

    def inspect
      attrs = to_hash.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      "#<#{self.class.name} #{attrs}>"
    end

    def pretty_print(q)
      q.object_group(self) do
        q.breakable

        # Get methods to serialize (same as to_hash logic)
        methods_to_serialize = if self.class.respond_to?(:serializable_getters, true)
          self.class.send(:serializable_getters)
        else
          self.class.instance_methods(false).reject { |m| (s = m.to_s).end_with?("=", "?", "_attributes") }
        end

        # Pretty print each attribute
        q.seplist(methods_to_serialize, lambda { q.text(','); q.breakable }) do |method|
          value = send(method)
          q.group do
            q.text method.to_s
            q.text ': '
            q.pp value
          end
        end

        # Include dynamic aliases if present
        dynamic_aliases_var = MiniTwin::DYNAMIC_ALIASES_VAR
        if instance_variable_defined?(dynamic_aliases_var)
          aliases = instance_variable_get(dynamic_aliases_var)
          if aliases && !aliases.empty?
            aliases.each do |target_method, alias_method|
              # Skip nested proxy aliases
              next if target_method.is_a?(Symbol) && target_method.to_s.start_with?(MiniTwin::NESTED_READER_PREFIX)

              value = send(target_method)
              q.text ','
              q.breakable
              q.group do
                q.text alias_method.to_s
                q.text ': '
                q.pp value
              end
            end
          end
        end
      end
    end

  end
end
