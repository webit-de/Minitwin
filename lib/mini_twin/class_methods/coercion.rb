class MiniTwin
  module ClassMethods
    module Coercion
      private

      def coerce_value_to_twin(value, target_klass)
        return nil if value.nil?
        return value if target_klass && value.is_a?(target_klass)
        return target_klass.new(**value.to_h) if target_klass && value.respond_to?(:to_h)
        return target_klass.new(**value.attributes) if target_klass && value.respond_to?(:attributes)
        if target_klass && value.is_a?(Array) && value.size == 2 && value.last.is_a?(Hash)
          return target_klass.new(**value.last)
        end
        if target_klass && value.is_a?(Hash)
          return target_klass.new(**value)
        end

        # Fallback: reflect by reading known properties or instance variables
        if target_klass
          attrs = {}
          begin
            if target_klass.respond_to?(:properties)
              target_klass.properties.each_key do |k|
                attrs[k] = value.public_send(k) if value.respond_to?(k)
              end
            end
          rescue StandardError
          end

          if attrs.empty? && value.respond_to?(:instance_variables) && value.instance_variables.any?
            value.instance_variables.each do |var|
              key = var.to_s.delete("@").to_sym
              attrs[key] = value.instance_variable_get(var)
            end
          end

          return (attrs.empty? ? value : target_klass.new(**attrs))
        end

        value
      end

      def coerce_collection_array(raw)
        raw.is_a?(Array) ? raw : (raw.respond_to?(:to_a) ? raw.to_a : Array(raw))
      end
    end
  end
end

