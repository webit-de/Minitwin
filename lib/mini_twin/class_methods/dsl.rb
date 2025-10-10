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
          arr = self.class.send(:coerce_collection_array, values)
          values = arr.map { |v| self.class.send(:coerce_value_to_twin, v, element_klass) }
          define_instance_variable(name:, value: values)
          __recompute_dynamic_aliases__ if respond_to?(:__recompute_dynamic_aliases__, true)
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
            coerced = self.class.send(:coerce_value_to_twin, value, nested_class)
            unless coerced.nil? || coerced.is_a?(nested_class)
              raise "Unprocessable input for property '#{name}'."
            end
            define_instance_variable(name:, value: coerced)
            __recompute_dynamic_aliases__ if respond_to?(:__recompute_dynamic_aliases__, true)
          end

          add_block_property(name:)
          properties[name.to_sym] = { type:, as:, virtual:, twin: nil, nested_class: nested_class }
        else
          define_method("#{name}=") do |value|
            value =
              if twin.present?
                self.class.send(:coerce_value_to_twin, value, twin)
              else
                setter ? setter.call(value) : value
              end
            define_instance_variable(name:, value:)
            __recompute_dynamic_aliases__ if respond_to?(:__recompute_dynamic_aliases__, true)
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

        leafs = []
        if nested_klass && nested_klass.respond_to?(:properties)
          walker = nil
          walker = ->(klass, path) do
            klass.properties.each do |prop, meta|
              if meta[:nested_class]
                walker.call(meta[:nested_class], path + [prop])
              else
                leafs << { path: (path + [prop]), as: (meta[:as] if meta[:as] && meta[:as] != prop) }
              end
            end
          end
          walker.call(nested_klass, [])
        end

        leafs.each do |leaf|
          path = leaf[:path]
          prop = path.last
          alias_name = leaf[:as] || prop

          # Public getter uses alias when present; reads inner via alias to
          # respect protected original readers inside the nested twin.
          define_method(alias_name) do
            obj = public_send(name)
            path[0..-2].each { |seg| obj = obj.public_send(seg) }
            inner_read = leaf[:as] || prop
            obj.public_send(inner_read)
          end

          # Setter uses original base name to call the nested twin's writer.
          define_method("#{prop}=") do |value|
            obj = public_send(name)
            path[0..-2].each { |seg| obj = obj.public_send(seg) }
            obj.public_send("#{prop}=", value)
          end

          virtual_properties << alias_name
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

                  if meta && (raw.is_a?(Array) || raw.respond_to?(:to_a))
                    elem_klass = meta[:element_twin]
                    arr = self.class.send(:coerce_collection_array, raw)
                    arr.map { |v| self.class.send(:coerce_value_to_twin, v, elem_klass) }
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
        if as.present?
          if as.is_a?(Proc)
            # Dynamic alias: protect original reader and let instances
            # compute and define the alias method at runtime.
            protected name
          elsif name != as
            alias_method as, name
            protected name
          end
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
