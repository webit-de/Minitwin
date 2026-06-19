# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class AssignmentTest < ActiveSupport::TestCase
  class BasicPropertyTwin < Minitwin
    property :sub_property
    property :another_sub_property, default: "default"
    property :bool?, type: Types::Params::Bool.lax
  end

  class CollectionItemsTwin < Minitwin
    collection :items
  end

  class DynamicAliasTwin < Minitwin
    property :name, as: -> { "n_#{name}" }
    property :age
    property :email
  end

  class NestedCollectionTwin < Minitwin
    collection :items do
      property :value
      property :nested do
        property :nval
      end
    end
  end

  class AliasedPropertyTwin < Minitwin
    property :sub_property, as: :renamed
    property :another_sub_property, default: "default"
  end

  class AliasedCollectionTwin < Minitwin
    collection :items do
      property :sub_property, as: :renamed
      property :another_sub_property
    end
  end

  class NestedAliasTwin < Minitwin
    nested :nested do
      property :rename_me, as: :nested_renamed
      property :plain
    end
  end

  PersonModel = Struct.new(:name, :age)

  class PersonTwin < Minitwin
    property :name
    property :age
  end

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

  # --- to_object -------------------------------------------------------------

  test "to_object mirrors values from model to twin setters" do
    model = PersonModel.new("Alice", 30)
    twin = PersonTwin.new(name: "Bob", age: 20)

    twin.to_object(model)

    assert_equal "Alice", twin.name
    assert_equal 30, twin.age
  end

  test "to_object mirrors nested models into nested twins" do
    contact = ContactModel.new("nested@example.com")
    profile = ProfileModel.new("About me", contact)
    user = UserModel.new("Alice", profile)

    twin = UserTwin.new
    twin.to_object(user)

    assert_equal "Alice", twin.name
    assert_instance_of UserTwin::Profile, twin.profile
    assert_equal "About me", twin.profile.bio
    assert_instance_of UserTwin::Profile::Contact, twin.profile.contact
    assert_equal "nested@example.com", twin.profile.contact.email
  end

  # --- assign_object ---------------------------------------------------------

  test "assign_object copies attributes for aliased property" do
    model = Data.define(:sub_property, :another_sub_property).new(sub_property: "x", another_sub_property: "y")
    twin = AliasedPropertyTwin.new
    twin.assign_object(model)

    assert_equal "x", twin.renamed
    assert_equal "y", twin.another_sub_property
  end

  test "assign_object wraps collection elements so aliases work" do
    item = Data.define(:sub_property, :another_sub_property)
    model = Data.define(:items).new(items: [item.new(sub_property: "a", another_sub_property: "b")])

    twin = AliasedCollectionTwin.new
    twin.assign_object(model)

    assert_equal 1, twin.items.size
    first = twin.items.first
    assert_respond_to first, :renamed
    assert_equal "a", first.renamed
    assert_equal "b", first.another_sub_property
  end

  test "assign_object populates nested alias via base setter" do
    model = Data.define(:rename_me, :plain).new(rename_me: "omg", plain: "p")
    twin = NestedAliasTwin.new
    twin.assign_object(model)

    # alias getter exposed at top-level via nested proxy
    assert_equal "omg", twin.nested_renamed
    # plain nested property also proxied
    assert_equal "p", twin.plain

    # to_hash groups under :nested with aliased key
    expected = { nested: { nested_renamed: "omg", plain: "p" } }
    assert_equal expected.deep_stringify_keys, twin.to_hash
  end

  test "assign_object tracks the model internally" do
    model = Struct.new(:name, :value).new("test", 42)

    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    obj = klass.new
    obj.assign_object(model)

    assert_equal "test", obj.name
    assert_equal 42, obj.value
    # Should track the model internally
    assert_equal model, obj.instance_variable_get(klass.internal_model_name("model"))
  end

  test "assign_object does not assign read-only value from object" do
    sub_model = Data.define(:my_sub_prop)
    model =
      Data.define(
        :my_usual_prop,
        :my_readonly_prop,
        :my_nested,
        :my_readonly_nested
      ).new("new usual", "new ro", sub_model.new("new sub ro"), sub_model.new("new sub prop"))

    klass = Class.new(Minitwin) do
      property :my_usual_prop
      property :my_readonly_prop, readonly: true
      property :my_nested do
        property :my_sub_readonly, readonly: true
      end
      property :my_readonly_nested, readonly: true do
        property :my_sub_prop
      end
    end

    twin =
      klass.new(
        my_usual_prop: "usual",
        my_readonly_prop: "ro",
        my_nested: { my_sub_readonly: "sub ro" },
        my_readonly_nested: { my_sub_prop: "sub prop" }
      )
    assert_equal "usual", twin.my_usual_prop
    assert_equal "ro", twin.my_readonly_prop
    assert_equal "sub ro", twin.my_nested.my_sub_readonly
    assert_equal "sub prop", twin.my_readonly_nested.my_sub_prop

    twin.assign_object(model)
    assert_equal "new usual", twin.my_usual_prop
    assert_equal "ro", twin.my_readonly_prop
    assert_equal "sub ro", twin.my_nested.my_sub_readonly
    assert_equal "sub prop", twin.my_readonly_nested.my_sub_prop
  end

  # --- assign_hash -----------------------------------------------------------

  test "assign_hash updates array element by index when not a twin/hash" do
    twin = CollectionItemsTwin.new(items: [1, 2, 3])
    twin.assign_hash(items: [9, 8, 7])
    assert_equal [9, 8, 7], twin.items
  end

  test "assign_hash with one key only writes that one attribute" do
    twin = DynamicAliasTwin.new(name: "orig_name", age: 7, email: "orig@x")
    twin.assign_hash(name: "new_name")
    assert_equal "new_name", twin.send(:name)
    assert_equal 7, twin.age
    assert_equal "orig@x", twin.email
  end

  test "assign_hash ignores unknown keys without error" do
    twin = DynamicAliasTwin.new(name: "a")
    twin.assign_hash(name: "b", bogus: 1, other_bogus: 2)
    assert_equal "b", twin.send(:name)
  end

  test "assign_hash updates nested twins" do
    klass = Class.new(Minitwin) do
      property :profile do
        property :bio
      end
    end

    obj = klass.new(bio: "old")
    # assign_hash should update nested twins if the nested object exists
    obj.assign_hash(profile: { bio: "new" })
    assert_equal "new", obj.profile.bio
  end

  test "assign_hash updates collection items" do
    klass = Class.new(Minitwin) do
      collection :items do
        property :name
      end
    end

    obj = klass.new(items: [{ name: "old" }])
    # assign_hash should update collection items
    obj.assign_hash(items: [{ name: "new" }])
    assert_equal "new", obj.items.first.name
  end

  test "assign_hash updates nested collection items" do
    twin = NestedCollectionTwin.from_hash(
      items: [
        { value: 1, nested: { nval: "a" } },
        { value: 2, nested: { nval: "b" } }
      ]
    )

    twin.assign_hash(items: [{}, { nested: { nval: "Z" } }])
    assert_equal "a", twin.items.first.nested.nval
    assert_equal "Z", twin.items.last.nested.nval
  end

  test "assign_hash does not assign read-only value" do
    klass = Class.new(Minitwin) do
      property :my_usual_prop
      property :my_readonly_prop, readonly: true
      property :my_nested do
        property :my_sub_readonly, readonly: true
      end
      property :my_readonly_nested, readonly: true do
        property :my_sub_prop
      end
    end

    twin =
      klass.new(
        my_usual_prop: "usual",
        my_readonly_prop: "ro",
        my_nested: { my_sub_readonly: "sub ro" },
        my_readonly_nested: { my_sub_prop: "sub prop" }
      )
    assert_equal "usual", twin.my_usual_prop
    assert_equal "ro", twin.my_readonly_prop
    assert_equal "sub ro", twin.my_nested.my_sub_readonly
    assert_equal "sub prop", twin.my_readonly_nested.my_sub_prop

    twin.assign_hash(
      my_usual_prop: "new usual",
      my_readonly_prop: "new ro",
      my_nested: { my_sub_readonly: "new sub ro" },
      my_readonly_nested: { my_sub_prop: "new sub prop" }
    )
    assert_equal "new usual", twin.my_usual_prop
    assert_equal "ro", twin.my_readonly_prop
    assert_equal "sub ro", twin.my_nested.my_sub_readonly
    assert_equal "sub prop", twin.my_readonly_nested.my_sub_prop
  end

  # --- assign_params ---------------------------------------------------------

  test "assign_params assigns from hash and ActionController params" do
    twin = BasicPropertyTwin.new
    assert_nil twin.sub_property
    assert_equal "default", twin.another_sub_property

    twin.assign_params({ sub_property: "test", "another_sub_property" => "not default" })
    assert_equal "test", twin.sub_property
    assert_equal "not default", twin.another_sub_property

    twin = BasicPropertyTwin.new
    twin.assign_params(ActionController::Parameters.new(sub_property: "test", another_sub_property: "not default"))
    assert_equal "test", twin.sub_property
    assert_equal "not default", twin.another_sub_property
  end

  test "assign_params accepts a non-ActionController hash" do
    klass = Class.new(Minitwin) do
      property :name
    end

    obj = klass.new
    # Regular hash should work with assign_params
    obj.assign_params(name: "test")
    assert_equal "test", obj.name
  end

  test "assign_params assigns boolean values" do
    twin = BasicPropertyTwin.new(**{ "bool?" => true })
    assert_instance_of TrueClass, twin.bool?
    assert_predicate twin, :bool?
    twin = BasicPropertyTwin.new(**{ "bool?" => false })
    assert_instance_of FalseClass, twin.bool?
    assert_not twin.bool?
  end

  # --- assignable_attribute_methods (white-box fallback branches) ------------

  test "attribute_methods still resolves keys when allowed_attribute_keys is unavailable" do
    klass = Class.new(Minitwin) do
      # Define a writer-only attribute and a plain reader to exercise respond_to? check
      attr_writer :foo

      attr_reader :foo
    end
    def klass.respond_to?(name, include_private = false) # rubocop: disable Style/OptionalBooleanParameter -- is method overwrite from `Object`
      return false if name == :allowed_attribute_keys && include_private

      super
    end
    twin = klass.new
    methods = twin.send(:attribute_methods)
    assert_includes methods, :foo
  end

  test "assign_attribute fallback sets ivar when no setter" do
    klass = Class.new(Minitwin) do
      # no setter defined for :bar
    end
    twin = klass.new
    twin.send(:assign_attribute, method: :bar, value: 123)
    assert_equal 123, twin.instance_variable_get(:@bar)
  end

  test "assign_attribute uses setter branch when available" do
    klass = Class.new(Minitwin) do
      attr_writer :foo

      attr_reader :foo
    end
    obj = klass.new
    obj.send(:assign_attribute, method: :foo, value: 42)
    assert_equal 42, obj.foo
  end
end
