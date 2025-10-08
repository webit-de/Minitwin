class MiniTwin
  module ClassMethods
    module DSL
      def block_properties
        @block_properties ||= []
      end

      def collection_properties
        @collection_properties ||= []
      end

      def virtual_properties
        @virtual_properties ||= []
      end

      def collection(name, validates: {}, default: [], as: nil, getter: nil, twin: nil, on: nil, **_opts, &block)
        nested_class = create_nested_class(name:, &block)

        define_method("#{name}=") do |values|
          element_klass = twin || nested_class
          values = Array(values).map do |v|
            if element_klass
              if v.nil?
                nil
              elsif v.is_a?(element_klass)
                v
              elsif v.respond_to?(:to_h)
                element_klass.new(**v.to_h)
              elsif v.respond_to?(:attributes)
                element_klass.new(**v.attributes)
              elsif v.is_a?(Array) && v.size == 2 && v.last.is_a?(Hash)
                element_klass.new(**v.last)
              elsif v.is_a?(Hash)
                element_klass.new(**v)
              else
                v
              end
            else
              v
            end
          end
          define_instance_variable(name:, value: values)
        end
        alias_method "#{name}_attributes=", "#{name}="

        define_getter_method(name:, on:, as:, default:, getter:, type: nil)
        alias_method "#{name}_attributes", name
        add_validation(name:, validates:)
        add_collection_property(name:)
        invalidate_caches

        collections[name.to_sym] = {
          element_twin: (twin || nested_class),
          as: as
        }
      end

      def property(name, validates: {}, default: nil, as: nil, virtual: false, type: nil, getter: nil, setter: nil, twin: nil, on: nil, **_opts, &block)
        if block_given?
          raise "setters are not possible in blocks" if setter

          nested_class = create_nested_class(name:, &block)

          define_method("#{name}=") do |value|
            if value.nil?
              define_instance_variable(name:, value: nil)
            else
              value = value.to_h if value.respond_to?(:to_h)
              value = value.attributes if value.respond_to?(:attributes)
              raise "Unprocessable input for property '#{name}'." unless value.is_a? Hash
              define_instance_variable(name:, value: nested_class.new(**value))
            end
          end

          add_block_property(name:)
          properties[name.to_sym] = { type:, as:, virtual:, twin: nil, nested_class: nested_class }
        else
          define_method("#{name}=") do |value|
            value =
              if twin.present?
                if value.nil?
                  nil
                elsif value.is_a?(twin)
                  value
                elsif value.respond_to?(:to_h)
                  twin.new(**value.to_h)
                elsif value.respond_to?(:attributes)
                  twin.new(**value.attributes)
                elsif value.is_a?(Hash)
                  twin.new(**value)
                else
                  value
                end
              else
                setter ? setter.call(value) : value
              end
            define_instance_variable(name:, value:)
          end
        end

        define_getter_method(name:, as:, on:, default:, getter:, type: type)
        add_validation(name:, validates:)
        add_virtual_property(name:, virtual:)
        invalidate_caches

        properties[name.to_sym] ||= {}
        properties[name.to_sym][:type] = type
        properties[name.to_sym][:as] = as
        properties[name.to_sym][:virtual] = virtual
        properties[name.to_sym][:twin] = twin unless twin.nil?
      end

      def nested(name, &block)
        raise ArgumentError, "nested requires a block" unless block_given?
        property(name, &block)

        const_name = name.to_s.split('_').map(&:capitalize).join
        nested_klass = self.const_get(const_name) rescue nil

        prop_paths = []
        if nested_klass && nested_klass.respond_to?(:properties)
          walker = nil
          walker = ->(klass, path) do
            klass.properties.each do |prop, meta|
              if meta[:nested_class]
                walker.call(meta[:nested_class], path + [prop])
              else
                prop_paths << (path + [prop])
              end
            end
          end
          walker.call(nested_klass, [])
        end

        prop_paths.each do |path|
          prop = path.last

          define_method(prop) do
            obj = public_send(name)
            path[0..-2].each { |seg| obj = obj.public_send(seg) }
            obj.public_send(prop)
          end

          define_method("#{prop}=") do |value|
            obj = public_send(name)
            path[0..-2].each { |seg| obj = obj.public_send(seg) }
            obj.public_send("#{prop}=", value)
          end

          virtual_properties << prop
        end

        invalidate_caches
      end

      private

      def create_nested_class(name:, &block)
        Class.new(MiniTwin).tap do |klass|
          if defined?(ActiveModel::Name)
            klass.define_singleton_method(:model_name) do
              ActiveModel::Name.new(self, nil, name.to_s)
            end
          end

          klass.class_eval(&block) if block.present?

          const_name = name.to_s.split('_').map(&:capitalize).join
          begin
            self.const_set(const_name, klass) unless self.const_defined?(const_name, false)
          rescue NameError
          end
        end
      end

      def define_getter_method(name:, as:, on:, default:, getter:, type: nil)
        getter_proc =
          if getter.present?
            -> { instance_exec(&getter) }
          else
            -> {
              if on.present?
                model = instance_variable_get(self.class.internal_model_name(on)) || (send(on) rescue nil)
                if model.nil?
                  raise "Property '#{name}' refers to unknown composition source '#{on}' in #{self.class}. Ensure the model is provided via from_objects or a reader exists."
                end
                raise "The instance of '#{model.class}' does not respond to '#{name}'." unless model.respond_to?(name)

                raw = model.send(name)
                if raw.nil?
                  (!default.nil?) ? default : (type ? self.class.send(:type_default_value, type) : nil)
                else
                  # If this is a collection property, wrap elements into the
                  # configured element twin so renamed getters etc. work when
                  # reading via composition (on: ...).
                  begin
                    meta = self.class.respond_to?(:collections) ? self.class.collections[name.to_sym] : nil
                  rescue StandardError
                    meta = nil
                  end

                  if meta && raw.is_a?(Array)
                    elem_klass = meta[:element_twin]
                    raw.map do |v|
                      if v.nil?
                        nil
                      elsif elem_klass && v.is_a?(elem_klass)
                        v
                      elsif elem_klass && v.respond_to?(:to_h)
                        elem_klass.new(**v.to_h)
                      elsif elem_klass && v.respond_to?(:attributes)
                        elem_klass.new(**v.attributes)
                      elsif elem_klass && v.is_a?(Array) && v.size == 2 && v.last.is_a?(Hash)
                        elem_klass.new(**v.last)
                      elsif elem_klass && v.is_a?(Hash)
                        elem_klass.new(**v)
                      else
                        v
                      end
                    end
                  else
                    type ? self.class.send(:coerce_with_type, raw, type) : raw
                  end
                end
              else
                if !name.end_with?("?") && instance_variable_defined?("@#{name}")
                  val = instance_variable_get("@#{name}")
                  return (!default.nil?) ? default : (type ? self.class.send(:type_default_value, type) : nil) if val.nil?
                  type ? self.class.send(:coerce_with_type, val, type) : val
                else
                  if !default.nil?
                    default
                  elsif type
                    self.class.send(:type_default_value, type)
                  else
                    nil
                  end
                end
              end
            }
          end

        define_method(name, &getter_proc)
        if as.present? && name != as
          alias_method as, name
          protected name
        end
      end

      def add_validation(name:, validates:)
        if validates.any?
          raise "Validation is not possible, because activemodel is not available" unless self.respond_to?(:validates)
          validates(name, **validates)
        end
      end

      def add_virtual_property(name:, virtual:)
        virtual_properties << name if virtual
      end

      def add_block_property(name:)
        block_properties << name
      end

      def add_collection_property(name:)
        collection_properties << name
      end
    end
  end
end
