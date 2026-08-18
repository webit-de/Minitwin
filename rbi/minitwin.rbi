# typed: true

# DO NOT EDIT MANUALLY.
# Generated from the RBS signatures in sig/ by `rake minitwin:generate_rbi`.

# from sig/generated/minitwin/assignment.rbs
class Minitwin
  module Assignment
    sig { params(arg0: T.untyped).returns(T.self_type) }
    def to_object(arg0); end

    sig { params(arg0: T.untyped).returns(T.self_type) }
    def assign_object(arg0); end

    sig { params(hash: T::Hash[T.any(String, Symbol), T.untyped]).returns(T.self_type) }
    def assign_hash(hash); end

    sig { params(params: T.untyped).returns(T.self_type) }
    def assign_params(params); end

    sig { returns(T::Array[Symbol]) }
    def assignable_attribute_methods; end
  end
end

# from sig/generated/minitwin/class_methods/caches.rbs
class Minitwin
  module ClassMethods
    extend T::Generic
    has_attached_class!(:out)

    module Caches
      extend T::Generic
      has_attached_class!(:out)

      sig { returns(T::Boolean) }
      def dynamic_aliases?; end

      private

      sig { returns(T.untyped) }
      def invalidate_caches; end

      sig { returns(T.untyped) }
      def serializable_getters; end

      sig { returns(T.untyped) }
      def serializable_method_candidates; end

      sig { returns(T.untyped) }
      def declared_property_keys; end

      sig { returns(T.untyped) }
      def twin_class_hierarchy; end

      sig { returns(T.untyped) }
      def allowed_attribute_keys; end

      sig { returns(T.untyped) }
      def allowed_attribute_keys_array; end

      sig { returns(T.untyped) }
      def setter_methods; end
    end
  end
end

# from sig/generated/minitwin/class_methods/constructors.rbs
class Minitwin
  module ClassMethods
    extend T::Generic
    has_attached_class!(:out)

    module Constructors
      extend T::Generic
      has_attached_class!(:out)

      sig { returns(T::Hash[T.untyped, T.untyped]) }
      def properties; end

      sig { returns(T::Hash[T.untyped, T.untyped]) }
      def collections; end

      sig { params(args: T::Hash[T.untyped, T.untyped]).returns(T.attached_class) }
      def from_hash(args); end

      sig { params(body: String).returns(T.attached_class) }
      def from_json(body); end

      sig { params(params: T.untyped).returns(T.attached_class) }
      def from_params(params); end

      sig { params(model: T.untyped).returns(T.attached_class) }
      def from_object(model); end

      sig { params(models: T.untyped).returns(T.untyped) }
      def from_objects(**models); end

      sig { params(models: T::Array[T.untyped]).returns(T::Array[T.attached_class]) }
      def from_collection(models); end

      sig { params(name: Symbol).returns(String) }
      def internal_model_name(name); end

      sig { params(attributes: T.untyped, models: T.untyped).returns(T.untyped) }
      def enrich_attributes_from_models!(attributes, models); end

      sig { params(attributes: T.untyped, models: T.untyped, key: T.untyped, is_collection: T.untyped).returns(T.untyped) }
      def enrich_attribute_from_models(attributes, models, key, is_collection:); end
    end
  end
end

