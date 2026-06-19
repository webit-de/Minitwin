# frozen_string_literal: true
# rbs_inline: enabled

class Minitwin
  module ClassMethods
    module Caches

      #: () -> bool
      def dynamic_aliases?
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
        @serializable_getters = nil
        @allowed_attribute_keys = nil
        @allowed_attribute_keys_array = nil
        @setter_methods = nil
        @has_dynamic_aliases_cache = nil
      end

      def serializable_getters
        @serializable_getters ||= begin
          unexposed = unexposed_properties.to_set(&:to_sym)
          prot = (protected_instance_methods - Minitwin.protected_instance_methods).to_set
          declared = declared_property_keys
          own_and_inherited = serializable_method_candidates
          own_and_inherited.reject do |m|
            s = m.to_s
            s.end_with?("=", "?", "_attributes") || unexposed.include?(m) || prot.include?(m) ||
              !declared.include?(instance_method(m).original_name)
          end
        end
      end

      # Methods defined directly on the twin class hierarchy: this class and any
      # intermediate Minitwin subclasses, but not Minitwin itself. Methods mixed
      # in via modules (e.g. ActionView helpers, which include arg-taking methods
      # like #link_to) are excluded because instance_methods(false) reports only
      # methods owned by the class, not by included modules.
      def serializable_method_candidates
        twin_class_hierarchy.flat_map { |klass| klass.instance_methods(false) }.uniq
      end

      # Base names of every declared property and collection across the twin
      # class hierarchy. Only methods whose declaration name is one of these
      # serialize, so plain getters hand-defined on a twin are excluded. `as:`
      # aliases pass because #original_name maps them back to the original
      # property (the aliased reader is made protected and rejected separately).
      def declared_property_keys
        twin_class_hierarchy.each_with_object(Set.new) do |klass, keys|
          keys.merge(klass.properties.keys)
          keys.merge(klass.collections.keys)
        end
      end

      # This class and any intermediate Minitwin subclasses, but not Minitwin
      # itself or mixed-in modules.
      def twin_class_hierarchy
        ancestors.take_while { |a| a != Minitwin }.select { |a| a.instance_of?(Class) }
      end

      def allowed_attribute_keys
        # Setters defined directly on the twin class hierarchy. Uses the same
        # candidate set as serializable_getters so mixed-in module setters
        # (e.g. ActionView's #output_buffer=) are not treated as assignable
        # attributes.
        @allowed_attribute_keys ||= serializable_method_candidates.
                                      grep(/=\z/).to_set { |m| m.to_s.delete_suffix("=").to_sym }
      end

      def allowed_attribute_keys_array
        @allowed_attribute_keys_array ||= begin
          allowed = allowed_attribute_keys
          ordered = property_order.select { |k| allowed.include?(k) }
          remaining = allowed.to_a - ordered
          (ordered + remaining).freeze
        end
      end

      def setter_methods
        @setter_methods ||= public_instance_methods(false).select { |m| m.to_s.end_with?("=") }
      end
    end
  end
end
