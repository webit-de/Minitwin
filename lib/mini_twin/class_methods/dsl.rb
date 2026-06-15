# frozen_string_literal: true
# rbs_inline: enabled

class Minitwin
  module ClassMethods
    module Dsl

      #: () -> Array[Symbol]
      def block_properties
        @block_properties ||= []
      end

      #: () -> Array[Symbol]
      def collection_properties
        @collection_properties ||= []
      end

      #: () -> Array[Symbol]
      def unexposed_properties
        @unexposed_properties ||= []
      end

      #: () -> Array[Symbol]
      def property_order
        @property_order ||= []
      end

      #: () -> Array[Hash]
      def dynamic_nested_aliases
        @dynamic_nested_aliases ||= []
      end

      # @rbs name: Symbol
      # @rbs validates: Hash[Symbol, untyped]
      # @rbs default: untyped
      # @rbs as: Symbol | Proc
      # @rbs getter: Proc
      # @rbs twin: untyped
      # @rbs on: Symbol
      # @rbs return: void
      def collection(name, validates: {}, default: [], as: nil, getter: nil, twin: nil, on: nil, **_opts, &block)
        nested_class = block ? create_nested_class(name:, &block) : nil
        element_klass = twin || nested_class

        define_method("#{name}=") do |values|
          arr = self.class.send(:coerce_collection_array, values)
          coerced_values = arr.map { |v| self.class.send(:coerce_value_to_twin, v, element_klass) }
          define_instance_variable(name:, value: coerced_values)
          # :nocov:
          if !@__skip_alias_recompute__ && self.class.dynamic_aliases?
            __recompute_dynamic_aliases__
          end
          # :nocov:
        end
        alias_method "#{name}_attributes=", "#{name}="

        define_getter_method(name:, on:, as:, default:, getter:, type: nil)
        alias_method "#{name}_attributes", name
        add_validation(name:, validates:)
        add_collection_property(name:)
        invalidate_caches

        collections[name.to_sym] = { element_twin: element_klass, as: as }
        add_to_property_order(name)
      end

      # @rbs name: Symbol
      # @rbs validates: Hash[Symbol, untyped]
      # @rbs default: untyped
      # @rbs as: Symbol | Proc
      # @rbs virtual: bool?
      # @rbs expose: bool
      # @rbs readonly: bool
      # @rbs type: untyped
      # @rbs getter: Proc
      # @rbs setter: Proc
      # @rbs twin: untyped
      # @rbs on: Symbol
      # @rbs return: void
      def property(
        name, validates: {}, default: nil, as: nil, virtual: nil, expose: true, readonly: false, type: nil, getter: nil, setter: nil,
        twin: nil, on: nil, **_opts, &block
      )
        unless virtual.nil?
          warn "property :#{name} - `virtual:` is deprecated, use `expose: #{!virtual}` instead.", uplevel: 1
          expose = !virtual
        end

        nested_class = nil

        if block_given?
          raise "setters are not possible in blocks" if setter

          nested_class = create_nested_class(name:, &block)

          define_method("#{name}=") do |value|
            coerced = self.class.send(:coerce_value_to_twin, value, nested_class)
            raise "Unprocessable input for property '#{name}'." unless coerced.nil? || coerced.is_a?(nested_class)

            define_instance_variable(name:, value: coerced)
            if !@__skip_alias_recompute__ && self.class.dynamic_aliases?
              __recompute_dynamic_aliases__
            end
          end

          add_block_property(name:)
        else
          define_method("#{name}=") do |value|
            coerced_value =
              if twin
                self.class.send(:coerce_value_to_twin, value, twin)
              elsif setter
                setter.call(value)
              elsif type && !value.nil?
                self.class.send(:coerce_with_type, value, type)
              else
                value
              end
            define_instance_variable(name:, value: coerced_value)
            if !@__skip_alias_recompute__ && self.class.dynamic_aliases?
              __recompute_dynamic_aliases__
            end
          end
        end

        define_getter_method(name:, as:, on:, default:, getter:, type: type)
        add_validation(name:, validates:)
        add_unexposed_property(name:, expose:)
        invalidate_caches

        properties[name.to_sym] = {
          type: type,
          as: as,
          expose: expose,
          readonly: readonly
        }
        properties[name.to_sym][:twin] = twin if twin
        properties[name.to_sym][:nested_class] = nested_class if nested_class
        add_to_property_order(name)
      end

      # @rbs name: Symbol
      # @rbs as: Symbol | Proc
      # @rbs return: void
      def nested(name, as: nil, &block)
        raise ArgumentError, "nested requires a block" unless block_given?

        property(name, as: as, &block)

        # Pull the nested class directly from the registration `property`
        # just performed instead of round-tripping through `const_get`.
        nested_klass = properties[name.to_sym]&.[](:nested_class)

        # Registry for dynamic nested aliases (as: -> { ... }) on leafs.
        # Reader defined once in the module body above.
        leafs = []
        if nested_klass.respond_to?(:properties)
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

        leafs.each do |leaf| # rubocop: disable Metrics/BlockLength
          path = leaf[:path]
          prop = path.last
          as_meta = leaf[:as]

          # Define a stable internal reader for this leaf to support dynamic aliasing
          target_reader = "#{Minitwin::NESTED_READER_PREFIX}#{([name] + path).join("__")}"
          define_method(target_reader) do
            obj = send(name)
            obj = Minitwin::Utils.traverse_path(obj, path[0..-2])
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
            obj = send(name)
            obj = Minitwin::Utils.traverse_path(obj, path[0..-2])
            obj.public_send("#{prop}=", value)
            if !@__skip_alias_recompute__ && self.class.dynamic_aliases?
              __recompute_dynamic_aliases__
            end
          end

          # Static alias: define a public getter method with the alias name
          if as_meta && !as_meta.is_a?(Proc)
            alias_name = as_meta
            define_method(alias_name) do
              send(target_reader)
            end
            unexposed_properties << alias_name

            # Define protected getter with original name so sync can read the value,
            # and register in properties so sync resolves the as: alias.
            define_method(prop) { send(target_reader) }
            protected prop
            properties[prop.to_sym] = { type: nil, as: as_meta, expose: true, nested_proxy: true }
          else
            # Dynamic alias: register for instance-level aliasing and rely on
            # __recompute_dynamic_aliases__ to create the per-instance method.
            dynamic_nested_aliases << { target: target_reader.to_sym, as: as_meta || prop, group: name, path: path }
          end

          # Always hide the internal reader from serialization
          unexposed_properties << target_reader.to_sym
        end

        invalidate_caches
      end

      private

      def constantize_name(name)
        name.to_s.split("_").map(&:capitalize).join
      end

      def create_nested_class(name:, &block)
        Class.new(Minitwin).tap do |klass|
          if defined?(ActiveModel::Name)
            klass.define_singleton_method(:model_name) do
              ActiveModel::Name.new(self, nil, name.to_s)
            end
          end

          klass.class_eval(&block) if block

          const_name = constantize_name(name)
          begin
            const_set(const_name, klass) unless const_defined?(const_name, false)
          rescue NameError
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
        if getter
          if getter.is_a?(Symbol)
            return -> { send(getter) }
          else
            return -> { instance_exec(&getter) }
          end
        end

        if on
          build_composition_getter(name:, on:, default:, type:)
        else
          build_regular_getter(name:, default:, type:)
        end
      end

      def build_composition_getter(name:, on:, default:, type:)
        # Resolve model ivar name at definition time when on is a symbol
        model_ivar = on.is_a?(Proc) ? nil : internal_model_name(on)
        # Collection metadata will be resolved after property registration
        # via a lazy lookup on first access, then cached in the closure.
        col_meta = nil
        col_meta_resolved = false

        -> { # rubocop: disable Metrics/BlockLength
          # Get composition model - handle both symbol and proc cases
          model = if on.is_a?(Proc)
                    instance_exec(&on)
                  else
                    instance_variable_get(model_ivar) || begin
                      send(on)
                    rescue NoMethodError
                      nil
                    end
                  end

          # Validate model
          if model.nil?
            raise(
              "Property '#{name}' refers to unknown composition source '#{on}' in #{self.class}. " \
                "Ensure the model is provided via from_objects or a reader exists."
            )
          end
          unless model.respond_to?(name)
            raise "The instance of '#{model.class}' does not respond to '#{name}'."
          end

          raw = model.send(name)

          # Return default if raw is nil
          return self.class.send(:resolve_default_value, default, type) if raw.nil?

          # Resolve collection metadata once and cache in closure
          unless col_meta_resolved
            col_meta = begin
              self.class.collections[name.to_sym]
            rescue StandardError
              nil
            end
            col_meta_resolved = true
          end

          if col_meta && (raw.is_a?(Array) || raw.respond_to?(:to_a))
            elem_klass = col_meta[:element_twin]
            arr = self.class.send(:coerce_collection_array, raw)
            arr.map { |v| self.class.send(:coerce_value_to_twin, v, elem_klass) }
          else
            type ? self.class.send(:coerce_with_type, raw, type) : raw
          end
        }
      end

      def build_regular_getter(name:, default:, type:)
        # Compute ivar_name at definition time for JIT optimization.
        # Type coercion happens on assignment (setter) so the getter just reads.
        ivar = Minitwin::Utils.ivar_name(name)
        -> {
          if instance_variable_defined?(ivar)
            val = instance_variable_get(ivar)
            return self.class.send(:resolve_default_value, default, type) if val.nil?

            val
          else
            self.class.send(:resolve_default_value, default, type)
          end
        }
      end

      def apply_alias_to_getter(name:, as:)
        return if as.nil?

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

        raise "Validation is not possible, because activemodel is not available" unless respond_to?(:validates)

        if validates.is_a?(Proc)
          validate do
            value = send(name)
            errors.add(name, "is invalid") unless validates.call(value)
          end
        else
          validates(name, **validates)
        end
      end

      def add_unexposed_property(name:, expose:)
        unexposed_properties << name unless expose
      end

      def add_block_property(name:)
        block_properties << name.to_sym
      end

      def add_collection_property(name:)
        collection_properties << name.to_sym
      end

      def add_to_property_order(name)
        key = name.to_sym
        property_order << key unless property_order.include?(key)
      end

      def resolve_default_value(default, type)
        unless default.nil?
          return default.respond_to?(:call) ? default.call : default
        end

        type ? type_default_value(type) : nil
      end
    end
  end
end
