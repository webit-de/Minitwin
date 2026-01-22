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

    def sync(model = nil, validate: true)
      # Resolve target model: explicit parameter, stored :model, or first stored internal model
      target_model = model
      if target_model.nil?
        ivar = self.class.internal_model_name("model")
        target_model = instance_variable_defined?(ivar) ? instance_variable_get(ivar) : nil
        if target_model.nil?
          any_ivar = instance_variables.find { |v| v.to_s.start_with?(MiniTwin::INTERNAL_MODEL_PREFIX) }
          target_model = instance_variable_get(any_ivar) if any_ivar
        end
      end

      return false if validate && !valid?
      return false if target_model.nil?

      # Copy twin values into the given model via public writers when available.
      attribute_methods.each do |method|
        writer = "#{method}="
        # We'll prefer deep sync for nested twins when possible. If not, fall back to writer.
        unless target_model.respond_to?(writer) || target_model.respond_to?(method)
          next
        end

        value = begin
          # Use send to read even when original reader is protected due to aliasing
          send(method)
        rescue NoMethodError
          # If the original reader is protected or missing, skip gracefully
          nil
        end

        # Nested object sync: recursively copy into existing child model if available
        if value.is_a?(MiniTwin)
          if target_model.respond_to?(method)
            begin
              child_model = target_model.public_send(method)
              if child_model
                value.sync(child_model, validate: false)
                next
              end
            rescue StandardError
              # Fall through to assignment below
            end
          end
        elsif value.is_a?(Array)
          if target_model.respond_to?(method)
            begin
              coll = target_model.public_send(method)
              if coll && coll.respond_to?(:each)
                # Prefer id-based matching when possible, then index-based.
                deep_synced_any = false
                id_map = nil
                begin
                  # Build a lookup by id for models that respond to :id
                  if coll.respond_to?(:to_a)
                    array_like = coll.to_a
                  elsif coll.is_a?(Array)
                    array_like = coll
                  else
                    array_like = nil
                  end

                  if array_like && array_like.all? { |m| m.respond_to?(:id) }
                    id_map = array_like.each_with_object({}) { |m, h| h[m.id] = m }
                  end
                rescue StandardError
                  id_map = nil
                end

                value.each_with_index do |elem, idx|
                  next unless elem.is_a?(MiniTwin)
                  target = nil

                  # Try id-based match
                  begin
                    elem_id = elem.send(:id) if elem.respond_to?(:id, true)
                    target ||= id_map[elem_id] if elem_id && id_map
                  rescue StandardError
                    # ignore and try index
                  end

                  # Fallback to index-based
                  if target.nil? && coll.respond_to?(:[])
                    begin
                      target = coll[idx]
                    rescue StandardError
                      target = nil
                    end
                  end

                  if target
                    elem.sync(target, validate: false)
                    deep_synced_any = true
                  end
                end

                # If we deep-synced into existing targets, skip writer fallback
                if deep_synced_any
                  next
                end
              end
            rescue StandardError
              # Continue with assignment fallback
            end
          end
        end

        # Convert nested twins/collections to assignable data for writer fallback
        assignable = case value
        when MiniTwin
          value.to_hash
        when Array
          value.map { |v| v.is_a?(MiniTwin) ? v.to_hash : v }
        else
          value
        end

        begin
          target_model.public_send(writer, assignable)
        rescue StandardError
          # Be defensive: if the model writer raises, continue with other attributes
        end
      end

      true
    end

  end
end
