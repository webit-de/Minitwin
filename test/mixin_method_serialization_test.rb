require "test_helper"
require "mini_twin"

# Module providing a public instance method that requires arguments.
# Mimics helpers like ActionView::Helpers::UrlHelper#sms_to which are mixed
# into twins but must not be treated as serializable getters.
module MixinWithArgMethod
  def needs_args(a, b = nil, c = nil)
    [a, b, c]
  end

  # Mixed-in setter, mimics helpers like ActionView's #output_buffer=.
  # Must not be treated as an assignable attribute. Raises if invoked so a
  # test can detect from_hash wrongly calling it.
  def mixin_setter=(_value)
    raise "mixed-in setter must not be invoked by from_hash"
  end
end

class MixinTwin < Minitwin
  include MixinWithArgMethod

  property :name

  # Plain getter defined directly on the twin must still be serialized.
  def computed
    "computed-#{name}"
  end
end

class MixinMethodSerializationTest < ActiveSupport::TestCase
  test "mixed-in module methods are not serialized" do
    obj = MixinTwin.from_hash(name: "x")

    hash = obj.to_hash

    assert_not hash.key?(:needs_args), "mixed-in method should not be serialized"
    assert_equal "x", hash[:name]
    assert_equal "computed-x", hash[:computed], "plain getter defined on twin must still serialize"
  end

  test "mixed-in module setters are not assignable attributes" do
    obj = nil

    assert_nothing_raised do
      obj = MixinTwin.from_hash(name: "x", mixin_setter: "boom")
    end

    assert_equal "x", obj.to_hash[:name]
  end
end
