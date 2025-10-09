require_relative "class_methods/dsl"
require_relative "class_methods/constructors"
require_relative "class_methods/rbs"
require_relative "class_methods/caches"
require_relative "class_methods/types_helper"
require_relative "class_methods/coercion"

class MiniTwin
  # Class-level DSL and public constructors split into focused modules.
  module ClassMethods
    include MiniTwin::ClassMethods::DSL
    include MiniTwin::ClassMethods::Constructors
    include MiniTwin::ClassMethods::RBS
    include MiniTwin::ClassMethods::Caches
    include MiniTwin::ClassMethods::TypesHelper
    include MiniTwin::ClassMethods::Coercion

    # Limit DSL surface to class body usage
    private :property, :collection, :nested

    # Make constructors and RBS API public
    public :from_hash, :from_json, :from_params, :from_object, :from_objects, :from_collection, :to_rbs
  end
end
