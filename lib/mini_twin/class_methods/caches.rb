class MiniTwin
  module ClassMethods
    module Caches
      private

      def invalidate_caches
        @serializable_getters_cache = nil
        @allowed_attribute_keys_cache = nil
        @allowed_attribute_keys_array_cache = nil
        @setter_methods_cache = nil
      end

      def serializable_getters
        @serializable_getters_cache ||= begin
          virt = virtual_properties.to_set
          prot = protected_instance_methods(false).to_set
          instance_methods(false).reject do |m|
            s = m.to_s
            s.end_with?("=", "?", "_attributes") || virt.include?(m) || prot.include?(m)
          end
        end
      end

      def allowed_attribute_keys
        @allowed_attribute_keys_cache ||= begin
          # Include methods from this class and parent MiniTwin subclasses,
          # but not from MiniTwin itself or its ancestors (Object, etc.)
          own_and_inherited = instance_methods - MiniTwin.instance_methods
          own_and_inherited.grep(/=\z/).map { |m| m.to_s.delete_suffix("=").to_sym }.to_set
        end
      end

      def allowed_attribute_keys_array
        @allowed_attribute_keys_array_cache ||= begin
          allowed = allowed_attribute_keys
          ordered = property_order.select { |k| allowed.include?(k) }
          remaining = allowed.to_a - ordered
          (ordered + remaining).freeze
        end
      end

      def setter_methods
        @setter_methods_cache ||= begin
          public_instance_methods(false).select { |m| m.to_s.end_with?("=") }
        end
      end
    end
  end
end
