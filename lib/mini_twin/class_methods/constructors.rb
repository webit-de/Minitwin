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
              model.instance_variables.each_with_object({}) do |var, hash|
                key = var.to_s.delete("@").to_sym
                hash[key] = model.instance_variable_get(var)
              end
            end
          end.reduce({}, :merge)

        # Enrich attributes with relation-style readers (e.g., has_one/has_many)
        # when they are not present in the model's attributes hash. This allows
        # nested block/twin properties and collections to be populated from
        # object readers commonly used by ORMs like ActiveRecord.
        begin
          properties.each do |prop, _meta|
            # Only enrich when attribute is missing or nil
            next if attributes.key?(prop) && !attributes[prop].nil?
            models.each_value do |model|
              next unless model.respond_to?(prop)
              val = model.public_send(prop)
              next if val.nil?
              attributes[prop] = val
              break
            end
          end

          collections.each_key do |coll|
            # Only enrich when attribute is missing or nil
            next if attributes.key?(coll) && !attributes[coll].nil?
            models.each_value do |model|
              next unless model.respond_to?(coll)
              val = model.public_send(coll)
              next if val.nil?
              attributes[coll] = val.respond_to?(:to_a) ? val.to_a : Array(val)
              break
            end
          end
        rescue StandardError
          # Be resilient to unexpected model behavior; proceed with best-effort enrichment
        end

        obj = new(**attributes)
        models.each { |name, model| obj.instance_variable_set(internal_model_name(name), model) }
        obj
      end

      def from_collection(models)
        models.map do |item|
          if item.respond_to?(:attributes)
            if item.respond_to?(:attribute_aliases)
              combined = item.attributes.dup
              item.attribute_aliases.each do |alias_name, real_attr|
                combined[alias_name] = item.public_send(real_attr)
              end
              new(**combined)
            else
              new(**item.attributes)
            end
          elsif item.respond_to?(:to_h)
            new(**item.to_h)
          elsif item.is_a?(Hash)
            new(**item)
          else
            attrs = item.instance_variables.each_with_object({}) do |var, hash|
              key = var.to_s.delete("@").to_sym
              hash[key] = item.instance_variable_get(var)
            end
            new(**attrs)
          end
        end
      end

      def internal_model_name(name)
        "@internal_model__#{name}" if name.present?
      end
    end
  end
end
