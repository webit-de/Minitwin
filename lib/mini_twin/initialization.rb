class MiniTwin
  # Instance construction and low-level helpers used by the DSL-generated
  # accessors. Filters unknown keys on initialize and seeds nested block
  # properties so that validations on nested twins can run.
  module Initialization
    def initialize(**args)
      # Filter only attributes that have corresponding writer methods on this class
      allowed_keys = (
        if self.class.respond_to?(:allowed_attribute_keys)
          self.class.allowed_attribute_keys
        else
          self.class.instance_methods(false).grep(/=\z/).map { |m| m.to_s.delete_suffix("=").to_sym }.to_set
        end
      )
      args.select! { |arg, _| allowed_keys.include?(arg.to_sym) }

      getter_defaults =
        self.
          class.
          block_properties.
          select { |method| allowed_keys.include?(method) }.
          index_with { {} }

      super(**getter_defaults.merge(args))
    end

    private

    def assign_attribute(method:, value:)
      if respond_to?("#{method}=")
        send("#{method}=", value)
      else
        instance_variable_set("@#{method}", value)
      end
    end

    def attribute_methods
      public_methods(false).select do |method|
        method_name = method.to_s
        next false if method_name.end_with?("=", "?", "!")

        respond_to?(:"#{method}=")
      end
    end

    def define_instance_variable(name:, value:)
      instance_variable_set("@#{name}".delete_suffix("?"), value)
    end
  end
end
