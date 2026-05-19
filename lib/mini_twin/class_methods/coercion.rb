class Minitwin
  module ClassMethods
    module Coercion
      private

      # Iterate over all attribute sources (properties, collections, and allowed keys)
      # for a target class, yielding each key to the block
      def iterate_attribute_sources(target_klass, &block)
        return unless target_klass
        return unless target_klass.respond_to?(:allowed_attribute_keys, true)

        target_klass.send(:allowed_attribute_keys).each(&block)
      end

      def coerce_value_to_twin(value, target_klass)
        return nil if value.nil?
        return value unless target_klass
        return value if value.is_a?(target_klass)

        # Check array pair format before to_h (arrays respond to :to_h in Ruby 3+)
        return coerce_from_array_pair(value, target_klass) if array_pair_format?(value)
        # Try standard conversion methods
        return coerce_from_to_h(value, target_klass) if value.respond_to?(:to_h) && !value.is_a?(Array)
        return coerce_from_attributes(value, target_klass) if value.respond_to?(:attributes)
        return target_klass.new(**value) if value.is_a?(Hash)

        # Fallback: reflect by reading known properties or instance variables
        coerce_by_reflection(value, target_klass)
      end

      def coerce_from_to_h(value, target_klass)
        attrs = value.to_h
        enrich_attrs_from_readers!(attrs, value, target_klass)
        target_klass.new(**attrs)
      end

      def coerce_from_attributes(value, target_klass)
        attrs = value.attributes
        enrich_attrs_from_readers!(attrs, value, target_klass)
        target_klass.new(**attrs)
      end

      def array_pair_format?(value)
        value.is_a?(Array) && value.size == 2 && value.last.is_a?(Hash)
      end

      def coerce_from_array_pair(value, target_klass)
        target_klass.new(**value.last)
      end

      def coerce_by_reflection(value, target_klass)
        attrs = extract_attrs_by_reflection(value, target_klass)
        attrs = extract_instance_variables(value) if attrs.empty?
        attrs.empty? ? value : target_klass.new(**attrs)
      end

      def extract_attrs_by_reflection(value, target_klass)
        attrs = {}
        begin
          iterate_attribute_sources(target_klass) do |key|
            next if attrs.key?(key)
            attrs[key] = value.public_send(key) if value.respond_to?(key)
          end
        rescue StandardError => e
          # Expected: Reflection may fail if source object raises in attribute readers
          # or has unexpected behavior. Continue with partial attributes.
        end
        attrs
      end

      def extract_instance_variables(value)
        return {} unless value.respond_to?(:instance_variables) && value.instance_variables.any?

        value.instance_variables.each_with_object({}) do |var, attrs|
          attrs[Minitwin::Utils.ivar_to_key(var)] = value.instance_variable_get(var)
        end
      end

      def enrich_attrs_from_readers!(attrs, source, target_klass)
        return attrs unless target_klass

        begin
          # Enrich from properties and allowed attribute keys
          iterate_attribute_sources(target_klass) do |key|
            next if attrs.key?(key) && !attrs[key].nil?
            next unless source.respond_to?(key)

            # Special handling for collections to ensure array coercion
            if target_klass.respond_to?(:collections) && target_klass.collections.key?(key)
              attrs[key] = coerce_collection_array(source.public_send(key))
            else
              attrs[key] = source.public_send(key)
            end
          end
        rescue StandardError => e
          # Expected: Source object may raise in attribute readers or have
          # unexpected behavior. Be resilient and proceed with partial attributes.
        end

        attrs
      end

      def coerce_collection_array(raw)
        return raw if raw.is_a?(Array)
        return raw.to_a if raw.respond_to?(:to_a)
        Array(raw)
      end
    end
  end
end
