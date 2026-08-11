# frozen_string_literal: true

require "test_helper"
require "minitwin"

class ConstructorsTest < ActiveSupport::TestCase
  # === from_json ===

  class FromJsonTwin < Minitwin
    property :id, type: Types::Params::Integer.lax
    property :name
    property :string, type: Types::Params::String.lax
    property :date, type: Types::Params::Date.lax
    property :not_given_date, type: Types::Params::Date.lax
    property :set?, type: Types::Params::Bool.lax
  end

  test "from_json builds from JSON with symbolized keys" do
    json = { id: "12", name: "Alice", string: 1, date: "2025-05-23", set?: true }.to_json
    t = FromJsonTwin.from_json(json)
    assert_equal 12, t.id
    assert_equal "Alice", t.name
    assert_instance_of Date, t.date
    assert_equal "1", t.string
    assert_nil t.not_given_date
    assert_predicate t, :set?
  end

  test "from_json builds nested structures" do
    klass = Class.new(Minitwin) do
      property :profile do
        property :bio
      end
    end

    json = '{"profile":{"bio":"test bio"}}'
    obj = klass.from_json(json)
    assert_equal "test bio", obj.profile.bio
  end

  # === from_params ===

  class FromParamsTwin < Minitwin
    property :x, type: Types::Params::Integer.lax
    property :y
    property :string, type: Types::Params::String.lax
    property :not_given, type: Types::Params::Integer.lax
  end

  test "from_params builds from ActionController::Parameters" do
    params = ActionController::Parameters.new(x: "7", y: "ok", string: 1)
    t = FromParamsTwin.from_params(params)
    assert_equal 7, t.x
    assert_equal "ok", t.y
    assert_equal 0, t.not_given
    assert_equal "1", t.string
  end

  test "from_params builds from plain hash" do
    t = FromParamsTwin.from_params({ x: "9", y: "fine" })
    assert_equal 9, t.x
    assert_equal "fine", t.y
  end

  test "from_params converts via unsafe hash" do
    params = ActionController::Parameters.new(name: "test", value: 42)

    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    obj = klass.from_params(params)
    assert_equal "test", obj.name
    assert_equal 42, obj.value
  end

  # === from_object ===

  class TwinFromObject < Minitwin
    property :sub_property, as: :renamed
    property :another_sub_property, default: "default"
  end

  class NestedTwinFromObject < Minitwin
    property :sub_property, as: :renamed
    property :another_sub_property do
      property :name
      property :age
    end
  end

  class SubTwinFromObject < Minitwin
    property :property, on: :contract
    collection :with_collection, on: :contract do
      property :sub_property, as: :renamed
      property :another_sub_property
    end
  end

  class ActiveModelPerson
    include ActiveModel::Model

    attr_accessor :name, :age, :sub_property, :another_sub_property
  end

  test "from_object instantiates from a plain object and tracks model" do
    model = Data.define(:sub_property, :another_sub_property).new(sub_property: "test", another_sub_property: "another test")
    obj = TwinFromObject.from_object(model)
    assert_equal "test", obj.renamed
    assert_equal "another test", obj.another_sub_property

    model = Data.define(:sub_property).new(sub_property: "test2")
    obj = TwinFromObject.from_object(model)
    assert_equal model, obj.instance_variable_get("@internal_model__model")
    assert_equal "test2", obj.renamed
    assert_equal "default", obj.another_sub_property
  end

  test "from_object instantiates from an activemodel object" do
    model = ActiveModelPerson.new(sub_property: "bob", another_sub_property: "18")
    obj = TwinFromObject.from_object(model)
    assert_equal "bob", obj.renamed
    assert_equal "18", obj.another_sub_property
  end

  test "from_object instantiates from an activemodel object in a block" do
    person = ActiveModelPerson.new(name: "bob", age: "18")
    model = Data.define(:sub_property, :another_sub_property).new(sub_property: "test", another_sub_property: person)
    obj = NestedTwinFromObject.from_object(model)
    assert_equal "test", obj.renamed
    assert_equal "bob", obj.another_sub_property.name
  end

  test "from_objects instantiates from object with collections" do
    collection = Data.define(:sub_property, :another_sub_property)
    contract =
      Data.
        define(:property, :with_collection).
        new(
          property: "test normal",
          with_collection: [
            collection.new(sub_property: "test", another_sub_property: "another test"),
            collection.new(sub_property: "test2", another_sub_property: "test")
          ]
        )
    obj = SubTwinFromObject.from_objects(contract: contract)
    assert_equal "test normal", obj.property
    assert_instance_of Array, obj.with_collection
    assert_equal 2, obj.with_collection.size
    first_collection = obj.with_collection.first
    assert_equal "test", first_collection.renamed
    assert_equal "another test", first_collection.another_sub_property
    second_collection = obj.with_collection.second
    assert_equal "test2", second_collection.renamed
    assert_equal "test", second_collection.another_sub_property
  end

  test "from_object raises on hash input" do
    klass = Class.new(Minitwin) do
      property :name
    end

    error = assert_raises(Minitwin::ParseError) do
      klass.from_object({ name: "test" })
    end
    assert_match(/use.*from_objects/, error.message)
  end

  test "from_object extracts instance variables when object lacks to_h, attributes, or known methods" do
    simple_object = Object.new
    simple_object.instance_variable_set(:@name, "test")
    simple_object.instance_variable_set(:@value, 42)

    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    # Should extract from instance variables as fallback
    obj = klass.from_object(simple_object)
    assert_equal "test", obj.name
    assert_equal 42, obj.value
  end

  test "from_object handles empty instance variables in coercion fallback" do
    simple_object = Object.new

    klass = Class.new(Minitwin) do
      property :name
    end

    # Should not raise when no instance variables exist
    obj = klass.from_object(simple_object)
    assert_nil obj.name
  end

  test "from_object handles method call failures during coercion" do
    # Create an object that responds but raises on call
    bad_object = Object.new
    def bad_object.name
      raise "method failed"
    end

    def bad_object.respond_to?(method, include_private = false) # rubocop: disable Style/OptionalBooleanParameter -- is method overwrite from `Object`
      return true if method == :name

      super
    end

    klass = Class.new(Minitwin) do
      property :name
    end

    # Should handle the error gracefully - won't set the property
    obj = klass.from_object(bad_object)
    assert_instance_of klass, obj
  end

  test "from_object handles enrichment failures gracefully" do
    source = Object.new
    def source.name
      raise "enrichment failed"
    end

    klass = Class.new(Minitwin) do
      property :name
    end

    # Should not propagate the error from source
    obj = klass.from_object(source)
    assert_instance_of klass, obj
  end

  # === attribute_aliases merging (same feature via from_object and from_collection) ===

  class AliasModel
    def initialize(attrs)
      @attrs = attrs
    end

    def attributes
      @attrs
    end

    def attribute_aliases
      { alias_name: :real_name }
    end

    def real_name
      @attrs[:real_name]
    end
  end

  class AliasTwin < Minitwin
    property :alias_name
  end

  test "from_object merges attribute_aliases into attributes" do
    model = AliasModel.new({ real_name: "Value" })
    twin = AliasTwin.from_object(model)
    assert_equal "Value", twin.alias_name
  end

  test "from_collection merges attribute_aliases for array of objects" do
    models = [AliasModel.new({ real_name: "A" }), AliasModel.new({ real_name: "B" })]
    list = AliasTwin.from_collection(models)
    assert_equal %w[A B], list.map(&:alias_name)
    assert(list.all?(AliasTwin))
  end

  test "from_objects merges attribute_aliases via Struct model" do
    model_class = Struct.new(:name, :old_name) do
      def attributes
        { name: name }
      end

      def attribute_aliases
        { new_name: :name }
      end
    end

    model = model_class.new("test", "old")

    klass = Class.new(Minitwin) do
      property :name
      property :new_name
    end

    obj = klass.from_objects(model: model)
    assert_equal "test", obj.name
    assert_equal "test", obj.new_name
  end

  # === has_one enrichment 2x2 matrix (from_object/from_collection x key absent/nil) ===

  class HasOneCategory
    def initialize(value:)
      @value = value
    end

    def attributes
      { value: @value }
    end

    attr_reader :value
  end

  class HasOneProfile
    def initialize(name:)
      @name = name
    end

    def attributes
      { name: @name } # no name-of-association key, like ActiveRecord attributes
    end
  end

  # Simulate an ActiveRecord-like model where `attributes` does not include the
  # association object, but a reader exists for it (has_one). Key ABSENT.
  class UserHasOneAbsent
    def initialize(id: 1, profile: nil)
      @id = id
      @profile = profile
    end

    def attributes
      { id: @id } # NOTE: no :profile key here, like ActiveRecord attributes
    end

    attr_reader :profile
  end

  # Simulate an ActiveRecord-like model where `attributes` includes the
  # association name with a nil value, overshadowing the reader. Key PRESENT-NIL.
  class ContractHasOneNil
    def initialize(id:, managed_service_category: nil)
      @id = id
      @msc = managed_service_category
    end

    # Important: key present with nil, like an attribute overshadowing the reader
    def attributes
      { id: @id, managed_service_category: nil }
    end

    def managed_service_category
      @msc
    end
  end

  class UserWithHasOneTwin < Minitwin
    property :id, type: Types::Params::Integer.lax
    property :profile do
      property :name
    end
  end

  class ManagedServiceTwin < Minitwin
    property :id
    property :managed_service_category do
      property :value, as: :category
    end
  end

  test "from_object populates block property from has_one reader when key absent" do
    user = UserHasOneAbsent.new(id: 7, profile: HasOneProfile.new(name: "Dana"))
    twin = UserWithHasOneTwin.from_object(user)
    assert_equal 7, twin.id
    assert twin.profile, "expected nested twin to be present"
    assert_equal "Dana", twin.profile.name
  end

  test "from_object uses has_one reader when attributes key present but nil" do
    contract = ContractHasOneNil.new(id: 1, managed_service_category: HasOneCategory.new(value: "MSP"))
    obj = ManagedServiceTwin.from_object(contract)
    # Should instantiate nested twin from reader even though attributes had the key with nil
    assert_not obj.managed_service_category.nil?
    assert_equal "MSP", obj.managed_service_category.category
  end

  test "from_collection uses has_one reader when attributes key present but nil" do
    items = [
      ContractHasOneNil.new(id: 1, managed_service_category: HasOneCategory.new(value: "A")),
      ContractHasOneNil.new(id: 2, managed_service_category: HasOneCategory.new(value: "B"))
    ]

    list = ManagedServiceTwin.from_collection(items)
    assert_equal 2, list.size
    assert_equal [1, 2], list.map(&:id)
    assert(list.all? { |e| !e.managed_service_category.nil? })
    assert_equal(%w[A B], list.map { |e| e.managed_service_category.category })
  end

  # === from_collection ===

  class FromCollectionTwin < Minitwin
    property :name
  end

  class AMItem
    include ActiveModel::Model

    attr_accessor :sub_property, :another_sub_property
  end

  class AMContract
    include ActiveModel::Model

    attr_accessor :property, :with_collection
  end

  class SubTwinFromCollection < Minitwin
    property :property
    collection :with_collection do
      property :sub_property, as: :renamed
      property :another_sub_property
    end
  end

  test "from_collection builds from array of hashes" do
    list = FromCollectionTwin.from_collection([{ name: "a" }, { name: "b" }])
    assert_equal %w[a b], list.map(&:name)
    assert(list.all?(FromCollectionTwin))
  end

  test "from_collection returns empty array for empty input" do
    klass = Class.new(Minitwin) do
      property :name
    end

    result = klass.from_collection([])
    assert_equal [], result
  end

  test "from_collection instantiates ActiveModel items inside collections" do
    contract = AMContract.new(
      property: "alpha",
      with_collection: [
        AMItem.new(sub_property: "x", another_sub_property: "y"),
        AMItem.new(sub_property: "u", another_sub_property: "v")
      ]
    )

    list = SubTwinFromCollection.from_collection([contract])
    assert_equal 1, list.size
    twin = list.first
    assert_equal "alpha", twin.property

    # Ensure collection items are instantiated as element twins and aliases work
    assert_equal 2, twin.with_collection.size
    first = twin.with_collection.first
    second = twin.with_collection.last
    assert_kind_of Minitwin, first
    assert_equal "x", first.renamed
    assert_equal "y", first.another_sub_property
    assert_equal "u", second.renamed
    assert_equal "v", second.another_sub_property
  end

  # === from_collection deep nesting (relation proxy + nested-group serialization) ===

  class Subcategory
    include ActiveModel::Model

    attr_accessor :code
  end

  class Category
    include ActiveModel::Model

    attr_accessor :name, :subcategories, :info, :tag

    # Simulate has_one-like overshadowing in attributes by returning nil for :info
    def attributes
      { name: @name, subcategories: @subcategories, info: nil, tag: @tag }
    end
  end

  class CategoryInfo
    include ActiveModel::Model

    attr_accessor :label
  end

  class ManagedService
    include ActiveModel::Model

    attr_accessor :title, :categories
  end

  class ContractDeep
    include ActiveModel::Model

    attr_accessor :id, :managed_service
  end

  # Deeply nested twin with a block property containing a collection, which
  # itself contains a further nested collection.
  class DeepCollectionTwin < Minitwin
    property :id
    property :managed_service do
      property :title
      collection :categories do
        property :name
        # Add a block property inside each category element
        property :info do
          property :label
        end
        # Add a nested group inside the category element; inner leaf is set via
        # element-level setter `tag=` on the twin which writes under `extra`.
        nested :extra do
          property :tag
        end
        collection :subcategories do
          property :code
        end
      end
    end
  end

  # Simulate ActiveRecord's CollectionProxy via a lightweight wrapper that is
  # not an Array but responds to to_a and Enumerable.
  class RelationProxy
    include Enumerable

    def initialize(items)
      @items = Array(items)
    end

    def each(&blk)
      @items.each(&blk)
    end

    def to_a
      @items.dup
    end

    def size
      @items.size
    end
  end

  test "from_collection builds deep nested block + collections" do
    items = [
      ContractDeep.new(
        id: 1,
        managed_service: ManagedService.new(
          title: "MS-A",
          categories: [
            Category.new(
              name: "C1",
              info: CategoryInfo.new(label: "I1"),
              tag: "T1",
              subcategories: [Subcategory.new(code: "s1"), Subcategory.new(code: "s2")]
            ),
            Category.new(name: "C2", info: CategoryInfo.new(label: "I2"), tag: "T2", subcategories: [Subcategory.new(code: "s3")])
          ]
        )
      ),
      ContractDeep.new(
        id: 2,
        managed_service: ManagedService.new(
          title: "MS-B",
          categories: [
            Category.new(name: "C3", info: CategoryInfo.new(label: "I3"), tag: "T3", subcategories: [])
          ]
        )
      )
    ]

    list = DeepCollectionTwin.from_collection(items)
    assert_equal 2, list.size

    first = list.first
    assert_equal 1, first.id
    assert_equal "MS-A", first.managed_service.title
    assert_equal 2, first.managed_service.categories.size
    assert_kind_of Minitwin, first.managed_service.categories.first
    assert_equal "C1", first.managed_service.categories.first.name
    assert_equal %w[s1 s2], first.managed_service.categories.first.subcategories.map(&:code)
    assert_equal(%w[I1 I2], first.managed_service.categories.map { |c| c.info.label })
    # Ensure nested group serializes under container key
    first_hash = first.to_hash
    assert_equal "T1", first_hash[:managed_service][:categories][0][:extra][:tag]
    assert_equal "T2", first_hash[:managed_service][:categories][1][:extra][:tag]

    second = list.last
    assert_equal 2, second.id
    assert_equal "MS-B", second.managed_service.title
    assert_equal ["C3"], second.managed_service.categories.map(&:name)
    assert_equal([[]], second.managed_service.categories.map { |c| c.subcategories.map(&:code) })
    assert_equal(["I3"], second.managed_service.categories.map { |c| c.info.label })
    second_hash = second.to_hash
    assert_equal "T3", second_hash[:managed_service][:categories][0][:extra][:tag]
  end

  test "from_collection builds deep nested with relation proxies" do
    items = [
      ContractDeep.new(
        id: 11,
        managed_service: ManagedService.new(
          title: "MS-R1",
          categories: RelationProxy.new(
            [
              Category.new(
                name: "RC1",
                info: CategoryInfo.new(label: "RI1"),
                tag: "RT1",
                subcategories: RelationProxy.new([Subcategory.new(code: "rs1")])
              )
            ]
          )
        )
      ),
      ContractDeep.new(
        id: 22,
        managed_service: ManagedService.new(
          title: "MS-R2",
          categories: RelationProxy.new(
            [
              Category.new(
                name: "RC2",
                info: CategoryInfo.new(label: "RI2"),
                tag: "RT2",
                subcategories: RelationProxy.new(
                  [
                    Subcategory.new(code: "rs2"), Subcategory.new(code: "rs3")
                  ]
                )
              )
            ]
          )
        )
      )
    ]

    list = DeepCollectionTwin.from_collection(items)
    assert_equal 2, list.size

    first = list.first
    assert_equal 11, first.id
    assert_equal "MS-R1", first.managed_service.title
    assert_equal ["RC1"], first.managed_service.categories.map(&:name)
    assert_equal(["RI1"], first.managed_service.categories.map { |c| c.info.label })
    assert_equal([["rs1"]], first.managed_service.categories.map { |c| c.subcategories.map(&:code) })
    fh = first.to_hash
    assert_equal "RT1", fh[:managed_service][:categories][0][:extra][:tag]

    second = list.last
    assert_equal 22, second.id
    assert_equal "MS-R2", second.managed_service.title
    assert_equal ["RC2"], second.managed_service.categories.map(&:name)
    assert_equal(["RI2"], second.managed_service.categories.map { |c| c.info.label })
    assert_equal([%w[rs2 rs3]], second.managed_service.categories.map { |c| c.subcategories.map(&:code) })
    sh = second.to_hash
    assert_equal "RT2", sh[:managed_service][:categories][0][:extra][:tag]
  end

  # === enrichment edge cases ===

  test "from_objects falls back to writer for collections metadata lookup failure" do
    klass = Class.new(Minitwin) do
      property :items, on: :model
    end

    model = Struct.new(:items).new([1, 2, 3])

    # Should handle when collections metadata can't be retrieved
    obj = klass.from_objects(model: model)
    assert_equal [1, 2, 3], obj.items
  end
end
