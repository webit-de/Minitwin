# rbs_inline: enabled

class Minitwin
  module ClassMethods
    module Caches

      #: () -> bool
      def has_dynamic_aliases?
        return @has_dynamic_aliases_cache unless @has_dynamic_aliases_cache.nil?

        @has_dynamic_aliases_cache = begin
          procs = properties.any? { |_, m| m[:as].is_a?(Proc) } ||
                  collections.any? { |_, m| m[:as].is_a?(Proc) }
          nested = respond_to?(:dynamic_nested_aliases) && dynamic_nested_aliases.any?
          procs || nested
        end
      end

      private

      def invalidate_caches
        @serializable_getters_cache = nil
        @allowed_attribute_keys_cache = nil
        @allowed_attribute_keys_array_cache = nil
        @setter_methods_cache = nil
        @has_dynamic_aliases_cache = nil
      end

      def serializable_getters
        @serializable_getters_cache ||= begin
          unexposed = unexposed_properties.to_set
          prot = (protected_instance_methods - Minitwin.protected_instance_methods).to_set
          own_and_inherited = instance_methods - Minitwin.instance_methods
          own_and_inherited.reject do |m|
            s = m.to_s
            s.end_with?("=", "?", "_attributes") || unexposed.include?(m) || prot.include?(m)
          end
        end
      end

      def allowed_attribute_keys
        @allowed_attribute_keys_cache ||= begin
          # Include methods from this class and parent Minitwin subclasses,
          # but not from Minitwin itself or its ancestors (Object, etc.)
          own_and_inherited = instance_methods - Minitwin.instance_methods
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
