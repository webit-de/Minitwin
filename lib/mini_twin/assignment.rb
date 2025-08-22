class MiniTwin
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
        current_value = instance_variable_get("@#{method}")

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
      self.public_methods(false).each do |method|
        next unless method.to_s.end_with?("=")
        self.send(method, model.send(method[..-2]))
      end
      self
    end
  end
end
