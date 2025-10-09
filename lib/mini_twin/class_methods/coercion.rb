class MiniTwin
  module ClassMethods
    module Coercion
      private

      def coerce_value_to_twin(value, target_klass)
        return nil if value.nil?
        return value if target_klass && value.is_a?(target_klass)
        if target_klass && value.respond_to?(:to_h)
          attrs = value.to_h
          enrich_attrs_from_readers!(attrs, value, target_klass)
          return target_klass.new(**attrs)
        end
        if target_klass && value.respond_to?(:attributes)
          attrs = value.attributes
          enrich_attrs_from_readers!(attrs, value, target_klass)
          return target_klass.new(**attrs)
        end
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
            if target_klass.respond_to?(:collections)
              target_klass.collections.each_key do |k|
                attrs[k] = value.public_send(k) if value.respond_to?(k)
              end
            end

            # Also map any direct setters (e.g., nested group leaf setters like `tag=`)
            if target_klass.respond_to?(:allowed_attribute_keys, true)
              target_klass.send(:allowed_attribute_keys).each do |k|
                next if attrs.key?(k)
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

      def enrich_attrs_from_readers!(attrs, source, target_klass)
        begin
          if target_klass.respond_to?(:properties)
            target_klass.properties.each_key do |k|
              next if attrs.key?(k) && !attrs[k].nil?
              attrs[k] = source.public_send(k) if source.respond_to?(k)
            end
          end
          if target_klass.respond_to?(:collections)
            target_klass.collections.each_key do |k|
              next if attrs.key?(k) && !attrs[k].nil?
              if source.respond_to?(k)
                v = source.public_send(k)
                attrs[k] = coerce_collection_array(v)
              end
            end
          end
          if target_klass.respond_to?(:allowed_attribute_keys, true)
            target_klass.send(:allowed_attribute_keys).each do |k|
              next if attrs.key?(k) && !attrs[k].nil?
              attrs[k] = source.public_send(k) if source.respond_to?(k)
            end
          end
        rescue StandardError
        end
        attrs
      end

      def coerce_collection_array(raw)
        raw.is_a?(Array) ? raw : (raw.respond_to?(:to_a) ? raw.to_a : Array(raw))
      end
    end
  end
end
