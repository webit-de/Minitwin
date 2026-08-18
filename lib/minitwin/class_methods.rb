# frozen_string_literal: true

require_relative "class_methods/dsl"
require_relative "class_methods/constructors"
require_relative "class_methods/rbs"
require_relative "class_methods/caches"
require_relative "class_methods/types_helper"
require_relative "class_methods/coercion"

class Minitwin
  # Class-level DSL and public constructors split into focused modules.
  module ClassMethods
    include Minitwin::ClassMethods::Dsl
    include Minitwin::ClassMethods::Constructors
    include Minitwin::ClassMethods::Rbs
    include Minitwin::ClassMethods::Caches
    include Minitwin::ClassMethods::TypesHelper
    include Minitwin::ClassMethods::Coercion

    # The DSL surface is limited to class body usage by Minitwin::ClassMethods::Dsl
    # itself; declaring it here would install visibility stubs that shadow the
    # typed originals.
  end
end
