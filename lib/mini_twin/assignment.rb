class MiniTwin
  # Assign/update helpers to merge incoming data into an existing twin.
  # - assign_object: copy readable attributes from an object and remember it
  # - assign_hash / assign_params: update only known attributes, recursing into
  #   nested twins and collection items when possible
  module Assignment

    # Mirror values from a model's getters into this twin's setters
    def to_object(model)
      attribute_methods.each do |method|
        next unless model.respond_to?(method)
        value = model.public_send(method)
        send("#{method}=", value) if respond_to?("#{method}=", true)
      end
      self
    end

    def assign_object(model)
      to_object(model)
      instance_variable_set(self.class.internal_model_name("model"), model)
      self
    end

    def assign_hash(hash = {})
      hash = hash.to_h.transform_keys(&:to_sym)

      attribute_methods.each do |method|
        next unless hash.key?(method)

        value = hash[method]
        ivar_name = MiniTwin::Utils.ivar_name(method)
        current_value = instance_variable_get(ivar_name) if instance_variable_defined?(ivar_name)

        if current_value.respond_to?(:assign_hash) && value.is_a?(Hash)
          current_value.assign_hash(value)
        elsif value.is_a?(Array) && current_value.is_a?(Array)
          value.each_with_index do |item, idx|
            if item.is_a?(Hash) && current_value.size > idx && current_value[idx].respond_to?(:assign_hash)
              current_value[idx].assign_hash(item)
            else
              current_value[idx] = item
            end
          end
        else
          send("#{method}=", value) if respond_to?("#{method}=", true)
        end
      end

      self
    end

    def assign_params(params = {})
      params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
      assign_hash(params)
    end
  end
end
