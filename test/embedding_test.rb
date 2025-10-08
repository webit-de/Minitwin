require "test_helper"
require "mini_twin"

class EmbSubTwin < MiniTwin
  property :sub_property
  property :another_sub_property, default: "default"
end

class EmbeddingTwin < MiniTwin
  property :sub_twin, twin: EmbSubTwin
  collection :sub_twins, twin: EmbSubTwin
end

class EmbeddingTest < ActiveSupport::TestCase
  test "should embed sub twins via twin option" do
    obj = EmbeddingTwin.from_hash(
      {
        sub_twin: { sub_property: "test sub property" },
        sub_twins: [
          { sub_property: "test", another_sub_property: "another test" },
          { sub_property: "second property" }
        ]
      }
    )
    assert_instance_of EmbSubTwin, obj.sub_twin
    assert_equal "test sub property", obj.sub_twin.sub_property
    assert_equal 2, obj.sub_twins.size
    assert_equal "test", obj.sub_twins.first.sub_property
    assert_equal "another test", obj.sub_twins.first.another_sub_property
    assert_equal "second property", obj.sub_twins.last.sub_property
    assert_equal "default", obj.sub_twins.last.another_sub_property
  end
end

