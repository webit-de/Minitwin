class MiniTwin
  module Initialization
    def initialize(**args)
      allowed_keys = self.class.instance_methods(false).to_set
      args.select! { |arg, _| allowed_keys.include?(arg.to_sym) }

      getter_defaults =
        self.
          class.
          block_properties.
          select { |method| allowed_keys.include?(method) }.
          index_with { nil }

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
