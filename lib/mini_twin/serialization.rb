class MiniTwin
  # Serialization to Hash/JSON and ActiveModel validation aggregation.
  # Converts nested twins recursively and preserves array items (dropping only
  # nil). When ActiveModel validations are available, nested errors are
  # surfaced on the parent using dot/bracket notation.
  module Serialization
    def to_hash(render_nil: false)
      klass = defined?(HashWithIndifferentAccess) ? HashWithIndifferentAccess : Hash

      klass.new.tap do |hash|
        methods_to_serialize = if self.class.respond_to?(:serializable_getters, true)
          self.class.send(:serializable_getters)
        else
          self.class.instance_methods(false).reject { |m| (s = m.to_s).end_with?("=") || s.end_with?("?") || s.end_with?("_attributes") }
        end

        methods_to_serialize.each do |method|
          value = send(method)
          next if value.nil? && !render_nil

          hash[method] =
            case value
            when MiniTwin
              value.to_hash
            when Array
              value.map { |item| item.respond_to?(:to_hash) ? item.to_hash : item }.compact
            else
              value
            end
        end
      end
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
  end
end
