class MiniTwin
  module ClassMethods
    module TypesHelper
      private

      def dry_type_primitive(type)
        return nil unless type.respond_to?(:primitive)
        type.primitive
      end

      def type_default_value(type)
        primitive_class = dry_type_primitive(type)

        case primitive_class
        when Integer then 0
        when String then ""
        when TrueClass, FalseClass then false
        else
          # Fallback: inspect type representation for hints
          infer_default_from_type_string(type)
        end
      end

      def infer_default_from_type_string(type)
        type_description = [type.to_s, (type.inspect rescue nil), type.class.name].compact.join(' ')
        return 0 if type_description.include?('Integer')
        return "" if type_description.include?('String')
        return false if type_description.include?('Bool')
        nil
      rescue StandardError
        nil
      end

      def coerce_with_type(raw_value, type)
        coerced = attempt_type_coercion(raw_value, type)
        primitive_class = dry_type_primitive(type)

        # Force string conversion if type is String but coercion didn't produce one
        if raw_value && !coerced.is_a?(String) && primitive_class == String
          coerced = raw_value.to_s
        end

        coerced
      end

      def attempt_type_coercion(raw_value, type)
        return raw_value unless type
        type.call(raw_value)
      rescue ::Dry::Types::CoercionError, TypeError, ArgumentError
        raw_value
      end
    end
  end
end
