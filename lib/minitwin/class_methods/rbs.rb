# frozen_string_literal: true
# rbs_inline: enabled

class Minitwin
  module ClassMethods
    module Rbs

      #: () -> String
      def to_rbs
        # :nocov:
        return "" unless name

        lines = []
        superclass_name = superclass ? " < ::#{superclass.name}" : ""
        # :nocov:
        lines << "class ::#{name}#{superclass_name}"

        # Collect initializer parameters
        init_params = []

        props = properties
        props.each do |prop, meta|
          as_meta = meta[:as]
          # Dynamic aliases (Proc) cannot be represented statically in RBS;
          # fall back to the base property name.
          reader_name = as_meta && !as_meta.is_a?(Proc) && as_meta != prop ? as_meta : prop
          type = rbs_type_for(meta)
          lines << "  attr_reader #{reader_name}: #{type}"
          if method_defined?(:"#{prop}=", false)
            # :nocov:
            lines << "  attr_writer #{prop}: #{type}"
            # :nocov:
          end

          # Add to initializer parameters (all optional)
          init_params << "?#{prop}: #{type}"
        end

        collections.each do |name_sym, meta|
          elem_type = rbs_elem_type_for(meta)
          lines << "  attr_accessor #{name_sym}: ::Array[#{elem_type}]"

          # Add to initializer parameters (all optional, collections accept arrays or individual items)
          init_params << "?#{name_sym}: ::Array[#{elem_type}]"
        end

        # Add initializer signature
        lines << ""
        lines << if init_params.any?
                   "  def initialize: (#{init_params.join(", ")}, **untyped) -> void"
                 else
                   "  def initialize: (**untyped) -> void"
                 end

        lines << "end"
        lines.join("\n")
      end

      private

      def rbs_type_for(meta)
        if meta[:twin]
          rbs_class_name(meta[:twin])
        elsif meta[:nested_class]
          rbs_class_name(meta[:nested_class])
        else
          dry_type_to_rbs(meta[:type])
        end
      end

      def rbs_elem_type_for(meta)
        if meta[:element_twin]
          rbs_class_name(meta[:element_twin])
        else
          "untyped"
        end
      end

      def rbs_class_name(klass)
        return "untyped" unless klass&.name

        "::#{klass.name}"
      end

      def dry_type_to_rbs(dry_type)
        return "untyped" unless dry_type

        if dry_type.respond_to?(:primitive) && dry_type.primitive
          prim = dry_type.primitive
          if [TrueClass, FalseClass].include?(prim)
            "bool"
          elsif prim.is_a?(Class) && prim.name
            "::#{prim.name}"
          else
            "untyped"
          end
        else
          s =
            begin
              dry_type.to_s
            rescue StandardError
              ""
            end
          i =
            begin
              dry_type.inspect
            rescue StandardError
              ""
            end
          blob = [s, i, dry_type.class.name].join(" ")
          return "bool" if blob.include?("Bool")
          return "::Integer" if blob.include?("Integer")
          return "::String" if blob.include?("String")
          return "::Float" if blob.include?("Float")

          begin
            v1 = dry_type.call(true)
            v2 = dry_type.call(false)
            return "bool" if [true, false].include?(v1) && [true, false].include?(v2)
          rescue StandardError
            # Expected: Type coercion may fail for non-boolean types.
            # Continue to fallback 'untyped'.
          end
          "untyped"
        end
      end
    end
  end
end
