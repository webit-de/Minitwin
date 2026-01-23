class MiniTwin
  module Sync
    def sync(model = nil, validate: true)
      # Resolve target model
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

      attribute_methods.each do |method|
        writer = "#{method}="
        unless target_model.respond_to?(writer) || target_model.respond_to?(method)
          next
        end

        value = begin
          send(method)
        rescue NoMethodError
          nil
        end

        # Nested twins
        if value.is_a?(MiniTwin)
          if target_model.respond_to?(method)
            begin
              child_model = target_model.public_send(method)
              if child_model
                value.sync(child_model, validate: false)
                next
              end
            rescue StandardError
              # fall through to writer
            end
          end
        elsif value.is_a?(Array)
          if target_model.respond_to?(method)
            begin
              coll = target_model.public_send(method)
              if coll && coll.respond_to?(:each)
                deep_synced_any = false

                id_map = build_target_id_lookup(coll)

                value.each_with_index do |elem, idx|
                  next unless elem.is_a?(MiniTwin)
                  target = nil

                  # Try id-based match first
                  target ||= begin
                    elem_id = elem.respond_to?(:id, true) ? elem.send(:id) : nil
                    (id_map && elem_id) ? id_map[elem_id] : nil
                  end

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
                    next
                  end

                  # Unmatched elements are handled later by writer fallback
                end

                next if deep_synced_any
              end
            rescue StandardError
              # continue to writer fallback
            end
          end
        end

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
          # ignore and continue
        end
      end

      true
    end

    private

    def build_target_id_lookup(coll)
      ary = if coll.respond_to?(:to_a)
        coll.to_a
      elsif coll.is_a?(Array)
        coll
      else
        nil
      end
      return nil unless ary

      ary.each_with_object({}) do |m, h|
        key = (m.respond_to?(:id) ? (m.public_send(:id) rescue nil) : nil)
        h[key] = m if key
      end
    end

    # No append or match_on helpers
  end
end
