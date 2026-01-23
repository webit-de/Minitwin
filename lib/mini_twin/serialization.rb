class MiniTwin
  # Serialization to Hash/JSON and ActiveModel validation aggregation.
  # Converts nested twins recursively and preserves array items (dropping only
  # nil). When ActiveModel validations are available, nested errors are
  # surfaced on the parent using dot/bracket notation.
  module Serialization

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
        # When ActiveModel is not available, consider the twin valid by default.
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
        q.seplist(ordered_attributes_for_pp, lambda { q.text(','); q.breakable }) do |(name, value)|
          q.group do
            q.text name.to_s
            q.text ': '
            q.pp value
          end
        end
      end
    end

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

    def ordered_attributes_for_pp
      methods = ordered_methods_for_pp
      attrs = methods.map { |m| [display_name_for(m), send(m)] }
      attrs + dynamic_aliases_for_pp
    end

    def ordered_methods_for_pp
      ordered = self.class.respond_to?(:property_order, true) ? self.class.send(:property_order) : []
      all_methods = self.class.respond_to?(:serializable_getters, true) ?
        self.class.send(:serializable_getters) :
        self.class.instance_methods(false).reject { |m| m.to_s.end_with?("=", "?", "_attributes") }

      ordered.select { |m| all_methods.include?(m) } + (all_methods - ordered)
    end

    def display_name_for(method)
      props = self.class.respond_to?(:properties, true) ? self.class.send(:properties) : {}
      colls = self.class.respond_to?(:collections, true) ? self.class.send(:collections) : {}

      meta = props[method] || colls[method]
      (meta && meta[:as] && !meta[:as].is_a?(Proc)) ? meta[:as] : method
    end

    def dynamic_aliases_for_pp
      return [] unless instance_variable_defined?(MiniTwin::DYNAMIC_ALIASES_VAR)

      aliases = instance_variable_get(MiniTwin::DYNAMIC_ALIASES_VAR)
      return [] unless aliases && !aliases.empty?

      aliases.filter_map do |target_method, alias_method|
        next if target_method.is_a?(Symbol) && target_method.to_s.start_with?(MiniTwin::NESTED_READER_PREFIX)
        [alias_method, send(target_method)]
      end
    end

  end
end
