class MiniTwin
  module ClassMethods
    module Constructors
      def properties
        @properties ||= {}
      end

      def collections
        @collections ||= {}
      end

      def from_hash(args)
        new(**args)
      end

      def from_json(body)
        hash = JSON.parse(body, symbolize_names: true)
        from_hash(hash)
      end

      def from_params(params)
        return from_hash(params) unless params.respond_to?(:to_unsafe_h)
        from_hash params.to_unsafe_h
      end

      def from_object(model)
        raise "Input is not an object. If you want to instantiate a MiniTwin with multiple objects, then use the pluralized 'from_objects'-method." if model.is_a?(Hash)
        from_objects(model:)
      end

      def from_objects(**models)
        attributes =
          models.values.map do |model|
            if model.respond_to?(:attributes) && model.respond_to?(:attribute_aliases)
              combined_attributes = model.attributes.dup
              model.attribute_aliases.each do |alias_name, real_attr|
                combined_attributes[alias_name] = model.send(real_attr)
              end
              combined_attributes
            elsif model.respond_to?(:to_h)
              model.to_h
            elsif model.respond_to?(:attributes)
              model.attributes
            else
              extract_instance_variables(model)
            end
          end.reduce({}, :merge)

        # Enrich attributes with relation-style readers (e.g., has_one/has_many)
        # when they are not present in the model's attributes hash. This allows
        # nested block/twin properties and collections to be populated from
        # object readers commonly used by ORMs like ActiveRecord.
        enrich_attributes_from_models!(attributes, models)

        obj = new(**attributes)
        models.each { |name, model| obj.instance_variable_set(internal_model_name(name), model) }
        obj
      end

      def from_collection(models)
        models.map { |item| from_objects(model: item) }
      end

      def internal_model_name(name)
        "#{MiniTwin::INTERNAL_MODEL_PREFIX}#{name}" unless name.nil?
      end

      def enrich_attributes_from_models!(attributes, models)
        begin
          properties.each_key do |key|
            enrich_attribute_from_models(attributes, models, key, is_collection: false)
          end

          collections.each_key do |key|
            enrich_attribute_from_models(attributes, models, key, is_collection: true)
          end
        rescue StandardError => e
          # Expected: Model objects may raise in attribute readers or have unexpected
          # behavior. Be resilient and proceed with best-effort enrichment.
        end
      end

      def enrich_attribute_from_models(attributes, models, key, is_collection:)
        # Only enrich when attribute is missing or nil
        return if attributes.key?(key) && !attributes[key].nil?

        models.each_value do |model|
          next unless model.respond_to?(key)
          val = model.public_send(key)
          next if val.nil?

          attributes[key] = is_collection ? coerce_collection_array(val) : val
          break
        end
      end
    end
  end
end
