# frozen_string_literal: true
# rbs_inline: enabled

class Minitwin
  # Serialization to Hash/JSON and ActiveModel validation aggregation.
  # Converts nested twins recursively and preserves array items (dropping only
  # nil). When ActiveModel validations are available, nested errors are
  # surfaced on the parent using dot/bracket notation.
  module Serialization
    # Cache constant references for JIT optimization
    ALIASES_VAR = Minitwin::DYNAMIC_ALIASES_VAR
    NESTED_PREFIX = Minitwin::NESTED_READER_PREFIX

    #: (render_nil: bool) -> Hash[Symbol, untyped]
    def to_hash(render_nil: false)
      hash = Minitwin.hash_klass.new

      methods_to_serialize = self.class.send(:serializable_getters)
      expose_nil_getters = self.class.send(:expose_nil_getters)

      methods_to_serialize.each do |method|
        value = send(method)
        next if value.nil? && !render_nil && !expose_nil_getters.include?(method)

        hash[method] = transform_value_for_serialization(value)
      end

      # Include dynamic alias keys (defined per instance via `as: -> { ... }`).
      if instance_variable_defined?(ALIASES_VAR)
        aliases = instance_variable_get(ALIASES_VAR)
        if aliases && !aliases.empty?
          expose_nil_keys = self.class.send(:expose_nil_property_keys)

          aliases.each do |target_method, alias_method|
            # Skip nested proxy aliases at the top level; nested groups
            # serialize under their container key only.
            next if target_method.is_a?(Symbol) && target_method.to_s.start_with?(NESTED_PREFIX)

            # Read the value from the original target method to avoid issues if
            # the alias method is overridden. Apply the same transformation rules
            # as above for nested twins and arrays.
            value = send(target_method)
            next if value.nil? && !render_nil && !expose_nil_keys.include?(target_method)

            hash[alias_method] = transform_value_for_serialization(value)
          end
        end
      end

      hash
    end

    alias to_h to_hash

    #: (**untyped) -> String
    def to_json(**)
      to_hash(**).to_json
    end

    #: () -> Hash[Symbol, untyped]
    def attributes
      # Use setter-based attribute names and read via `send` to allow
      # accessing protected original readers when aliases (`as:`) are used.
      attribute_methods.each_with_object({}) do |m, h|
        h[m] = send(m) if respond_to?(m, true)
      end
    end

    #: () -> bool
    def valid?
      # If ActiveModel validations are available and included, run them and
      # aggregate nested errors. Otherwise, consider the twin valid.
      if defined?(ActiveModel::Validations) && self.class.ancestors.include?(ActiveModel::Validations)
        super

        self.class.block_properties.each do |property|
          child = send(property)
          next unless child.respond_to?(:valid?)

          child.valid?
          child.errors.each do |attribute|
            errors.add("#{property}.#{attribute.attribute}", attribute.message)
          end
        end

        self.class.collection_properties.each do |property|
          send(property).each_with_index do |value, index|
            next unless value.respond_to?(:valid?)

            value.valid?
            value.errors.each do |attribute|
              errors.add("#{property}[#{index}].#{attribute.attribute}", attribute.message)
            end
          end
        end

        errors.empty?
      else
        # When ActiveModel is not available, consider the twin valid by default.
        true
      end
    end

    #: () -> String
    def inspect
      attrs = to_hash.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      "#<#{self.class.name} #{attrs}>"
    end

    # Internal helper for PrettyPrint. Do not call this on your own.
    #: (PP) -> void
    def pretty_print(pretty_printer)
      pretty_printer.object_group(self) do
        pretty_printer.breakable
        pretty_printer.seplist(
          ordered_attributes_for_pp,
          -> {
            pretty_printer.text(",")
            pretty_printer.breakable
          }
        ) do |(name, value)|
          pretty_printer.group do
            pretty_printer.text name.to_s
            pretty_printer.text ": "
            pretty_printer.pp value
          end
        end
      end
    end

    private

    def transform_value_for_serialization(value)
      case value
      when Minitwin
        value.to_hash
      when Array
        value.filter_map { |item| item.respond_to?(:to_hash) ? item.to_hash : item }
      else
        value
      end
    end

    def ordered_attributes_for_pp
      methods = ordered_methods_for_pp
      attrs = methods.map { |m| [display_name_for(m), send(m)] }
      attrs + dynamic_aliases_for_pp
    end

    def ordered_methods_for_pp
      ordered = self.class.send(:property_order)
      all_methods = self.class.send(:serializable_getters)
      ordered.select { |m| all_methods.include?(m) } + (all_methods - ordered)
    end

    def display_name_for(method)
      meta = self.class.properties[method] || self.class.collections[method]
      meta && meta[:as] && !meta[:as].is_a?(Proc) ? meta[:as] : method
    end

    def dynamic_aliases_for_pp
      return [] unless instance_variable_defined?(ALIASES_VAR)

      aliases = instance_variable_get(ALIASES_VAR)
      return [] unless aliases && !aliases.empty?

      aliases.filter_map do |target_method, alias_method|
        next if target_method.is_a?(Symbol) && target_method.to_s.start_with?(NESTED_PREFIX)

        [alias_method, send(target_method)]
      end
    end

  end
end
