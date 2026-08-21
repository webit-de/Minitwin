# frozen_string_literal: true
# rbs_inline: enabled

class Minitwin
  module ClassMethods
    module Constructors

      #: () -> Hash[untyped, untyped]
      def properties
        @properties ||= {}
      end

      #: () -> Hash[untyped, untyped]
      def collections
        @collections ||= {}
      end

      #: (Hash[untyped, untyped] args) -> instance
      def from_hash(args)
        new(**args)
      end

      #: (String body) -> instance
      def from_json(body)
        hash = JSON.parse(body, symbolize_names: true)
        from_hash(hash)
      end

      # Actually, this is expected to be an `ActionController::Parameters`
      # object. The type will be unknown when used without rails. So for RBS
      # the argument is typed `untyped`.
      #: (untyped params) -> instance
      def from_params(params)
        return from_hash(params) unless params.respond_to?(:to_unsafe_h)

        from_hash params.to_unsafe_h
      end

      #: (untyped model) -> instance
      def from_object(model)
        if model.is_a?(Hash)
          raise(
            "Input is not an object. If you want to instantiate a Minitwin with multiple " \
              "objects, then use the pluralized 'from_objects'-method."
          )
        end

        from_objects(model:)
      end

      #: (Hash[Symbol, untyped] **models) -> instance
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

      #: (Array[untyped] models) -> Array[instance]
      def from_collection(models)
        models.map { |item| from_objects(model: item) }
      end

      #: (Symbol name) -> String | nil
      def internal_model_name(name)
        "#{Minitwin::INTERNAL_MODEL_PREFIX}#{name}" unless name.nil?
      end

      #: (Symbol name) -> Symbol
      def model_attribute_name(name)
        meta = properties[name] || collections[name]
        Minitwin::Utils.model_attribute_name(name, meta && meta[:as])
      end

      def enrich_attributes_from_models!(attributes, models)
        properties.each_key do |key|
          enrich_attribute_from_models(attributes, models, key, is_collection: false)
        end

        collections.each_key do |key|
          enrich_attribute_from_models(attributes, models, key, is_collection: true)
        end
      rescue StandardError
        # Expected: Model objects may raise in attribute readers or have unexpected
        # behavior. Be resilient and proceed with best-effort enrichment.
      end

      def enrich_attribute_from_models(attributes, models, key, is_collection:)
        # Only enrich when attribute is missing or nil
        return if attributes.key?(key) && !attributes[key].nil?

        models.each_value do |model|
          reader = model_reader_for(model, key)
          next unless reader

          val = model.public_send(reader)
          next if val.nil?

          attributes[key] = is_collection ? coerce_collection_array(val) : val
          break
        end
      end

      #: (untyped model, Symbol name) -> Symbol?
      def model_reader_for(model, name)
        aliased = model_attribute_name(name)
        return aliased if model.respond_to?(aliased)

        name if model.respond_to?(name)
      end
    end
  end
end
