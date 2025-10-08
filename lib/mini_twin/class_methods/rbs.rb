class MiniTwin
  module ClassMethods
    module RBS
      def to_rbs
        return "" unless name

        lines = []
        superclass_name = self.superclass ? " < ::#{self.superclass.name}" : ""
        lines << "class ::#{name}#{superclass_name}"

        props = properties
        props.each do |prop, meta|
          reader_name = (meta[:as] && meta[:as] != prop) ? meta[:as] : prop
          type = rbs_type_for(meta)
          lines << "  attr_reader #{reader_name}: #{type}"
          if instance_methods(false).include?("#{prop}=".to_sym)
            lines << "  attr_writer #{prop}: #{type}"
          end
        end

        collections.each do |name_sym, meta|
          elem_type = rbs_elem_type_for(meta)
          lines << "  attr_accessor #{name_sym}: ::Array[#{elem_type}]"
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
          'untyped'
        end
      end

      def rbs_class_name(klass)
        return 'untyped' unless klass && klass.name
        "::#{klass.name}"
      end

      def dry_type_to_rbs(t)
        return 'untyped' unless t
        if t.respond_to?(:primitive) && t.primitive
          prim = t.primitive
          if prim == TrueClass || prim == FalseClass
            'bool'
          elsif prim.is_a?(Class) && prim.name
            "::#{prim.name}"
          else
            'untyped'
          end
        else
          s = t.to_s rescue ''
          i = (t.inspect rescue '')
          blob = [ s, i, t.class.name ].join(' ')
          return 'bool' if blob.include?('Bool')
          return '::Integer' if blob.include?('Integer')
          return '::String' if blob.include?('String')
          return '::Float' if blob.include?('Float')
          begin
            v1 = t.call(true)
            v2 = t.call(false)
            return 'bool' if (v1 == true || v1 == false) && (v2 == true || v2 == false)
          rescue StandardError
          end
          'untyped'
        end
      end
    end
  end
end
