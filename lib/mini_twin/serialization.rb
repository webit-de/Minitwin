class MiniTwin
  module Serialization
    def to_hash(render_nil: false)
      klass = defined?(HashWithIndifferentAccess) ? HashWithIndifferentAccess : Hash

      klass.new.tap do |hash|
        virtual_props = self.class.virtual_properties.to_set

        self.class.instance_methods(false).each do |method|
          next if method.end_with?("=") || method.end_with?("?") || method.end_with?("_attributes")
          next if virtual_props.include?(method) || protected_methods(false).include?(method)

          value = send(method)
          next if value.nil? && !render_nil

          hash[method] =
            case value
            when MiniTwin
              value.to_hash
            when Array
              value.filter_map { |item| item.respond_to?(:to_hash) ? item.to_hash : item.presence }
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
      attribute_methods.index_with { |m| public_send(m) }
    end

    def valid?
      # If ActiveModel validations are available and included, run them and
      # aggregate nested errors. Otherwise, consider the twin valid.
      if defined?(ActiveModel::Validations) && self.class.ancestors.include?(ActiveModel::Validations)
        super

        self.class.block_properties.each do |property|
          self.send(property).valid?
          self.send(property).errors.each do |attribute|
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
