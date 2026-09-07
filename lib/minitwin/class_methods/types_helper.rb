# frozen_string_literal: true

class Minitwin
  module ClassMethods
    module TypesHelper
      private

      def dry_type_primitive(type)
        return nil unless type.respond_to?(:primitive)

        type.primitive
      end

      def type_default_value(type)
        primitive_class = dry_type_primitive(type)

        # :nocov:
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
        # Build type description from multiple sources for better inference
        parts = [type.to_s, type.class.name]
        begin
          parts << type.inspect
        rescue StandardError
          # Type.inspect may fail for some custom types
        end
        type_description = parts.compact.join(" ")

        return 0 if type_description.include?("Integer")
        return "" if type_description.include?("String")
        return false if type_description.include?("Bool")

        nil
      rescue StandardError
        # Expected: Type introspection may fail for custom or complex types.
        # Return nil as a safe default.
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
      rescue Minitwin::Error
        # Re-raise: a Minitwin::Error (e.g. from a custom type: callable) must propagate
        # instead of being swallowed by the broader rescue below, which is for ordinary
        # coercion failures only. CoercionError/AliasError/ParseError/DefinitionError are
        # all TypeError/ArgumentError subclasses, so this clause has to come first.
        raise
      rescue *Minitwin.send(:coercion_error_classes)
        raw_value
      end
    end
  end
end
