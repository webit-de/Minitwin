class MiniTwin
  module ClassMethods
    module Caches
      private

      def invalidate_caches
        @serializable_getters_cache = nil
        @allowed_attribute_keys_cache = nil
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
          instance_methods(false).grep(/=\z/).map { |m| m.to_s.delete_suffix("=").to_sym }.to_set
        end
      end
    end
  end
end
