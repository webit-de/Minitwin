# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class RbiTest < ActiveSupport::TestCase
  def transpile(rbs)
    Minitwin::Rbi.from_rbs(rbs)
  end

  test "transpiles a module with a simple instance method" do
    rbi = transpile(<<~RBS)
      module Foo
        def bar: () -> String
      end
    RBS

    assert_equal <<~RBI, rbi
      # typed: true

      module Foo
        sig { returns(String) }
        def bar; end
      end
    RBI
  end

  # Extracts the single generated sig line, so type-mapping tests stay readable.
  def sig_for(rbs_return_type)
    rbi = transpile("module Foo\n  def bar: () -> #{rbs_return_type}\nend\n")
    rbi.lines.find { |line| line.include?("sig {") }.strip
  end

  test "maps untyped to T.untyped" do
    assert_equal "sig { returns(T.untyped) }", sig_for("untyped")
  end

  test "maps bool to T::Boolean" do
    assert_equal "sig { returns(T::Boolean) }", sig_for("bool")
  end

  test "maps void return type to .void" do
    assert_equal "sig { void }", sig_for("void")
  end

  test "maps optional types to T.nilable" do
    assert_equal "sig { returns(T.nilable(String)) }", sig_for("String?")
  end

  test "maps unions to T.any" do
    assert_equal "sig { returns(T.any(String, Symbol)) }", sig_for("(String | Symbol)")
  end

  test "maps a union with nil to T.nilable" do
    assert_equal "sig { returns(T.nilable(String)) }", sig_for("(String | nil)")
  end

  test "maps a union of several types with nil to a nilable T.any" do
    assert_equal "sig { returns(T.nilable(T.any(String, Symbol))) }", sig_for("(String | Symbol | nil)")
  end

  test "keeps absolute type names absolute" do
    assert_equal "sig { returns(::Minitwin::Foo) }", sig_for("::Minitwin::Foo")
  end

  test "maps generic stdlib collections to their T:: equivalents" do
    assert_equal "sig { returns(T::Array[Symbol]) }", sig_for("Array[Symbol]")
    assert_equal "sig { returns(T::Hash[Symbol, T.untyped]) }", sig_for("Hash[Symbol, untyped]")
    assert_equal "sig { returns(T::Set[String]) }", sig_for("Set[String]")
    assert_equal "sig { returns(T::Enumerable[Integer]) }", sig_for("Enumerable[Integer]")
    assert_equal "sig { returns(T::Range[Integer]) }", sig_for("Range[Integer]")
  end

  test "fills in untyped arguments for bare stdlib collections" do
    assert_equal "sig { returns(T::Array[T.untyped]) }", sig_for("Array")
    assert_equal "sig { returns(T::Hash[T.untyped, T.untyped]) }", sig_for("Hash")
  end

  test "keeps generic arguments of non-stdlib classes as written" do
    assert_equal "sig { returns(::Minitwin::Box[String]) }", sig_for("::Minitwin::Box[String]")
  end

  test "maps self to T.self_type" do
    assert_equal "sig { returns(T.self_type) }", sig_for("self")
  end

  # Sorbet restricts T.self_type and T.attached_class by position, so `instance`
  # and `self` have to be mapped depending on where they appear.
  test "maps instance in a singleton method of a class to T.attached_class" do
    assert_includes(
      transpile("class Foo\n  def self.bar: () -> instance\nend\n"),
      "sig { returns(T.attached_class) }\n  def self.bar; end\n"
    )
  end

  test "maps instance in a singleton method of a module to T.untyped" do
    assert_includes(
      transpile("module Foo\n  def self.bar: () -> instance\nend\n"),
      "sig { returns(T.untyped) }\n  def self.bar; end\n"
    )
  end

  test "maps instance in an instance method to T.self_type" do
    assert_equal "sig { returns(T.self_type) }", sig_for("instance")
  end

  test "maps instance per receiver for module_function style definitions" do
    rbi = transpile("class Foo\n  def self?.bar: () -> instance\nend\n")

    assert_includes rbi, "sig { returns(T.self_type) }\n  def bar; end\n"
    assert_includes rbi, "sig { returns(T.attached_class) }\n  def self.bar; end\n"
  end

  test "keeps T.attached_class inside containers" do
    assert_includes(
      transpile("class Foo\n  def self.bar: () -> Array[instance]\nend\n"),
      "sig { returns(T::Array[T.attached_class]) }\n"
    )
  end

  test "falls back to T.untyped for self and instance inside containers" do
    assert_equal "sig { returns(T::Array[T.untyped]) }", sig_for("Array[instance]")
    assert_equal "sig { returns(T::Array[T.untyped]) }", sig_for("Array[self]")
    assert_equal "sig { returns(T.any(T.untyped, Integer)) }", sig_for("(self | Integer)")
  end

  test "keeps a nilable self type, which Sorbet still counts as top level" do
    assert_equal "sig { returns(T.nilable(T.self_type)) }", sig_for("self?")
  end

  test "falls back to T.untyped for self and instance in parameter position" do
    assert_equal(
      ["sig { params(other: T.untyped).void }", "def bar(other); end"],
      method_for("(self other) -> void")
    )
  end

  test "forces a void return type for initialize" do
    assert_includes(
      transpile("class Foo\n  def initialize: (String name) -> instance\nend\n"),
      "sig { params(name: String).void }\n  def initialize(name); end\n"
    )
  end

  class Root
    module Extended; end
    module Included; end
    module Unused; end

    extend Extended
    include Included
  end

  test "lists the modules a class is extended with" do
    assert_equal ["#{Root}::Extended"], Minitwin::Rbi.extended_modules(Root)
  end

  test "lists no modules for a class without an extend" do
    assert_empty Minitwin::Rbi.extended_modules(Root::Unused)
  end

  test "lists the modules minitwin itself is extended with" do
    extended = Minitwin::Rbi.extended_modules(Minitwin)

    assert_includes extended, "Minitwin::ClassMethods"
    assert_includes extended, "Minitwin::ClassMethods::Constructors"
    refute_includes extended, "Minitwin::Assignment"
  end

  # A module whose methods return `instance` means "an instance of the class I am
  # mixed into". With include that is the receiver, with extend it is the
  # attached class, and RBS spells both the same way.
  test "declares has_attached_class! for modules that are mixed in with extend" do
    rbi = Minitwin::Rbi.from_rbs(<<~RBS, extended_modules: ["Foo::Bar"])
      module Foo
        module Bar
          def build: () -> instance
          def build_many: () -> Array[instance]
          def take: (instance other) -> void
        end
      end
    RBS

    assert_equal <<~RBI, rbi
      # typed: true

      module Foo
        module Bar
          extend T::Generic
          has_attached_class!(:out)

          sig { returns(T.attached_class) }
          def build; end

          sig { returns(T::Array[T.attached_class]) }
          def build_many; end

          sig { params(other: T.untyped).void }
          def take(other); end
        end
      end
    RBI
  end

  test "keeps a self type for modules that are mixed in with include" do
    rbi = Minitwin::Rbi.from_rbs("module Foo\n  def copy: () -> instance\nend\n", extended_modules: ["Bar"])

    assert_includes rbi, "sig { returns(T.self_type) }"
    refute_includes rbi, "has_attached_class!"
  end

  test "matches extended modules regardless of a leading namespace separator" do
    rbi = Minitwin::Rbi.from_rbs("module Foo\n  def build: () -> instance\nend\n", extended_modules: ["::Foo"])

    assert_includes rbi, "has_attached_class!(:out)"
  end

  test "combines has_attached_class! with type parameters in one T::Generic block" do
    rbi = Minitwin::Rbi.from_rbs("module Foo[Elem]\nend\n", extended_modules: ["Foo"])

    assert_equal <<~RBI, rbi
      # typed: true

      module Foo
        extend T::Generic
        has_attached_class!(:out)

        Elem = type_member
      end
    RBI
  end

  test "passes extended modules through when combining files" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "a.rbs"), "module Foo\n  def build: () -> instance\nend\n")
      paths = [File.join(dir, "a.rbs")]

      rbi = Minitwin::Rbi.from_rbs_files(paths, relative_to: dir, extended_modules: ["Foo"])

      assert_includes rbi, "has_attached_class!(:out)"
      assert_includes rbi, "sig { returns(T.attached_class) }"
    end
  end

  test "does not declare has_attached_class! for classes" do
    rbi = Minitwin::Rbi.from_rbs("class Foo\n  def self.build: () -> instance\nend\n", extended_modules: ["Foo"])

    refute_includes rbi, "has_attached_class!"
    assert_includes rbi, "sig { returns(T.attached_class) }"
  end

  test "maps top and bot" do
    assert_equal "sig { returns(T.anything) }", sig_for("top")
    assert_equal "sig { returns(T.noreturn) }", sig_for("bot")
  end

  test "maps a nil return type to NilClass" do
    assert_equal "sig { returns(NilClass) }", sig_for("nil")
  end

  test "maps singleton types to T.class_of" do
    assert_equal "sig { returns(T.class_of(::Minitwin)) }", sig_for("singleton(::Minitwin)")
  end

  test "widens literal types to their class" do
    assert_equal "sig { returns(Symbol) }", sig_for(":sym")
    assert_equal "sig { returns(String) }", sig_for('"str"')
    assert_equal "sig { returns(Integer) }", sig_for("1")
    assert_equal "sig { returns(T::Boolean) }", sig_for("true")
  end

  test "maps intersections to T.all" do
    assert_equal "sig { returns(T.all(String, Comparable)) }", sig_for("(String & Comparable)")
  end

  test "maps tuples and records to their Sorbet equivalents" do
    assert_equal "sig { returns([Integer, String]) }", sig_for("[Integer, String]")
    assert_equal "sig { returns({a: Integer, b: String}) }", sig_for("{ a: Integer, b: String }")
  end

  test "maps proc types to T.proc" do
    assert_equal "sig { returns(T.proc.params(arg0: Integer).returns(String)) }", sig_for("^(Integer) -> String")
    assert_equal "sig { returns(T.proc.void) }", sig_for("^() -> void")
  end

  test "falls back to T.untyped for interfaces and type aliases" do
    rbi = transpile(<<~RBS)
      type name_like = String | Symbol

      interface _Stringish
        def to_s: () -> String
      end

      module Foo
        def bar: () -> name_like
        def duck: () -> _Stringish
      end
    RBS

    assert_equal(2, rbi.lines.count { |line| line.strip == "sig { returns(T.untyped) }" })
  end

  # Returns the [sig, def] pair generated for a single method type.
  def method_for(rbs_method_type)
    rbi = transpile("module Foo\n  def bar: #{rbs_method_type}\nend\n")
    rbi.lines.map(&:strip).select { |line| line.start_with?("sig ", "def ") }
  end

  test "names and types required positional parameters" do
    assert_equal(
      ["sig { params(name: Symbol, size: Integer).void }", "def bar(name, size); end"],
      method_for("(Symbol name, Integer size) -> void")
    )
  end

  test "synthesizes names for anonymous positional parameters" do
    assert_equal(
      ["sig { params(arg0: Symbol, arg1: Integer).void }", "def bar(arg0, arg1); end"],
      method_for("(Symbol, Integer) -> void")
    )
  end

  test "gives optional positional parameters an unsafe default" do
    assert_equal(
      ["sig { params(name: Symbol).void }", "def bar(name = T.unsafe(nil)); end"],
      method_for("(?Symbol name) -> void")
    )
  end

  test "translates rest positional parameters" do
    assert_equal(
      ["sig { params(rest: Integer).void }", "def bar(*rest); end"],
      method_for("(*Integer rest) -> void")
    )
  end

  test "names anonymous rest parameters args and kwargs" do
    assert_equal(
      ["sig { params(args: T.untyped, kwargs: T.untyped).void }", "def bar(*args, **kwargs); end"],
      method_for("(*untyped, **untyped) -> void")
    )
  end

  test "translates required and optional keyword parameters" do
    assert_equal(
      ["sig { params(key: Symbol, opt: T::Boolean).void }",
       "def bar(key:, opt: T.unsafe(nil)); end"],
      method_for("(key: Symbol, ?opt: bool) -> void")
    )
  end

  test "translates rest keyword parameters" do
    assert_equal(
      ["sig { params(opts: T.untyped).void }", "def bar(**opts); end"],
      method_for("(**untyped opts) -> void")
    )
  end

  test "translates a required block to a T.proc parameter" do
    assert_equal(
      ["sig { params(blk: T.proc.params(arg0: Integer).void).void }", "def bar(&blk); end"],
      method_for("() { (Integer) -> void } -> void")
    )
  end

  test "makes an optional block nilable" do
    assert_equal(
      ["sig { params(blk: T.nilable(T.proc.void)).void }", "def bar(&blk); end"],
      method_for("() ?{ () -> void } -> void")
    )
  end

  test "falls back to T.untyped for blocks with untyped parameters" do
    assert_equal(
      ["sig { params(blk: T.untyped).void }", "def bar(&blk); end"],
      method_for("() ?{ (?) -> untyped } -> void")
    )
  end

  test "orders parameters as Ruby requires" do
    assert_equal(
      ["sig { params(name: Symbol, on: Symbol, opts: T.untyped, blk: T.untyped).void }",
       "def bar(name, on: T.unsafe(nil), **opts, &blk); end"],
      method_for("(Symbol name, ?on: Symbol, **untyped opts) ?{ (?) -> untyped } -> void")
    )
  end

  test "emits singleton methods on self" do
    assert_equal(
      ["sig { params(name: String).void }", "def self.bar(name); end"],
      transpile("module Foo\n  def self.bar: (String name) -> void\nend\n").
        lines.map(&:strip).select { |line| line.start_with?("sig ", "def ") }
    )
  end

  test "expands module_function style definitions into both receivers" do
    rbi = transpile("module Foo\n  def self?.bar: () -> void\nend\n")

    assert_includes rbi, "def bar; end"
    assert_includes rbi, "def self.bar; end"
  end

  test "separates the two definitions of a module_function style method" do
    assert_equal <<~RBI, transpile("module Foo\n  def self?.bar: () -> void\nend\n")
      # typed: true

      module Foo
        sig { void }
        def bar; end

        sig { void }
        def self.bar; end
      end
    RBI
  end

  test "records dropped overloads once per method" do
    rbi = transpile("module Foo\n  def self?.bar: (String) -> void\n           | (Integer) -> void\nend\n")

    assert_equal(1, rbi.lines.count { |line| line.include?("further RBS overload") })
  end

  test "keeps method visibility" do
    rbi = transpile(<<~RBS)
      module Foo
        def pub: () -> void

        private

        def secret: () -> void
      end
    RBS

    assert_equal(
      ["module Foo", "sig { void }", "def pub; end", "private", "sig { void }", "def secret; end", "end"],
      rbi.lines.map(&:strip).reject(&:empty?).drop(1)
    )
  end

  test "keeps inline visibility annotations" do
    rbi = transpile("module Foo\n  private def secret: () -> void\nend\n")

    assert_includes rbi, "  sig { void }\n  private def secret; end\n"
  end

  test "uses the first overload and records the dropped ones" do
    rbi = transpile("module Foo\n  def bar: (String) -> void\n         | (Integer) -> void\nend\n")

    assert_includes rbi, "# NOTE: 1 further RBS overload of `bar` dropped; Sorbet RBI has no overloads."
    assert_includes rbi, "sig { params(arg0: String).void }"
  end

  test "transpiles classes with a superclass" do
    assert_equal <<~RBI, transpile("class Foo < Bar\nend\n")
      # typed: true

      class Foo < Bar
      end
    RBI
  end

  test "nests namespaces and indents members" do
    rbi = transpile(<<~RBS)
      class Outer
        module Inner
          def deep: () -> void
        end
      end
    RBS

    assert_equal <<~RBI, rbi
      # typed: true

      class Outer
        module Inner
          sig { void }
          def deep; end
        end
      end
    RBI
  end

  test "translates type parameters into type members" do
    rbi = transpile(<<~RBS)
      class Box[Elem]
        def get: () -> Elem
      end
    RBS

    assert_equal <<~RBI, rbi
      # typed: true

      class Box
        extend T::Generic

        Elem = type_member

        sig { returns(Elem) }
        def get; end
      end
    RBI
  end

  test "translates type parameter variance and bounds" do
    rbi = transpile("class Box[out A, in B, C < String]\nend\n")

    assert_includes rbi, "  A = type_member(:out)\n"
    assert_includes rbi, "  B = type_member(:in)\n"
    assert_includes rbi, "  C = type_member { { upper: String } }\n"
  end

  test "translates mixins" do
    rbi = transpile(<<~RBS)
      class Foo
        include Bar
        extend Baz
        prepend Qux
      end
    RBS

    assert_equal(
      ["class Foo", "include Bar", "extend Baz", "prepend Qux", "end"],
      rbi.lines.map(&:strip).reject(&:empty?).drop(1)
    )
  end

  test "translates attributes into sigged attr declarations" do
    rbi = transpile(<<~RBS)
      class Foo
        attr_reader name: String
        attr_writer raw: untyped
        attr_accessor items: Array[Symbol]
      end
    RBS

    assert_includes rbi, "  sig { returns(String) }\n  attr_reader :name\n"
    assert_includes rbi, "  sig { params(raw: T.untyped).returns(T.untyped) }\n  attr_writer :raw\n"
    assert_includes rbi, "  sig { returns(T::Array[Symbol]) }\n  attr_accessor :items\n"
  end

  test "translates singleton attributes into singleton methods" do
    rbi = transpile("class Foo\n  attr_reader self.count: Integer\nend\n")

    assert_includes rbi, "  sig { returns(Integer) }\n  def self.count; end\n"
  end

  test "translates constants into T.let declarations" do
    rbi = transpile("class Foo\n  VERSION: String\nend\n")

    assert_includes rbi, "  VERSION = T.let(T.unsafe(nil), String)\n"
  end

  test "translates aliases" do
    rbi = transpile("class Foo\n  def length: () -> Integer\n  alias size length\nend\n")

    assert_includes rbi, "  alias size length\n"
  end

  test "keeps the public visibility marker" do
    rbi = transpile("class Foo\n  private\n  def a: () -> void\n  public\n  def b: () -> void\nend\n")

    assert_equal(
      ["class Foo", "private", "sig { void }", "def a; end", "public", "sig { void }", "def b; end", "end"],
      rbi.lines.map(&:strip).reject(&:empty?).drop(1)
    )
  end

  test "keeps attribute visibility" do
    rbi = transpile("class Foo\n  private attr_reader name: String\nend\n")

    assert_includes rbi, "  sig { returns(String) }\n  private attr_reader :name\n"
  end

  test "combines several RBS files into one RBI, in the given order" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "b.rbs"), "class Foo\n  def b: () -> void\nend\n")
      File.write(File.join(dir, "a.rbs"), "class Foo\n  def a: () -> void\nend\n")
      paths = [File.join(dir, "a.rbs"), File.join(dir, "b.rbs")]

      rbi = Minitwin::Rbi.from_rbs_files(paths, relative_to: dir)

      assert_equal <<~RBI, rbi
        # typed: true

        # DO NOT EDIT MANUALLY.
        # Generated from the RBS signatures in sig/ by `rake minitwin:generate_rbi`.

        # from a.rbs
        class Foo
          sig { void }
          def a; end
        end

        # from b.rbs
        class Foo
          sig { void }
          def b; end
        end
      RBI
    end
  end

  test "handles relative input paths" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "sig"))
      File.write(File.join(dir, "sig", "a.rbs"), "class Foo\n  def a: () -> void\nend\n")

      rbi = Dir.chdir(dir) { Minitwin::Rbi.from_rbs_files(["sig/a.rbs"]) }

      assert_includes rbi, "# from sig/a.rbs\n"
    end
  end

  test "skips RBS files that declare nothing translatable" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "aliases.rbs"), "type thing = String\n")

      rbi = Minitwin::Rbi.from_rbs_files([File.join(dir, "aliases.rbs")], relative_to: dir)

      refute_includes rbi, "aliases.rbs"
    end
  end

  test "ignores instance variable declarations" do
    rbi = transpile("class Foo\n  @name: String\n  self.@count: Integer\nend\n")

    assert_equal "# typed: true\n\nclass Foo\nend\n", rbi
  end
end
