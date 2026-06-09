# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class SyncAsAliasTest < ActiveSupport::TestCase
  test "sync writes to aliased attribute on target model" do
    model = Struct.new(:draft_reference).new(nil)

    klass = Class.new(Minitwin) do
      property :orderno, as: :draft_reference
    end

    twin = klass.from_params(orderno: "ABC123")
    assert twin.sync(model, validate: false)
    assert_equal "ABC123", model.draft_reference
  end

  test "sync uses alias for respond_to check on target model" do
    model = Struct.new(:mapped_name).new("old")

    klass = Class.new(Minitwin) do
      property :name, as: :mapped_name
    end

    twin = klass.new(name: "new_value")
    assert twin.sync(model, validate: false)
    assert_equal "new_value", model.mapped_name
  end

  test "sync skips property when aliased writer is not available on target" do
    model = Struct.new(:unrelated).new("original")

    klass = Class.new(Minitwin) do
      property :foo, as: :nonexistent_attr
    end

    twin = klass.new(foo: "bar")
    assert twin.sync(model, validate: false)
    assert_equal "original", model.unrelated
  end

  test "sync deep-syncs nested twin using alias" do
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

  test "sync deep-syncs collection using alias" do
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

  test "sync ignores Proc as: and uses original method name" do
    model = Struct.new(:code).new("old")

    klass = Class.new(Minitwin) do
      property :code, as: -> { "dynamic" }
    end

    twin = klass.new(code: "new_value")
    assert twin.sync(model, validate: false)
    assert_equal "new_value", model.code
  end

  test "sync works with string as: value" do
    model = Struct.new(:target_field).new(nil)

    klass = Class.new(Minitwin) do
      property :source, as: "target_field"
    end

    twin = klass.new(source: "hello")
    assert twin.sync(model, validate: false)
    assert_equal "hello", model.target_field
  end

  test "sync without as: still uses original property name" do
    model = Struct.new(:name).new("old")

    klass = Class.new(Minitwin) do
      property :name
    end

    twin = klass.new(name: "new")
    assert twin.sync(model, validate: false)
    assert_equal "new", model.name
  end
end