# from sig/generated/minitwin/class_methods/dsl.rbs
class Minitwin
  module ClassMethods
    extend T::Generic
    has_attached_class!(:out)

    module Dsl
      extend T::Generic
      has_attached_class!(:out)

      sig { returns(T::Array[Symbol]) }
      def block_properties; end

      sig { returns(T::Array[Symbol]) }
      def collection_properties; end

      sig { returns(T::Array[Symbol]) }
      def unexposed_properties; end

      sig { returns(T::Array[Symbol]) }
      def property_order; end

      sig { returns(T::Array[T::Hash[T.untyped, T.untyped]]) }
      def dynamic_nested_aliases; end

      private

      sig { params(name: Symbol, validates: T::Hash[Symbol, T.untyped], default: T.untyped, as: T.untyped, getter: Proc, twin: T.untyped, on: Symbol, _opts: T.untyped, blk: T.untyped).void }
      def collection(name, validates: T.unsafe(nil), default: T.unsafe(nil), as: T.unsafe(nil), getter: T.unsafe(nil), twin: T.unsafe(nil), on: T.unsafe(nil), **_opts, &blk); end

      sig { params(name: Symbol, validates: T::Hash[Symbol, T.untyped], default: T.untyped, as: T.untyped, expose: T::Boolean, readonly: T::Boolean, type: T.untyped, getter: Proc, setter: Proc, twin: T.untyped, on: Symbol, _opts: T.untyped, blk: T.untyped).void }
      def property(name, validates: T.unsafe(nil), default: T.unsafe(nil), as: T.unsafe(nil), expose: T.unsafe(nil), readonly: T.unsafe(nil), type: T.unsafe(nil), getter: T.unsafe(nil), setter: T.unsafe(nil), twin: T.unsafe(nil), on: T.unsafe(nil), **_opts, &blk); end

      sig { params(name: Symbol, as: T.untyped, blk: T.untyped).void }
      def nested(name, as: T.unsafe(nil), &blk); end

      sig { params(name: T.untyped).returns(T.untyped) }
      def constantize_name(name); end

      sig { params(name: T.untyped, blk: T.untyped).returns(T.untyped) }
      def create_nested_class(name:, &blk); end

      sig { params(name: T.untyped, as: T.untyped, on: T.untyped, default: T.untyped, getter: T.untyped, type: T.untyped).returns(T.untyped) }
      def define_getter_method(name:, as:, on:, default:, getter:, type: T.unsafe(nil)); end

      sig { params(name: T.untyped, on: T.untyped, default: T.untyped, getter: T.untyped, type: T.untyped).returns(T.untyped) }
      def build_getter_proc(name:, on:, default:, getter:, type:); end

      sig { params(name: T.untyped, on: T.untyped, default: T.untyped, type: T.untyped).returns(T.untyped) }
      def build_composition_getter(name:, on:, default:, type:); end

      sig { params(name: T.untyped, default: T.untyped, type: T.untyped).returns(T.untyped) }
      def build_regular_getter(name:, default:, type:); end

      sig { params(name: T.untyped, as: T.untyped).returns(T.untyped) }
      def apply_alias_to_getter(name:, as:); end

      sig { params(name: T.untyped, validates: T.untyped).returns(T.untyped) }
      def add_validation(name:, validates:); end

      sig { params(name: T.untyped, expose: T.untyped).returns(T.untyped) }
      def add_unexposed_property(name:, expose:); end

      sig { params(name: T.untyped).returns(T.untyped) }
      def add_block_property(name:); end

      sig { params(name: T.untyped).returns(T.untyped) }
      def add_collection_property(name:); end

      sig { params(name: T.untyped).returns(T.untyped) }
      def add_to_property_order(name); end

      sig { params(default: T.untyped, type: T.untyped).returns(T.untyped) }
      def resolve_default_value(default, type); end
    end
  end
end

# from sig/generated/minitwin/class_methods/rbs.rbs
class Minitwin
  module ClassMethods
    extend T::Generic
    has_attached_class!(:out)

    module Rbs
      extend T::Generic
      has_attached_class!(:out)

      sig { returns(String) }
      def to_rbs; end

      private

      sig { params(meta: T.untyped).returns(T.untyped) }
      def rbs_type_for(meta); end

      sig { params(meta: T.untyped).returns(T.untyped) }
      def rbs_elem_type_for(meta); end

      sig { params(klass: T.untyped).returns(T.untyped) }
      def rbs_class_name(klass); end

      sig { params(dry_type: T.untyped).returns(T.untyped) }
      def dry_type_to_rbs(dry_type); end
    end
  end
end

