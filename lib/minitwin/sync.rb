# frozen_string_literal: true
# rbs_inline: enabled

class Minitwin
  module Sync
    # Cache constant reference for JIT optimization
    MODEL_PREFIX = Minitwin::INTERNAL_MODEL_PREFIX

    #: (untyped, validate: bool) -> bool
    def sync(model = nil, validate: true)
      # Resolve target model
      target_model = model
      if target_model.nil?
        ivar = self.class.internal_model_name("model")
        target_model = instance_variable_defined?(ivar) ? instance_variable_get(ivar) : nil
        if target_model.nil?
          any_ivar = instance_variables.find { |v| v.to_s.start_with?(MODEL_PREFIX) }
          target_model = instance_variable_get(any_ivar) if any_ivar
        end
      end

      return false if validate && !valid?
      return false if target_model.nil?

      attribute_methods.each do |method_name| # rubocop: disable Metrics/BlockLength
        prop_meta = self.class.properties[method_name] || self.class.collections[method_name]
        as_name = prop_meta&.[](:as)
        target_name = as_name.is_a?(Symbol) || as_name.is_a?(String) ? as_name.to_sym : method_name

        writer = :"#{target_name}="
        next unless target_model.respond_to?(writer) || target_model.respond_to?(target_name)

        value = respond_to?(method_name, true) ? send(method_name) : nil

        # Nested twins
        if value.is_a?(Minitwin)
          if target_model.respond_to?(target_name)
            begin
              child_model = target_model.public_send(target_name)
              if child_model
                value.sync(child_model, validate: false)
                next
              end
            rescue StandardError
              # fall through to writer
            end
          end
        elsif value.is_a?(Array)
          if target_model.respond_to?(target_name)
            begin
              coll = target_model.public_send(target_name)
              if coll.respond_to?(:each)
                deep_synced_any = false

                id_map = build_target_id_lookup(coll)

                value.each_with_index do |elem, idx|
                  next unless elem.is_a?(Minitwin)

                  target = nil

                  # Try id-based match first
                  target ||= begin
                    elem_id = elem.respond_to?(:id, true) ? elem.send(:id) : nil
                    id_map && elem_id ? id_map[elem_id] : nil
                  end

                  if target.nil? && coll.respond_to?(:[])
                    begin
                      target = coll[idx]
                    rescue StandardError
                      target = nil
                    end
                  end

                  next unless target

                  elem.sync(target, validate: false)
                  deep_synced_any = true
                  next

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
                     when Minitwin
                       value.to_hash
                     when Array
                       value.map { |v| v.is_a?(Minitwin) ? v.to_hash : v }
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

    # Builds a lookup hash from the provided collection.
    # The collection may be an array or something convertible to an array.
    # The result is a hash map with the ids of the models in the collection as
    # keys and the models itself as values.
    def build_target_id_lookup(coll)
      ary = if coll.is_a?(Array)
              coll
            elsif coll.respond_to?(:to_a)
              coll.to_a
            else
              return nil
            end

      ary.each_with_object({}) do |m, h|
        next unless m.respond_to?(:id)

        key = m.id
        h[key] = m if key
      end
    end

    # No append or match_on helpers
  end
end
