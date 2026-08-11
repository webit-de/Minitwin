# frozen_string_literal: true
# rbs_inline: enabled

class Minitwin
  # Marker: `rescue Minitwin::Error` catches every gem-specific error.
  module Error; end

  # DSL used incorrectly — fails at class-definition time.
  class DefinitionError < ::ArgumentError
    include Error
  end

  # A source object cannot supply a composed property.
  class CompositionError < ::RuntimeError
    include Error
  end

  # A dynamic alias is invalid, forbidden, or collides.
  class AliasError < ::ArgumentError
    include Error
  end

  # A value cannot be coerced into the expected twin type.
  class CoercionError < ::TypeError
    include Error
  end

  # Input data is structurally unusable (JSON, wrong object type).
  class ParseError < ::ArgumentError
    include Error
  end
end
