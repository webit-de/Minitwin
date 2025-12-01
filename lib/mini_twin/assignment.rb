class MiniTwin
  # Assign/update helpers to merge incoming data into an existing twin.
  # - assign_object: copy readable attributes from an object and remember it
  # - assign_hash / assign_params: update only known attributes, recursing into
  #   nested twins and collection items when possible
  # - to_object: copy from a model to the twin via setters (one-way mirror)
  module Assignment
    def assign_object(model)
      attribute_methods.each do |method|
        next unless model.respond_to?(method)
        value = model.public_send(method)
        assign_attribute(method:, value:)
      end
      instance_variable_set(self.class.internal_model_name("model"), model)
      self
    end

    def assign_hash(hash = {})
      hash = hash.to_h.with_indifferent_access

      attribute_methods.each do |method|
        next unless hash.key?(method)

        value = hash[method]
        # Strip '?' suffix for instance variable lookup to match setter behavior
        ivar_name = "@#{method}".delete_suffix("?")
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
          assign_attribute(method:, value:)
        end
      end

      self
    end

    def assign_params(params = {})
      params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
      assign_hash(params)
    end

    def to_object(model)
      # Use cached setter methods if available
      setter_methods = if self.class.respond_to?(:setter_methods, true)
        self.class.send(:setter_methods)
      else
        public_methods(false).select { |m| m.to_s.end_with?("=") }
      end

      setter_methods.each do |method|
        attr = method.to_s.delete_suffix("=")
        next unless model.respond_to?(attr)
        send(method, model.public_send(attr))
      end
      self
    end
  end
end
