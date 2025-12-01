class MiniTwin
  module ClassMethods
    module Dsl
      def block_properties
        @block_properties ||= []
      end

      def collection_properties
        @collection_properties ||= []
      end

      def virtual_properties
        @virtual_properties ||= []
      end

      def property_order
        @property_order ||= []
      end

      def collection(name, validates: {}, default: [], as: nil, getter: nil, twin: nil, on: nil, **_opts, &block)
        nested_class = block ? create_nested_class(name:, &block) : nil
        element_klass = twin || nested_class

        define_method("#{name}=") do |values|
          arr = self.class.send(:coerce_collection_array, values)
          coerced_values = arr.map { |v| self.class.send(:coerce_value_to_twin, v, element_klass) }
          define_instance_variable(name:, value: coerced_values)
          __recompute_dynamic_aliases__ if respond_to?(:__recompute_dynamic_aliases__, true)
        end
        alias_method "#{name}_attributes=", "#{name}="

        define_getter_method(name:, on:, as:, default:, getter:, type: nil)
        alias_method "#{name}_attributes", name
        add_validation(name:, validates:)
        add_collection_property(name:)
        invalidate_caches

        collections[name.to_sym] = { element_twin: element_klass, as: as }
        property_order << name.to_sym unless property_order.include?(name.to_sym)
      end

      def property(name, validates: {}, default: nil, as: nil, virtual: false, type: nil, getter: nil, setter: nil, twin: nil, on: nil, **_opts, &block)
        nested_class = nil

        if block_given?
          raise "setters are not possible in blocks" if setter
          nested_class = create_nested_class(name:, &block)

          define_method("#{name}=") do |value|
            coerced = self.class.send(:coerce_value_to_twin, value, nested_class)
            raise "Unprocessable input for property '#{name}'." unless coerced.nil? || coerced.is_a?(nested_class)
            define_instance_variable(name:, value: coerced)
            __recompute_dynamic_aliases__ if respond_to?(:__recompute_dynamic_aliases__, true)
          end

          add_block_property(name:)
        else
          define_method("#{name}=") do |value|
            coerced_value = if twin.present?
              self.class.send(:coerce_value_to_twin, value, twin)
            else
              setter ? setter.call(value) : value
            end
            define_instance_variable(name:, value: coerced_value)
            __recompute_dynamic_aliases__ if respond_to?(:__recompute_dynamic_aliases__, true)
          end
        end

        define_getter_method(name:, as:, on:, default:, getter:, type: type)
        add_validation(name:, validates:)
        add_virtual_property(name:, virtual:)
        invalidate_caches

        properties[name.to_sym] = {
          type: type,
          as: as,
          virtual: virtual
        }
        properties[name.to_sym][:twin] = twin if twin
        properties[name.to_sym][:nested_class] = nested_class if nested_class
        property_order << name.to_sym unless property_order.include?(name.to_sym)
      end

      def nested(name, &block)
        raise ArgumentError, "nested requires a block" unless block_given?
        property(name, &block)

        const_name = constantize_name(name)
        nested_klass = begin
          self.const_get(const_name)
        rescue NameError
          nil
        end

        # Registry for dynamic nested aliases (as: -> { ... }) on leafs
        @dynamic_nested_aliases ||= []
        def self.dynamic_nested_aliases; @dynamic_nested_aliases ||= []; end

        leafs = []
        if nested_klass && nested_klass.respond_to?(:properties)
          extract_leaf_properties = ->(klass, path) do
            klass.properties.each do |prop, meta|
              if meta[:nested_class]
                extract_leaf_properties.call(meta[:nested_class], path + [prop])
              else
                leafs << { path: (path + [prop]), as: (meta[:as] if meta[:as] && meta[:as] != prop) }
              end
            end
          end
          extract_leaf_properties.call(nested_klass, [])
        end

        leafs.each do |leaf|
          path = leaf[:path]
          prop = path.last
          as_meta = leaf[:as]

          # Define a stable internal reader for this leaf to support dynamic aliasing
          target_reader = "#{MiniTwin::NESTED_READER_PREFIX}#{([name] + path).join('__')}"
          define_method(target_reader) do
            obj = public_send(name)
            path[0..-2].each { |seg| obj = obj.public_send(seg) }
            if as_meta.is_a?(Proc)
              # When inner property has a dynamic alias, original reader may be protected.
              obj.send(prop)
            else
              inner_read = as_meta || prop
              # Use send to allow accessing protected original readers
              obj.send(inner_read)
            end
          end

          # Setter uses original base name to call the nested twin's writer.
          define_method("#{prop}=") do |value|
            obj = public_send(name)
            path[0..-2].each { |seg| obj = obj.public_send(seg) }
            obj.public_send("#{prop}=", value)
            __recompute_dynamic_aliases__ if respond_to?(:__recompute_dynamic_aliases__, true)
          end

          # Static alias: define a public getter method with the alias name
          if as_meta && !as_meta.is_a?(Proc)
            alias_name = as_meta
            define_method(alias_name) do
              send(target_reader)
            end
            virtual_properties << alias_name
          else
            # Dynamic alias: register for instance-level aliasing and rely on
            # __recompute_dynamic_aliases__ to create the per-instance method.
            self.dynamic_nested_aliases << { target: target_reader.to_sym, as: (as_meta || prop), group: name, path: path }
          end

          # Always hide the internal reader from serialization
          virtual_properties << target_reader.to_sym
        end

        invalidate_caches
      end

      private

      def constantize_name(name)
        name.to_s.split('_').map(&:capitalize).join
      end

      def create_nested_class(name:, &block)
        Class.new(MiniTwin).tap do |klass|
          if defined?(ActiveModel::Name)
            klass.define_singleton_method(:model_name) do
              ActiveModel::Name.new(self, nil, name.to_s)
            end
          end

          klass.class_eval(&block) if block.present?

          const_name = constantize_name(name)
          begin
            self.const_set(const_name, klass) unless self.const_defined?(const_name, false)
          rescue NameError => e
            # Expected: Constant name may be invalid or already defined in complex scenarios.
            # The nested class is still accessible via the klass variable.
          end
        end
      end

      def define_getter_method(name:, as:, on:, default:, getter:, type: nil)
        getter_proc = build_getter_proc(name:, on:, default:, getter:, type:)
        define_method(name, &getter_proc)
        apply_alias_to_getter(name:, as:)
      end

      def build_getter_proc(name:, on:, default:, getter:, type:)
        return -> { instance_exec(&getter) } if getter.present?

        if on.present?
          build_composition_getter(name:, on:, default:, type:)
        else
          build_regular_getter(name:, default:, type:)
        end
      end

      def build_composition_getter(name:, on:, default:, type:)
        -> {
          # Get composition model
          model = instance_variable_get(self.class.internal_model_name(on)) || (send(on) rescue nil)

          # Validate model
          if model.nil?
            raise "Property '#{name}' refers to unknown composition source '#{on}' in #{self.class}. Ensure the model is provided via from_objects or a reader exists."
          end
          unless model.respond_to?(name)
            raise "The instance of '#{model.class}' does not respond to '#{name}'."
          end

          raw = model.send(name)

          # Return default if raw is nil
          if raw.nil?
            return default unless default.nil?
            return type ? self.class.send(:type_default_value, type) : nil
          end

          # Process the value
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
        }
      end

      def build_regular_getter(name:, default:, type:)
        -> {
          # Strip '?' suffix for instance variable lookup to match setter behavior
          ivar_name = "@#{name}".delete_suffix("?")
          if instance_variable_defined?(ivar_name)
            val = instance_variable_get(ivar_name)
            if val.nil?
              return default unless default.nil?
              return type ? self.class.send(:type_default_value, type) : nil
            end
            type ? self.class.send(:coerce_with_type, val, type) : val
          else
            return default unless default.nil?
            type ? self.class.send(:type_default_value, type) : nil
          end
        }
      end

      def apply_alias_to_getter(name:, as:)
        return unless as.present?

        if as.is_a?(Proc)
          # Dynamic alias: protect original reader and let instances
          # compute and define the alias method at runtime.
          protected name
        elsif name != as
          alias_method as, name
          protected name
        end
      end

      def add_validation(name:, validates:)
        return if validates.nil?
        return if validates.respond_to?(:empty?) && validates.empty?

        raise "Validation is not possible, because activemodel is not available" unless self.respond_to?(:validates)

        if validates.is_a?(Proc)
          validate do
            value = send(name)
            errors.add(name, "is invalid") unless validates.call(value)
          end
        else
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
