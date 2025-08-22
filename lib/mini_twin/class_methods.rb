class MiniTwin
  module ClassMethods
    def from_hash(args)
      new(**args)
    end

    def from_json(body)
      hash = JSON.parse(body, symbolize_names: true)
      from_hash(hash)
    end

    def from_params(params)
      return from_hash(params) unless params.respond_to?(:to_unsafe_hash)
      from_hash params.to_unsafe_hash
    end

    def from_object(model)
      raise "Input is not an object. If you want to instantiate a MiniTwin with multiple objects, then use the pluralized 'from_objects'-method." if model.is_a?(Hash)
      from_objects(model:)
    end

    def from_objects(**models)
      attributes =
        models.values.map do |model|
          if model.respond_to?(:attributes) && model.respond_to?(:attribute_aliases)
            combined_attributes = model.attributes.dup
            model.attribute_aliases.each do |alias_name, real_attr|
              combined_attributes[alias_name] = model.send(real_attr)
            end
            combined_attributes
          elsif model.respond_to?(:attributes)
            model.attributes
          elsif model.respond_to?(:to_h)
            model.to_h
          else
            model.instance_variables.each_with_object({}) do |var, hash|
              key = var.to_s.delete("@").to_sym
              hash[key] = model.instance_variable_get(var)
            end
          end
        end.reduce({}, :merge)

      obj = new(**attributes)
      models.each { |name, model| obj.instance_variable_set(internal_model_name(name), model) }
      obj
    end

    def from_collection(models)
      models.map { |attrs| self.new(**attrs) }
    end

    def collection(name, validates: {}, default: [], as: nil, getter: nil, twin: nil, on: nil, **_opts, &block)
      nested_class = create_nested_class(name:, &block)

      define_method("#{name}=") do |values|
        values = Array(values).map do |v|
          if twin.present?
            if v.is_a?(Hash)
              twin.new(**v)
            elsif v.is_a?(Array)
              twin.new(**v.last)
            end
          elsif v.is_a?(Hash)
            nested_class.new(**v)
          else
            v
          end
        end
        define_instance_variable(name:, value: values)
      end
      alias_method "#{name}_attributes=", "#{name}="

      define_getter_method(name:, on:, as:, default:, getter:)
      alias_method "#{name}_attributes", name
      add_validation(name:, validates:)
      add_collection_property(name:)
    end

    def property(name, validates: {}, default: nil, as: nil, virtual: false, type: nil, getter: nil, setter: nil, twin: nil, on: nil, **_opts, &block)
      if block_given?
        raise "setters are not possible in blocks" if setter

        nested_class = create_nested_class(name:, &block)

        define_method("#{name}=") do |value|
          value = value.to_h if value.respond_to?(:to_h)
          value = value.attributes if value.respond_to?(:attributes)
          raise "Unprocessable input for property '#{name}'." unless value.is_a? Hash
          define_instance_variable(name:, value: nested_class.new(**value))
        end

        add_block_property(name:)
      else
        define_method("#{name}=") do |value|
          value =
            if twin.present?
              twin.new(**value)
            else
              raw = setter ? setter.call(value) : value
              type ? (type.call(raw) rescue raw) : raw
            end
          define_instance_variable(name:, value:)
        end
      end

      define_getter_method(name:, as:, on:, default:, getter:)
      add_validation(name:, validates:)
      add_virtual_property(name:, virtual:)
    end

    def block_properties
      @block_properties ||= []
    end

    def collection_properties
      @collection_properties ||= []
    end

    def virtual_properties
      @virtual_properties ||= []
    end

    def internal_model_name(name)
      "@internal_model__#{name}".to_sym if name.present?
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
      end
    end

    def define_getter_method(name:, as:, on:, default:, getter:)
      getter_proc =
        if getter.present?
          -> { instance_exec(&getter) }
        else
          -> {
            if on.present?
              model = instance_variable_get(self.class.internal_model_name(on)).presence || send(on)
              raise "The property '#{name}' defines an on-keyword which does not exist (#{on}). Please make sure, that the model is instantiated correctly with 'from_object' " if model.nil?
              raise "The instance of '#{model.class}' does not respond to '#{name}'." unless model.respond_to?(name)

              model.send(name).presence || default
            else
              (!name.end_with?("?") && instance_variable_defined?("@#{name}")) ? instance_variable_get("@#{name}") : default
            end
          }
        end

      define_method(name, &getter_proc)
      alias_method "#{name}?", name if name.end_with?("?")

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
