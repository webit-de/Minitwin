# frozen_string_literal: true

require "test_helper"
require "minitwin"

class SyncTest < ActiveSupport::TestCase

  # --- Basic write-back ----------------------------------------------------

  test "sync writes twin values back to its target model" do
    model = Struct.new(:name, :value).new("from_model", 42)

    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    assert_equal "from_model", model.name
    assert_equal 42, model.value

    twin = klass.new(name: "original", value: 10)
    twin.sync(model)

    assert_equal "original", model.name
    assert_equal 10, model.value
  end

  class PersonContractTwin < Minitwin
    property :name, validates: { presence: true }
    property :age, validates: { presence: true, numericality: { greater_than: 17 } }
  end

  test "sync completes the present/submit/write-back form lifecycle" do
    model = Struct.new(:name, :age).new("Max", 18)

    # presenting form
    contract = PersonContractTwin.from_object(model)
    assert_predicate contract, :valid?
    assert_equal "Max", contract.name
    assert_equal 18, contract.age

    # submitting form
    contract = PersonContractTwin.from_params({ name: "Moritz", age: 15 })
    refute_predicate contract, :valid?
    assert_equal ["must be greater than 17"], contract.errors[:age]

    contract = PersonContractTwin.from_params({ name: "Moritz", age: 19 })
    assert_predicate contract, :valid?
    assert contract.sync(model)

    assert_equal "Moritz", model.name
    assert_equal 19, model.age
  end

  test "sync skips invalid twins unless validate is false" do
    model = Struct.new(:name, :age).new("Max", 18)

    # presenting form
    contract = PersonContractTwin.from_object(model)
    assert_predicate contract, :valid?
    assert_equal "Max", contract.name
    assert_equal 18, contract.age

    # submitting form
    contract = PersonContractTwin.from_params({ name: "Moritz", age: 15 })
    refute_predicate contract, :valid?
    assert_equal ["must be greater than 17"], contract.errors[:age]
    assert_not contract.sync(model)

    assert_equal "Max", model.name
    assert_equal 18, model.age

    assert contract.sync(model, validate: false)
    assert_equal "Moritz", model.name
    assert_equal 15, model.age
  end

  # --- Stored-model defaulting (sync without / with nil argument) -----------

  Person = Struct.new(:name, :age)

  class PersonTwin < Minitwin
    property :name
    property :age
  end

  test "sync uses the stored model when no argument is given" do
    model = Person.new("Eve", 30)
    twin = PersonTwin.from_object(model)
    twin.assign_params(name: "Eva", age: 31)

    assert twin.sync
    assert_equal "Eva", model.name
    assert_equal 31, model.age
  end

  test "sync picks first stored model when the default :model slot is empty" do
    model = Struct.new(:name).new("X")
    klass = Class.new(Minitwin) do
      property :name
    end
    twin = klass.from_objects(other: model)
    twin.assign_hash(name: "Y")
    assert twin.sync
    assert_equal "Y", model.name
  end

  test "sync returns false when there is no model to write to" do
    klass = Class.new(Minitwin) do
      property :value
    end

    twin = klass.new(value: "A1")
    assert_not twin.sync
  end

  # --- Collections: id match else index fallback ---------------------------

  ItemModel = Struct.new(:id, :value)
  OrderModel = Struct.new(:items)

  class OrderTwin < Minitwin
    collection :items do
      property :id
      property :value
    end
  end

  test "sync matches collection items by id rather than position" do
    order = OrderModel.new(
      [
        ItemModel.new(1, "a"),
        ItemModel.new(2, "b")
      ]
    )

    twin = OrderTwin.from_object(order)
    # reorder and change values
    twin.items = [
      { id: 2, value: "B2" },
      { id: 1, value: "A1" }
    ]

    assert twin.sync(nil) # use stored model

    # Expect in-place updates matched by id, not index
    assert_equal 1, order.items[0].id
    assert_equal "A1", order.items[0].value
    assert_equal 2, order.items[1].id
    assert_equal "B2", order.items[1].value
  end

  test "sync falls back to index when collection items have nil ids" do
    item = Struct.new(:id, :value)
    model = Struct.new(:items).new([item.new(nil, "a"), item.new(nil, "b")])

    klass = Class.new(Minitwin) do
      collection :items do
        property :id
        property :value
      end
    end

    twin = klass.new(items: [{ id: 1, value: "A1" }, { id: 2, value: "B2" }])
    assert twin.sync(model)
    assert_equal "A1", model.items[0].value
    assert_equal "B2", model.items[1].value
  end

  test "sync falls back to index when collection has no id property and supports only each and []" do
    collection_class = Class.new do
      def initialize(arr)
        @arr = arr
      end

      def each(&blk)
        @arr.each(&blk)
      end

      def [](idx)
        @arr[idx]
      end
    end

    item = Struct.new(:value)
    model = Struct.new(:items).new(collection_class.new([item.new("a"), item.new("b")]))

    klass = Class.new(Minitwin) do
      collection :items do
        property :value
      end
    end

    twin = klass.new(items: [{ value: "A1" }, { value: "B2" }])
    assert twin.sync(model)
    assert_equal "A1", model.items[0].value
    assert_equal "B2", model.items[1].value
  end

  test "sync assigns an array of hashes via the writer when the target has no collection" do
    order = OrderModel.new(nil)
    twin = OrderTwin.from_params(items: [{ id: 1, value: "x" }])

    assert twin.sync(order, validate: false)
    assert_kind_of Array, order.items
    assert_equal [{ id: 1, value: "x" }.with_indifferent_access], order.items
  end

  # --- Nested twins: deep-sync in place / writer fallback ------------------

  ContactModel = Struct.new(:email)
  ProfileModel = Struct.new(:bio, :contact)
  UserModel = Struct.new(:name, :profile)

  class UserTwin < Minitwin
    property :name
    property :profile do
      property :bio
      property :contact do
        property :email
      end
    end
  end

  test "sync deep-syncs nested twins into the stored model in place" do
    contact = ContactModel.new("old@example.com")
    profile = ProfileModel.new("Old bio", contact)
    user = UserModel.new("Alice", profile)

    # Presenting form
    presented = UserTwin.from_object(user)
    assert_equal "Alice", presented.name
    assert_equal "Old bio", presented.profile.bio
    assert_equal "old@example.com", presented.profile.contact.email

    # Submitting form with nested changes on the same presented instance
    presented.assign_params(
      {
        name: "Bob",
        profile: {
          bio: "New bio",
          contact: { email: "new@example.com" }
        }
      }
    )

    assert presented.sync(nil) # defaults to stored model when available

    # Deep sync updates nested objects in place
    assert_equal "Bob", user.name
    assert_same profile, user.profile
    assert_equal "New bio", user.profile.bio
    assert_same contact, user.profile.contact
    assert_equal "new@example.com", user.profile.contact.email
  end

  test "sync assigns a hash via the writer when there is no nested target object" do
    # Model without nested object instance yet
    user = UserModel.new("Carol", nil)

    twin = UserTwin.from_params(
      {
        name: "Dave",
        profile: { bio: "Bio", contact: { email: "contact@example.com" } }
      }
    )

    # The writer should receive a hash for profile
    assert twin.sync(user, validate: false)
    assert_equal "Dave", user.name
    assert_kind_of Hash, user.profile, "expected profile to be assigned as a Hash when no nested target exists"
    assert_equal({ bio: "Bio", contact: { email: "contact@example.com" } }.with_indifferent_access, user.profile)
  end

  # --- Aliased nested properties flattening onto plain models --------------

  # Flat model (like ActiveRecord) — no nested structure, just attributes
  OrderRecord = Struct.new(:customer_from, :extcusref, :draft_reference, :orderdate, :orderno)

  class NestedAliasedTwin < Minitwin
    nested :order do
      property :customer_from
      property :extcusref
      property :orderno, as: :draft_reference
    end

    nested :config do
      property :order_date, as: :orderdate
    end
  end

  test "sync writes aliased nested properties onto a flat model using the as: name" do
    model = OrderRecord.new
    twin = NestedAliasedTwin.from_params(
      order: { customer_from: "ENVT", extcusref: "REF_1", orderno: "ORD_123" },
      config: { order_date: "2017-01-01" }
    )

    assert twin.sync(model, validate: false)

    assert_equal "ENVT", model.customer_from
    assert_equal "REF_1", model.extcusref
    assert_equal "ORD_123", model.draft_reference, "expected orderno to be synced via as: :draft_reference"
    assert_equal "2017-01-01", model.orderdate, "expected order_date to be synced via as: :orderdate"
  end

  test "sync writes only the aliased column and leaves the original name untouched" do
    model = OrderRecord.new
    twin = NestedAliasedTwin.from_params(
      order: { orderno: "ORD_456" },
      config: {}
    )

    twin.sync(model, validate: false)

    assert_equal "ORD_456", model.draft_reference
    assert_nil model.orderno, "expected orderno column to remain nil when as: maps to draft_reference"
  end

  # Regression: nested property with as: + type coercion
  ActivationRecord = Struct.new(:activation_date)

  class TypedNestedTwin < Minitwin
    nested :settings do
      property :start_date, as: :activation_date, type: Types::Params::Date.lax
    end
  end

  test "sync writes a typed aliased nested property with its coerced value" do
    model = ActivationRecord.new
    twin = TypedNestedTwin.from_params(settings: { start_date: "2025-06-15" })

    assert twin.sync(model, validate: false)
    assert_equal Date.new(2025, 6, 15), model.activation_date
  end

  # Multiple nested blocks syncing to same flat model
  ProjectRecord = Struct.new(:name, :mapped_code, :target_date)

  class MultiNestedTwin < Minitwin
    nested :identity do
      property :name
      property :code, as: :mapped_code
    end

    nested :scheduling do
      property :date, as: :target_date
    end
  end

  test "sync flattens multiple aliased nested blocks onto one flat model" do
    model = ProjectRecord.new
    twin = MultiNestedTwin.from_params(
      identity: { name: "Alice", code: "X99" },
      scheduling: { date: "tomorrow" }
    )

    assert twin.sync(model, validate: false)
    assert_equal "Alice", model.name
    assert_equal "X99", model.mapped_code
    assert_equal "tomorrow", model.target_date
  end

  # Verify to_hash still nests correctly (no regression)
  test "to_hash preserves nested structure with aliases" do
    twin = NestedAliasedTwin.from_params(
      order: { customer_from: "ENVT", extcusref: "REF_1", orderno: "ORD_123" },
      config: { order_date: "2017-01-01" }
    )

    hash = twin.to_hash
    assert_equal "ENVT", hash[:order][:customer_from]
    assert_equal "REF_1", hash[:order][:extcusref]
    assert_equal "ORD_123", hash[:order][:draft_reference]
    assert_equal "2017-01-01", hash[:config][:orderdate]
    refute hash.key?(:customer_from), "proxy should not appear at top level"
    refute hash.key?(:orderno), "original name should not appear at top level"
  end

  # --- Full as: alias matrix ----------------------------------------------

  test "sync writes to an aliased attribute on the target model" do
    model = Struct.new(:draft_reference).new(nil)

    klass = Class.new(Minitwin) do
      property :orderno, as: :draft_reference
    end

    twin = klass.from_params(orderno: "ABC123")
    assert twin.sync(model, validate: false)
    assert_equal "ABC123", model.draft_reference
  end

  test "sync uses the alias for the respond_to check on the target model" do
    model = Struct.new(:mapped_name).new("old")

    klass = Class.new(Minitwin) do
      property :name, as: :mapped_name
    end

    twin = klass.new(name: "new_value")
    assert twin.sync(model, validate: false)
    assert_equal "new_value", model.mapped_name
  end

  test "sync skips a property when its aliased writer is missing on the target" do
    model = Struct.new(:unrelated).new("original")

    klass = Class.new(Minitwin) do
      property :foo, as: :nonexistent_attr
    end

    twin = klass.new(foo: "bar")
    assert twin.sync(model, validate: false)
    assert_equal "original", model.unrelated
  end

  test "sync deep-syncs a nested twin through its alias" do
    child_model = Struct.new(:bio).new("old bio")
    parent_model = Struct.new(:detail).new(child_model)

    klass = Class.new(Minitwin) do
      property :profile, as: :detail do
        property :bio
      end
    end

    twin = klass.new(profile: { bio: "new bio" })
    assert twin.sync(parent_model, validate: false)
    assert_same child_model, parent_model.detail
    assert_equal "new bio", parent_model.detail.bio
  end

  test "sync deep-syncs a collection through its alias" do
    item_model = Struct.new(:value)
    parent_model = Struct.new(:renamed_items).new([item_model.new("a"), item_model.new("b")])

    klass = Class.new(Minitwin) do
      collection :items, as: :renamed_items do
        property :value
      end
    end

    twin = klass.new(items: [{ value: "A1" }, { value: "B2" }])
    assert twin.sync(parent_model, validate: false)
    assert_equal "A1", parent_model.renamed_items[0].value
    assert_equal "B2", parent_model.renamed_items[1].value
  end

  test "sync ignores a Proc as: and falls back to the original method name" do
    model = Struct.new(:code).new("old")

    klass = Class.new(Minitwin) do
      property :code, as: -> { "dynamic" }
    end

    twin = klass.new(code: "new_value")
    assert twin.sync(model, validate: false)
    assert_equal "new_value", model.code
  end

  test "sync accepts a String as: value" do
    model = Struct.new(:target_field).new(nil)

    klass = Class.new(Minitwin) do
      property :source, as: "target_field"
    end

    twin = klass.new(source: "hello")
    assert twin.sync(model, validate: false)
    assert_equal "hello", model.target_field
  end

  test "sync uses the original property name when no as: is given" do
    model = Struct.new(:name).new("old")

    klass = Class.new(Minitwin) do
      property :name
    end

    twin = klass.new(name: "new")
    assert twin.sync(model, validate: false)
    assert_equal "new", model.name
  end

  # --- White-box branch coverage (do not drop) -----------------------------

  test "sync writes via setter even when the twin attribute has no getter" do
    model = Class.new do
      attr_reader :written

      def missing_getter=(_)
        @written = true
      end
    end.new
    twin = Class.new(Minitwin) do
      def self.allowed_attribute_keys
        Set[:missing_getter]
      end

      def missing_getter=(value)
        @missing = value
      end
    end.new
    assert twin.sync(model)
    assert model.written
  end

  test "sync falls back to the writer when the collection's [] access raises" do
    collection_class = Class.new do
      def initialize(arr)
        @arr = arr
      end

      def each(&blk)
        @arr.each(&blk)
      end

      def [](_)
        raise "boom"
      end
    end
    item = Struct.new(:val)
    model = Class.new do
      attr_reader :items
      attr_reader :assigned

      def initialize(items)
        @items = items
      end

      def items=(value)
        @assigned = value
      end
    end.new(collection_class.new([item.new("a"), item.new("b")]))

    twin = Class.new(Minitwin) do
      collection :items do
        property :val
      end
    end.new(items: [{ val: "A" }, { val: "B" }])

    assert twin.sync(model)
    # Writer fallback performed due to [] rescue
    assert_equal([{ val: "A" }.with_indifferent_access, { val: "B" }.with_indifferent_access], model.assigned)
  end

  test "build_target_id_lookup skips to_a when respond_to? hides it on an Array subclass" do
    item = Struct.new(:id, :value)
    weird = Class.new(Array) do
      def respond_to?(method_name, inc = false) # rubocop: disable Style/OptionalBooleanParameter -- is method overwrite from `Object`
        return false if method_name == :to_a

        super
      end
    end
    array = weird.new([item.new(1, "a"), item.new(2, "b")])

    model = Struct.new(:items).new(array)

    twin = Class.new(Minitwin) do
      collection :items do
        property :id
        property :value
      end
    end.from_object(model)

    twin.items = [{ id: 1, value: "A1" }, { id: 2, value: "B2" }]
    assert twin.sync(model)
    assert_equal "A1", model.items[0].value
    assert_equal "B2", model.items[1].value
  end

  test "build_target_id_lookup converts a non-array collection via to_a and matches by id" do
    collection_class = Class.new do
      def initialize(arr)
        @arr = arr
      end

      def each(&blk)
        @arr.each(&blk)
      end

      def [](idx)
        @arr[idx]
      end

      def to_a
        @arr.to_a
      end
    end

    item = Struct.new(:id, :value)
    model = Struct.new(:items).new(collection_class.new([item.new(1, "a"), item.new(2, "b")]))

    klass = Class.new(Minitwin) do
      collection :items do
        property :id
        property :value
      end
    end

    twin = klass.new(items: [{ id: 2, value: "B1" }, { id: 1, value: "A2" }])
    assert twin.sync(model)
    assert_equal "A2", model.items[0].value
    assert_equal "B1", model.items[1].value
  end

end
