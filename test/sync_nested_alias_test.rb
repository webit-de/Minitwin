# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class SyncNestedAliasTest < ActiveSupport::TestCase
  # Flat model (like ActiveRecord) — no nested structure, just attributes
  FlatModel = Struct.new(:customer_from, :extcusref, :draft_reference, :orderdate, :orderno)

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

  test "sync writes aliased nested property to flat model using as: name" do
    model = FlatModel.new
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

  test "sync does not write to original name when as: alias is used" do
    model = FlatModel.new
    twin = NestedAliasedTwin.from_params(
      order: { orderno: "ORD_456" },
      config: {}
    )

    twin.sync(model, validate: false)

    assert_equal "ORD_456", model.draft_reference
    assert_nil model.orderno, "expected orderno column to remain nil when as: maps to draft_reference"
  end

  # Regression: nested property with as: + type coercion
  TypedModel = Struct.new(:activation_date)

  class TypedNestedTwin < Minitwin
    nested :settings do
      property :start_date, as: :activation_date, type: Types::Params::Date.lax
    end
  end

  test "sync writes typed aliased nested property with coerced value" do
    model = TypedModel.new
    twin = TypedNestedTwin.from_params(settings: { start_date: "2025-06-15" })

    assert twin.sync(model, validate: false)
    assert_equal Date.new(2025, 6, 15), model.activation_date
  end

  # Multiple nested blocks syncing to same flat model
  MultiModel = Struct.new(:name, :mapped_code, :target_date)

  class MultiNestedTwin < Minitwin
    nested :identity do
      property :name
      property :code, as: :mapped_code
    end

    nested :scheduling do
      property :date, as: :target_date
    end
  end

  test "sync from multiple nested blocks with aliases to flat model" do
    model = MultiModel.new
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

    h = twin.to_hash
    assert_equal "ENVT", h[:order][:customer_from]
    assert_equal "REF_1", h[:order][:extcusref]
    assert_equal "ORD_123", h[:order][:draft_reference]
    assert_equal "2017-01-01", h[:config][:orderdate]
    refute h.key?(:customer_from), "proxy should not appear at top level"
    refute h.key?(:orderno), "original name should not appear at top level"
  end
end
