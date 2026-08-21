# frozen_string_literal: true
# rbs_inline: enabled

class Minitwin
  # Assign/update helpers to merge incoming data into an existing twin.
  # - assign_object: copy readable attributes from an object and remember it
  # - assign_hash / assign_params: update only known attributes, recursing into
  #   nested twins and collection items when possible
  module Assignment

    # Mirror values from a model's getters into this twin's setters
    #: (untyped) -> instance
    def to_object(model)
      assignable_attribute_methods.each do |method|
        reader = self.class.model_reader_for(model, method)
        next unless reader

        value = model.public_send(reader)

        ivar_name = Minitwin::Utils.ivar_name(method)
        current_value = instance_variable_get(ivar_name) if instance_variable_defined?(ivar_name)

        if current_value.is_a?(Minitwin) && !value.nil? && !value.is_a?(Hash)
          current_value.to_object(value)
        elsif respond_to?("#{method}=", true)
          send("#{method}=", value)
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
      aliases = self.class.send(:setter_alias_map)
      hash = hash.to_h.transform_keys { |key| aliases.fetch(key.to_sym, key.to_sym) }
      allowed = assignable_attribute_methods

      deferred = {}

      was_skipping = @__skip_alias_recompute__
      @__skip_alias_recompute__ = true
      begin
        hash.each do |method, value|
          unless allowed.include?(method)
            deferred[method] = value
            next
          end

          ivar_name = Minitwin::Utils.ivar_name(method)
          current_value = instance_variable_get(ivar_name) if instance_variable_defined?(ivar_name)

          if current_value.respond_to?(:assign_hash) && value.is_a?(Hash)
            current_value.assign_hash(value)
          elsif value.is_a?(Array) && current_value.is_a?(Array)
            assign_collection(method:, current: current_value, incoming: value)
          elsif respond_to?("#{method}=", true)
            send("#{method}=", value)
          end
        end
      ensure
        @__skip_alias_recompute__ = was_skipping
      end

      if !@__skip_alias_recompute__ && self.class.dynamic_aliases?
        __recompute_dynamic_aliases__
        __assign_dynamic_alias_keys__(deferred, allowed: allowed)
      end

      self
    end

    # Actually, this is expected to be an `ActionController::Parameters`
    # object. The type will be unknown when used without rails. So for RBS
    # the argument is typed `untyped`.
    #: (untyped params) -> instance
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

    private

    #: (method: Symbol, current: Array[untyped], incoming: Array[untyped]) -> void
    def assign_collection(method:, current:, incoming:)
      incoming.each_with_index do |item, index|
        if index >= current.size
          current << coerce_collection_item(method:, item:)
        elsif item.is_a?(Hash) && current[index].respond_to?(:assign_hash)
          current[index].assign_hash(item)
        else
          current[index] = coerce_collection_item(method:, item:)
        end
      end

      current.slice!(incoming.size..) if current.size > incoming.size
    end

    #: (method: Symbol, item: untyped) -> untyped
    def coerce_collection_item(method:, item:)
      element_twin = self.class.collections.dig(method, :element_twin)
      return item unless element_twin

      self.class.send(:coerce_value_to_twin, item, element_twin)
    end
  end
end