# from sig/generated/minitwin/initialization.rbs
class Minitwin
  module Initialization
    ALIASES_VAR = T.let(T.unsafe(nil), T.untyped)

    ALIASES_REV_VAR = T.let(T.unsafe(nil), T.untyped)

    FORBIDDEN_ALIAS_NAMES = T.let(T.unsafe(nil), T.untyped)

    sig { params(kwargs: T.untyped).void }
    def initialize(**kwargs); end

    private

    sig { params(method: T.untyped, value: T.untyped).returns(T.untyped) }
    def assign_attribute(method:, value:); end

    sig { returns(T.untyped) }
    def attribute_methods; end

    sig { params(name: T.untyped, value: T.untyped).returns(T.untyped) }
    def define_instance_variable(name:, value:); end

    sig { returns(T.untyped) }
    def __recompute_dynamic_aliases__; end

    sig { params(collection_method: T.untyped).returns(T.untyped) }
    def __recompute_aliases_for_collection__(collection_method); end

    sig { returns(T.untyped) }
    def __recompute_nested_aliases__; end

    sig { params(as_proc: T.untyped).returns(T.untyped) }
    def __compute_alias_name__(as_proc); end

    sig { params(entry: T.untyped).returns(T.untyped) }
    def __compute_nested_alias_name__(entry); end

    sig { params(target_method: T.untyped, alias_name: T.untyped).returns(T.untyped) }
    def __apply_dynamic_alias__(target_method, alias_name); end

    sig { returns(T.untyped) }
    def dynamic_aliases; end
  end
end

