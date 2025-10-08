class MiniTwin
  module ClassMethods
    module TypesHelper
      private

      def dry_type_primitive(t)
        if t.respond_to?(:primitive) && t.primitive
          t.primitive
        else
          nil
        end
      end

      def type_default_value(t)
        prim = dry_type_primitive(t)
        case prim
        when Integer
          return 0
        when String
          return ""
        when TrueClass, FalseClass
          return false
        end

        begin
          blob = [t.to_s, (t.inspect rescue nil), t.class.name].compact.join(' ')
          return 0 if blob.include?('Integer')
          return "" if blob.include?('String')
          return false if blob.include?('Bool')
        rescue StandardError
        end

        nil
      end

      def coerce_with_type(raw, type)
        begin
          coerced = type ? type.call(raw) : raw
        rescue ::Dry::Types::CoercionError, TypeError, ArgumentError
          coerced = raw
        end
        prim = dry_type_primitive(type)
        if (!raw.nil?) && !coerced.is_a?(String) && (prim == String)
          coerced = raw.to_s
        end
        coerced
      end
    end
  end
end
