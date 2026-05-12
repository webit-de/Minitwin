# rbs_inline: enabled

class MiniTwin
  # Assign/update helpers to merge incoming data into an existing twin.
  # - assign_object: copy readable attributes from an object and remember it
  # - assign_hash / assign_params: update only known attributes, recursing into
  #   nested twins and collection items when possible
  module Assignment

    # Mirror values from a model's getters into this twin's setters
    #: (untyped) -> instance
    def to_object(model)
      assignable_attribute_methods.each do |method|
        next unless model.respond_to?(method)
        value = model.public_send(method)

        ivar_name = MiniTwin::Utils.ivar_name(method)
        current_value = instance_variable_get(ivar_name) if instance_variable_defined?(ivar_name)

        if current_value.is_a?(MiniTwin) && !value.nil? && !value.is_a?(Hash)
          current_value.to_object(value)
        else
          send("#{method}=", value) if respond_to?("#{method}=", true)
        end
      end
      self
    end

    #: (untyped) -> instance
    def assign_object(model)
      to_object(model)
      instance_variable_set(self.class.internal_model_name("model"), model)
      self
    end

    #: (Hash[ String | Symbol, untyped ] hash) -> instance
    def assign_hash(hash = {})
      hash = hash.to_h.transform_keys(&:to_sym)
      allowed = assignable_attribute_methods

      was_skipping = @__skip_alias_recompute__
      @__skip_alias_recompute__ = true
      begin
        hash.each do |method, value|
          next unless allowed.include?(method)

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
      ensure
        @__skip_alias_recompute__ = was_skipping
      end

      if !@__skip_alias_recompute__ && self.class.has_dynamic_aliases?
        __recompute_dynamic_aliases__
      end

      self
    end

    # DEBT: This will fail in type checks in projects without rails, because
    # argument type is unknown in plain ruby.
    #
    #: (ActionController::Parameters params) -> instance
    def assign_params(params = {})
      params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
      assign_hash(params)
    end

    # Gets the non-readonly methods, which can be assigned with new values.
    #: () -> Array[Symbol]
    def assignable_attribute_methods
      attribute_methods.reject do |method|
        prop_meta = self.class.properties[method]
        prop_meta && prop_meta[:readonly]
      end
    end
  end
end