# from sig/generated/minitwin/rbi.rbs
class Minitwin
  module Rbi
    SIGIL = T.let(T.unsafe(nil), ::String)

    GENERATED_NOTICE = T.let(T.unsafe(nil), T.untyped)

    sig { params(arg0: Module).returns(T::Array[String]) }
    def extended_modules(arg0); end

    sig { params(arg0: Module).returns(T::Array[String]) }
    def self.extended_modules(arg0); end

    sig { params(arg0: String, extended_modules: T::Array[String]).returns(String) }
    def from_rbs(arg0, extended_modules: T.unsafe(nil)); end

    sig { params(arg0: String, extended_modules: T::Array[String]).returns(String) }
    def self.from_rbs(arg0, extended_modules: T.unsafe(nil)); end

    sig { params(arg0: T::Array[String], relative_to: String, extended_modules: T::Array[String]).returns(String) }
    def from_rbs_files(arg0, relative_to: T.unsafe(nil), extended_modules: T.unsafe(nil)); end

    sig { params(arg0: T::Array[String], relative_to: String, extended_modules: T::Array[String]).returns(String) }
    def self.from_rbs_files(arg0, relative_to: T.unsafe(nil), extended_modules: T.unsafe(nil)); end

    sig { params(arg0: String, arg1: String, arg2: T::Array[String]).returns(T::Array[String]) }
    def translate(arg0, arg1, arg2); end

    sig { params(arg0: String, arg1: String, arg2: T::Array[String]).returns(T::Array[String]) }
    def self.translate(arg0, arg1, arg2); end

    sig { params(arg0: T::Array[T::Array[String]]).returns(T::Array[String]) }
    def space_out(arg0); end

    sig { params(arg0: T::Array[T::Array[String]]).returns(T::Array[String]) }
    def self.space_out(arg0); end

    class Position < Data
      sig { returns(T.untyped) }
      attr_reader :attached

      sig { returns(T.untyped) }
      attr_reader :singleton

      sig { returns(T.untyped) }
      attr_reader :out

      sig { returns(T.untyped) }
      attr_reader :nested

      # NOTE: 1 further RBS overload of `new` dropped; Sorbet RBI has no overloads.
      sig { params(attached: T.untyped, singleton: T.untyped, out: T.untyped, nested: T.untyped).returns(T.attached_class) }
      def self.new(attached, singleton, out, nested); end

      sig { returns([Symbol, Symbol, Symbol, Symbol]) }
      def self.members; end

      sig { returns([Symbol, Symbol, Symbol, Symbol]) }
      def members; end
    end

    PLAIN = T.let(T.unsafe(nil), T.untyped)

    class Context < Data
      sig { returns(T.untyped) }
      attr_reader :namespace

      sig { returns(T.untyped) }
      attr_reader :extended

      sig { returns(T.untyped) }
      attr_reader :in_class

      sig { returns(T.untyped) }
      attr_reader :attached_module

      # NOTE: 1 further RBS overload of `new` dropped; Sorbet RBI has no overloads.
      sig { params(namespace: T.untyped, extended: T.untyped, in_class: T.untyped, attached_module: T.untyped).returns(T.attached_class) }
      def self.new(namespace, extended, in_class, attached_module); end

      sig { returns([Symbol, Symbol, Symbol, Symbol]) }
      def self.members; end

      sig { returns([Symbol, Symbol, Symbol, Symbol]) }
      def members; end
    end

    sig { params(arg0: T.untyped, arg1: Integer, arg2: T.untyped).returns(T::Array[String]) }
    def declaration_lines(arg0, arg1, arg2); end

    sig { params(arg0: T.untyped, arg1: Integer, arg2: T.untyped).returns(T::Array[String]) }
    def self.declaration_lines(arg0, arg1, arg2); end

    sig { params(arg0: T.untyped).returns(String) }
    def class_header(arg0); end

    sig { params(arg0: T.untyped).returns(String) }
    def self.class_header(arg0); end

    sig { params(arg0: String, arg1: T.untyped, arg2: Integer, arg3: T.untyped).returns(T::Array[String]) }
    def namespace_lines(arg0, arg1, arg2, arg3); end

    sig { params(arg0: String, arg1: T.untyped, arg2: Integer, arg3: T.untyped).returns(T::Array[String]) }
    def self.namespace_lines(arg0, arg1, arg2, arg3); end

    VARIANCES = T.let(T.unsafe(nil), T.untyped)

    sig { params(arg0: T.untyped, arg1: Integer, arg2: T.untyped).returns(T::Array[T::Array[String]]) }
    def generic_groups(arg0, arg1, arg2); end

    sig { params(arg0: T.untyped, arg1: Integer, arg2: T.untyped).returns(T::Array[T::Array[String]]) }
    def self.generic_groups(arg0, arg1, arg2); end

    sig { params(arg0: T.untyped).returns(String) }
    def type_member_line(arg0); end

    sig { params(arg0: T.untyped).returns(String) }
    def self.type_member_line(arg0); end

    MIXINS = T.let(T.unsafe(nil), T.untyped)

    ATTRIBUTES = T.let(T.unsafe(nil), T.untyped)

    sig { params(arg0: T.untyped, arg1: Integer, arg2: T.untyped).returns(T::Array[String]) }
    def member_lines(arg0, arg1, arg2); end

    sig { params(arg0: T.untyped, arg1: Integer, arg2: T.untyped).returns(T::Array[String]) }
    def self.member_lines(arg0, arg1, arg2); end

    sig { params(arg0: T.untyped, arg1: Integer, arg2: Symbol, arg3: T.untyped).returns(T::Array[String]) }
    def attribute_lines(arg0, arg1, arg2, arg3); end

    sig { params(arg0: T.untyped, arg1: Integer, arg2: Symbol, arg3: T.untyped).returns(T::Array[String]) }
    def self.attribute_lines(arg0, arg1, arg2, arg3); end

    sig { params(arg0: T.untyped, arg1: String, arg2: String, arg3: Symbol).returns(T::Array[String]) }
    def singleton_attribute_lines(arg0, arg1, arg2, arg3); end

    sig { params(arg0: T.untyped, arg1: String, arg2: String, arg3: Symbol).returns(T::Array[String]) }
    def self.singleton_attribute_lines(arg0, arg1, arg2, arg3); end

    RECEIVERS = T.let(T.unsafe(nil), T.untyped)

    sig { params(arg0: T.untyped, arg1: Integer, arg2: T.untyped).returns(T::Array[String]) }
    def method_lines(arg0, arg1, arg2); end

    sig { params(arg0: T.untyped, arg1: Integer, arg2: T.untyped).returns(T::Array[String]) }
    def self.method_lines(arg0, arg1, arg2); end

    sig { params(arg0: T.untyped, arg1: T.untyped, attached: T::Boolean, singleton: T::Boolean).returns(String) }
    def method_return(arg0, arg1, attached:, singleton:); end

    sig { params(arg0: T.untyped, arg1: T.untyped, attached: T::Boolean, singleton: T::Boolean).returns(String) }
    def self.method_return(arg0, arg1, attached:, singleton:); end

    sig { params(arg0: T.untyped, arg1: String).returns(T::Array[String]) }
    def overload_notice(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: String).returns(T::Array[String]) }
    def self.overload_notice(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(T::Array[[String, String, String]]) }
    def parameter_specs(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(T::Array[[String, String, String]]) }
    def self.parameter_specs(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(T::Array[[String, String, String]]) }
    def positional_specs(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(T::Array[[String, String, String]]) }
    def self.positional_specs(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: Integer).returns(String) }
    def positional_name(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: Integer).returns(String) }
    def self.positional_name(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(T::Array[[String, String, String]]) }
    def keyword_specs(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(T::Array[[String, String, String]]) }
    def self.keyword_specs(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(T.nilable([String, String, String])) }
    def block_spec(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(T.nilable([String, String, String])) }
    def self.block_spec(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def block_type(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def self.block_type(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def return_clause(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def self.return_clause(arg0, arg1); end

    GENERIC_STDLIB = T.let(T.unsafe(nil), T.untyped)

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def rbi_type(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def self.rbi_type(arg0, arg1); end

    sig { params(arg0: T.untyped).returns(String) }
    def self_type(arg0); end

    sig { params(arg0: T.untyped).returns(String) }
    def self.self_type(arg0); end

    sig { params(arg0: T.untyped).returns(String) }
    def instance_type(arg0); end

    sig { params(arg0: T.untyped).returns(String) }
    def self.instance_type(arg0); end

    sig { params(arg0: T::Array[T.untyped], arg1: T.untyped).returns(String) }
    def type_list(arg0, arg1); end

    sig { params(arg0: T::Array[T.untyped], arg1: T.untyped).returns(String) }
    def self.type_list(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def class_instance_type(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def self.class_instance_type(arg0, arg1); end

    LITERAL_CLASSES = T.let(T.unsafe(nil), T.untyped)

    sig { params(arg0: T.untyped).returns(String) }
    def literal_type(arg0); end

    sig { params(arg0: T.untyped).returns(String) }
    def self.literal_type(arg0); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def record_type(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def self.record_type(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def proc_from_function(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def self.proc_from_function(arg0, arg1); end

    sig { params(arg0: T.untyped).returns(T::Array[[String, T.untyped]]) }
    def positional_pairs(arg0); end

    sig { params(arg0: T.untyped).returns(T::Array[[String, T.untyped]]) }
    def self.positional_pairs(arg0); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def union_type(arg0, arg1); end

    sig { params(arg0: T.untyped, arg1: T.untyped).returns(String) }
    def self.union_type(arg0, arg1); end

    sig { params(arg0: String).returns(String) }
    def nilable(arg0); end

    sig { params(arg0: String).returns(String) }
    def self.nilable(arg0); end
  end
end

# from sig/generated/minitwin/serialization.rbs
class Minitwin
  module Serialization
    ALIASES_VAR = T.let(T.unsafe(nil), T.untyped)

    NESTED_PREFIX = T.let(T.unsafe(nil), T.untyped)

    sig { params(render_nil: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
    def to_hash(render_nil:); end

    alias to_h to_hash

    sig { params(kwargs: T.untyped).returns(String) }
    def to_json(**kwargs); end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def attributes; end

    sig { returns(T::Boolean) }
    def valid?; end

    sig { returns(String) }
    def inspect; end

    sig { params(arg0: PP).void }
    def pretty_print(arg0); end

    private

    sig { params(value: T.untyped).returns(T.untyped) }
    def transform_value_for_serialization(value); end

    sig { returns(T.untyped) }
    def ordered_attributes_for_pp; end

    sig { returns(T.untyped) }
    def ordered_methods_for_pp; end

    sig { params(method: T.untyped).returns(T.untyped) }
    def display_name_for(method); end

    sig { returns(T.untyped) }
    def dynamic_aliases_for_pp; end
  end
end

# from sig/generated/minitwin/sync.rbs
class Minitwin
  module Sync
    MODEL_PREFIX = T.let(T.unsafe(nil), T.untyped)

    sig { params(arg0: T.untyped, validate: T::Boolean).returns(T::Boolean) }
    def sync(arg0, validate:); end

    private

    sig { params(coll: T.untyped).returns(T.untyped) }
    def build_target_id_lookup(coll); end
  end
end
