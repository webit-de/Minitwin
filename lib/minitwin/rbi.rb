# frozen_string_literal: true
# rbs_inline: enabled

require "pathname"
require "rbs"

class Minitwin
  # Translates RBS signatures into Sorbet RBI files, so that Sorbet users can
  # consume a gem that is typed with RBS only. The two languages overlap but do
  # not match: constructs without a faithful counterpart degrade to T.untyped
  # rather than producing an RBI Sorbet would reject.
  module Rbi
    module_function

    SIGIL = "# typed: true"
    GENERATED_NOTICE = [
      "# DO NOT EDIT MANUALLY.",
      "# Generated from the RBS signatures in sig/ by `rake minitwin:generate_rbi`."
    ].freeze

    # The names of the modules below `root` that reach it through `extend`
    # rather than `include`, ready to be passed to #from_rbs_files. This is the
    # one piece of information the RBS signatures cannot carry, so it has to be
    # read off the loaded runtime.
    #: (Module) -> Array[String]
    def extended_modules(root)
      own = ->(mod) { mod.instance_of?(Module) && mod.name&.start_with?("#{root.name}::") }

      (root.singleton_class.ancestors.select(&own) - root.ancestors).map(&:name)
    end

    # Translates a single RBS source string into an RBI file body.
    #
    # extended_modules lists the fully qualified names of modules that are mixed
    # in with `extend` rather than `include`. RBS spells both the same way, but
    # Sorbet needs to tell them apart (see #instance_type).
    #: (String, ?extended_modules: Array[String]) -> String
    def from_rbs(source, extended_modules: [])
      "#{SIGIL}\n\n#{translate(source, "(rbs)", extended_modules).join("\n")}\n"
    end

    # Translates several RBS files into one RBI file, one section per input
    # file. Reopening the same class per section is valid Ruby, so no merging
    # of namespaces is needed.
    #: (Array[String], ?relative_to: String, ?extended_modules: Array[String]) -> String
    def from_rbs_files(paths, relative_to: Dir.pwd, extended_modules: [])
      root = Pathname(File.expand_path(relative_to))
      sections = paths.filter_map do |path|
        lines = translate(File.read(path), path, extended_modules)
        next if lines.empty?

        ["# from #{Pathname(File.expand_path(path)).relative_path_from(root)}", *lines]
      end

      "#{[[SIGIL], GENERATED_NOTICE, *sections].map { |chunk| chunk.join("\n") }.join("\n\n")}\n"
    end

    #: (String, String, Array[String]) -> Array[String]
    def translate(source, name, extended_modules)
      buffer = RBS::Buffer.new(name: Pathname(name), content: source)
      _buffer, _directives, decls = RBS::Parser.parse_signature(buffer)
      context = Context.new(
        namespace: [],
        extended: extended_modules.map { |mod| mod.to_s.delete_prefix("::") },
        in_class: false,
        attached_module: false
      )

      space_out(decls.map { |decl| declaration_lines(decl, 0, context) })
    end

    # Joins line groups with a blank line between them.
    #: (Array[Array[String]]) -> Array[String]
    def space_out(groups)
      groups.reject(&:empty?).flat_map.with_index { |group, index| index.zero? ? group : ["", *group] }
    end

    # Sorbet accepts T.self_type and T.attached_class only in specific
    # positions, so the translator tracks where a type is being written:
    # whether an attached class exists in this scope, whether the method is a
    # singleton method, whether the position is an output position (`returns`),
    # and whether the type sits nested inside another type.
    Position = Data.define(:attached, :singleton, :out, :nested) do
      def nest
        with(nested: true)
      end
    end

    # Position for types that can never be self-referential, such as constant
    # types and type parameter bounds.
    PLAIN = Position.new(attached: false, singleton: false, out: false, nested: true)

    # The declaration the translator is currently inside: the enclosing
    # namespace, the configured extended module names, and what those imply for
    # the members being written.
    Context = Data.define(:namespace, :extended, :in_class, :attached_module) do
      def enter(name, in_class:)
        path = namespace + [name.to_s.delete_prefix("::")]
        with(namespace: path, in_class:, attached_module: !in_class && extended.include?(path.join("::")))
      end

      # Whether T.attached_class is available for a member with this receiver.
      def attached?(singleton:)
        singleton ? in_class : attached_module
      end
    end

    #: (untyped, Integer, untyped) -> Array[String]
    def declaration_lines(decl, indent, context)
      pad = "  " * indent
      case decl
      when RBS::AST::Declarations::Class
        namespace_lines(class_header(decl), decl, indent, context.enter(decl.name, in_class: true))
      when RBS::AST::Declarations::Module
        namespace_lines("module #{decl.name}", decl, indent, context.enter(decl.name, in_class: false))
      when RBS::AST::Declarations::Constant
        ["#{pad}#{decl.name.name} = T.let(T.unsafe(nil), #{rbi_type(decl.type, PLAIN)})"]
      # Interfaces and type aliases have no RBI counterpart; references to them
      # degrade to T.untyped at the use site.
      else []
      end
    end

    #: (untyped) -> String
    def class_header(decl)
      superclass = decl.super_class ? " < #{decl.super_class.name}" : ""
      "class #{decl.name}#{superclass}"
    end

    #: (String, untyped, Integer, untyped) -> Array[String]
    def namespace_lines(header, decl, indent, context)
      pad = "  " * indent
      members = decl.members.map { |member| member_lines(member, indent + 1, context) }
      body = space_out(generic_groups(decl, indent + 1, context) + members)

      ["#{pad}#{header}", *body, "#{pad}end"]
    end

    VARIANCES = { covariant: ":out", contravariant: ":in" }.freeze

    # Sorbet expresses RBS type parameters as type_member assignments, and an
    # extended module's attached class as has_attached_class!. Both need
    # T::Generic.
    #: (untyped, Integer, untyped) -> Array[Array[String]]
    def generic_groups(decl, indent, context)
      return [] if decl.type_params.empty? && !context.attached_module

      pad = "  " * indent
      attached = context.attached_module ? ["#{pad}has_attached_class!(:out)"] : []
      members = decl.type_params.map { |param| "#{pad}#{type_member_line(param)}" }

      [["#{pad}extend T::Generic", *attached], members]
    end

    #: (untyped) -> String
    def type_member_line(param)
      variance = VARIANCES[param.variance]
      bound = param.upper_bound ? " { { upper: #{rbi_type(param.upper_bound, PLAIN)} } }" : ""

      "#{param.name} = type_member#{"(#{variance})" if variance}#{bound}"
    end

    MIXINS = {
      RBS::AST::Members::Include => "include",
      RBS::AST::Members::Extend => "extend",
      RBS::AST::Members::Prepend => "prepend"
    }.freeze

    ATTRIBUTES = {
      RBS::AST::Members::AttrReader => :reader,
      RBS::AST::Members::AttrWriter => :writer,
      RBS::AST::Members::AttrAccessor => :accessor
    }.freeze

    #: (untyped, Integer, untyped) -> Array[String]
    def member_lines(member, indent, context)
      pad = "  " * indent
      case member
      when RBS::AST::Members::MethodDefinition then method_lines(member, indent, context)
      when RBS::AST::Declarations::Base then declaration_lines(member, indent, context)
      when RBS::AST::Members::Private then ["#{pad}private"]
      when RBS::AST::Members::Public then ["#{pad}public"]
      when RBS::AST::Members::Alias then ["#{pad}alias #{member.new_name} #{member.old_name}"]
      when *MIXINS.keys then ["#{pad}#{MIXINS.fetch(member.class)} #{member.name}"]
      when *ATTRIBUTES.keys
        attribute_lines(member, indent, ATTRIBUTES.fetch(member.class), context)
      # Instance variable declarations have no RBI counterpart: Sorbet types
      # instance variables through T.let in the implementation itself.
      else []
      end
    end

    #: (untyped, Integer, Symbol, untyped) -> Array[String]
    def attribute_lines(member, indent, mode, context)
      pad = "  " * indent
      singleton = member.kind == :singleton
      # An attr_writer takes its type as an argument, where a self type is not
      # allowed; a reader returns it.
      out = mode != :writer
      attached = context.attached?(singleton:)
      type = rbi_type(member.type, Position.new(attached:, singleton:, out:, nested: false))
      return singleton_attribute_lines(member, pad, type, mode) if singleton

      sig = mode == :writer ? "params(#{member.name}: #{type}).returns(#{type})" : "returns(#{type})"
      prefix = member.visibility ? "#{member.visibility} " : ""
      ["#{pad}sig { #{sig} }", "#{pad}#{prefix}attr_#{mode} :#{member.name}"]
    end

    # Singleton attributes become plain singleton methods; that is equivalent
    # for the type checker and avoids emitting a `class << self` block.
    #: (untyped, String, String, Symbol) -> Array[String]
    def singleton_attribute_lines(member, pad, type, mode)
      name = member.name
      reader = ["#{pad}sig { returns(#{type}) }", "#{pad}def self.#{name}; end"]
      writer = ["#{pad}sig { params(#{name}: #{type}).returns(#{type}) }",
                "#{pad}def self.#{name}=(#{name}); end"]

      case mode
      when :reader then reader
      when :writer then writer
      else reader + [""] + writer
      end
    end

    # RBS `def self?.x` defines the method on both receivers.
    RECEIVERS = { instance: [""], singleton: ["self."], singleton_instance: ["", "self."] }.freeze

    #: (untyped, Integer, untyped) -> Array[String]
    def method_lines(member, indent, context)
      pad = "  " * indent
      method_type = member.overloads.first.method_type
      visibility = member.visibility ? "#{member.visibility} " : ""

      definitions = RECEIVERS.fetch(member.kind).map do |receiver|
        singleton = !receiver.empty?
        attached = context.attached?(singleton:)
        specs = parameter_specs(method_type, Position.new(attached:, singleton:, out: false, nested: false))
        params = specs.map { |name, type, _decl| "#{name}: #{type}" }
        arguments = specs.map { |_name, _type, decl| decl }

        ["#{pad}sig { #{"params(#{params.join(", ")})." unless params.empty?}" \
          "#{method_return(member, method_type, attached:, singleton:)} }",
         "#{pad}#{visibility}def #{receiver}#{member.name}" \
           "#{"(#{arguments.join(", ")})" unless arguments.empty?}; end"]
      end

      overload_notice(member, pad) + space_out(definitions)
    end

    #: (untyped, untyped, attached: bool, singleton: bool) -> String
    def method_return(member, method_type, attached:, singleton:)
      # Sorbet insists on a void initialize, whatever RBS declares.
      return "void" if member.name == :initialize && !singleton

      return_clause(
        method_type.type.return_type,
        Position.new(attached:, singleton:, out: true, nested: false)
      )
    end

    #: (untyped, String) -> Array[String]
    def overload_notice(member, pad)
      dropped = member.overloads.size - 1
      return [] unless dropped.positive?

      ["#{pad}# NOTE: #{dropped} further RBS overload#{"s" if dropped > 1} of " \
        "`#{member.name}` dropped; Sorbet RBI has no overloads."]
    end

    # Returns [name, rbi_type, ruby_declaration] triples in Ruby's required order.
    #: (untyped, untyped) -> Array[[String, String, String]]
    def parameter_specs(method_type, position)
      function = method_type.type
      specs = positional_specs(function, position) + keyword_specs(function, position)
      block = block_spec(method_type, position)

      block ? specs + [block] : specs
    end

    #: (untyped, untyped) -> Array[[String, String, String]]
    def positional_specs(function, position)
      index = -1
      required = function.required_positionals.map do |param|
        name = positional_name(param, index += 1)
        [name, rbi_type(param.type, position), name]
      end
      optional = function.optional_positionals.map do |param|
        name = positional_name(param, index += 1)
        [name, rbi_type(param.type, position), "#{name} = T.unsafe(nil)"]
      end
      rest = function.rest_positionals
      return required + optional unless rest

      name = rest.name&.to_s || "args"
      required + optional + [[name, rbi_type(rest.type, position), "*#{name}"]]
    end

    #: (untyped, Integer) -> String
    def positional_name(param, index)
      param.name&.to_s || "arg#{index}"
    end

    #: (untyped, untyped) -> Array[[String, String, String]]
    def keyword_specs(function, position)
      required = function.required_keywords.map do |name, param|
        [name.to_s, rbi_type(param.type, position), "#{name}:"]
      end
      optional = function.optional_keywords.map do |name, param|
        [name.to_s, rbi_type(param.type, position), "#{name}: T.unsafe(nil)"]
      end
      rest = function.rest_keywords
      return required + optional unless rest

      name = rest.name&.to_s || "kwargs"
      required + optional + [[name, rbi_type(rest.type, position), "**#{name}"]]
    end

    #: (untyped, untyped) -> [String, String, String]?
    def block_spec(method_type, position)
      block = method_type.block
      return nil unless block

      ["blk", block_type(block, position), "&blk"]
    end

    #: (untyped, untyped) -> String
    def block_type(block, position)
      # A block with untyped parameters has no T.proc equivalent.
      return "T.untyped" if block.type.is_a?(RBS::Types::UntypedFunction)

      proc_string = proc_from_function(block.type, position)
      block.required ? proc_string : nilable(proc_string)
    end

    # `void` is a return-position-only construct in both languages.
    #: (untyped, untyped) -> String
    def return_clause(type, position)
      return "void" if type.is_a?(RBS::Types::Bases::Void)

      "returns(#{rbi_type(type, position)})"
    end

    # Stdlib classes Sorbet models as generics under the T:: namespace,
    # mapped to the arity Sorbet expects.
    GENERIC_STDLIB = {
      "Array" => 1, "Set" => 1, "Enumerable" => 1, "Enumerator" => 1,
      "Range" => 1, "Hash" => 2
    }.freeze

    #: (untyped, untyped) -> String
    def rbi_type(type, position)
      case type
      when RBS::Types::Bases::Bool then "T::Boolean"
      when RBS::Types::Bases::Void then "void"
      when RBS::Types::Bases::Nil then "NilClass"
      when RBS::Types::Bases::Self then self_type(position)
      when RBS::Types::Bases::Instance then instance_type(position)
      when RBS::Types::Bases::Top then "T.anything"
      when RBS::Types::Bases::Bottom then "T.noreturn"
      when RBS::Types::Optional then nilable(rbi_type(type.type, position))
      when RBS::Types::Union then union_type(type, position)
      when RBS::Types::Intersection then "T.all(#{type_list(type.types, position.nest)})"
      when RBS::Types::ClassInstance then class_instance_type(type, position)
      when RBS::Types::ClassSingleton then "T.class_of(#{type.name})"
      when RBS::Types::Literal then literal_type(type)
      when RBS::Types::Tuple then "[#{type_list(type.types, position.nest)}]"
      when RBS::Types::Record then record_type(type, position.nest)
      when RBS::Types::Proc then proc_from_function(type.type, position.nest)
      when RBS::Types::Variable then type.name.to_s
      # untyped, the RBS `class` type, interfaces, type aliases and anything the
      # RBS grammar grows later have no faithful Sorbet counterpart.
      else "T.untyped"
      end
    end

    # T.self_type is allowed in output positions only, and never nested inside
    # another type.
    #: (untyped) -> String
    def self_type(position)
      position.out && !position.nested ? "T.self_type" : "T.untyped"
    end

    #: (untyped) -> String
    def instance_type(position)
      return "T.attached_class" if position.attached && position.out
      # In an instance method of a class or of an included module, RBS'
      # `instance` is the receiver's own type.
      return self_type(position) unless position.singleton

      # A singleton method on a module has no attached class to speak of,
      # because modules cannot be instantiated.
      "T.untyped"
    end

    #: (Array[untyped], untyped) -> String
    def type_list(types, position)
      types.map { |type| rbi_type(type, position) }.join(", ")
    end

    #: (untyped, untyped) -> String
    def class_instance_type(type, position)
      name = type.name.to_s
      bare_name = name.delete_prefix("::")
      args = type.args.map { |arg| rbi_type(arg, position.nest) }
      arity = GENERIC_STDLIB[bare_name]

      if arity
        args = ["T.untyped"] * arity if args.empty?
        return "T::#{bare_name}[#{args.join(", ")}]"
      end

      args.empty? ? name : "#{name}[#{args.join(", ")}]"
    end

    LITERAL_CLASSES = {
      "Symbol" => "Symbol", "String" => "String", "Integer" => "Integer",
      "TrueClass" => "T::Boolean", "FalseClass" => "T::Boolean"
    }.freeze

    # Sorbet has no literal types, so widen to the literal's class.
    #: (untyped) -> String
    def literal_type(type)
      LITERAL_CLASSES.fetch(type.literal.class.name, "T.untyped")
    end

    #: (untyped, untyped) -> String
    def record_type(type, position)
      fields = type.fields.map { |name, field| "#{name}: #{rbi_type(field, position)}" }
      "{#{fields.join(", ")}}"
    end

    #: (untyped, untyped) -> String
    def proc_from_function(function, position)
      params = positional_pairs(function).map { |name, type| "#{name}: #{rbi_type(type, position)}" }
      prefix = params.empty? ? "T.proc" : "T.proc.params(#{params.join(", ")})"

      "#{prefix}.#{return_clause(function.return_type, position)}"
    end

    # RBS positional parameters may be anonymous; Sorbet always needs a name.
    #: (untyped) -> Array[[String, untyped]]
    def positional_pairs(function)
      positionals = function.required_positionals + function.optional_positionals
      positionals.each_with_index.map { |param, index| [positional_name(param, index), param.type] }
    end

    # RBS spells nilability as a union member; Sorbet as a wrapper. A single
    # non-nil member still counts as top level for Sorbet, several do not.
    #: (untyped, untyped) -> String
    def union_type(type, position)
      nils, others = type.types.partition { |member| member.is_a?(RBS::Types::Bases::Nil) }
      inner = others.map { |member| rbi_type(member, others.one? ? position : position.nest) }
      joined = inner.one? ? inner.first : "T.any(#{inner.join(", ")})"

      nils.empty? ? joined : nilable(joined)
    end

    #: (String) -> String
    def nilable(inner)
      "T.nilable(#{inner})"
    end
  end
end
