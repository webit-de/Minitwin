require "test_helper"

class NoActiveModelInitTest < ActiveSupport::TestCase
  test "twin initializes without ActiveModel loaded" do
    lib_path = File.expand_path("../lib", __dir__)
    script = <<~RUBY
      $LOAD_PATH.unshift(#{lib_path.inspect})

      # Stub require to skip active_model so MiniTwin loads without it.
      module Kernel
        alias_method :__orig_require__, :require
        def require(path)
          return false if path == "active_model"
          __orig_require__(path)
        end
      end

      require "mini_twin"
      raise "ActiveModel leaked" if defined?(ActiveModel::Model)

      class T < MiniTwin
        property :name
      end

      t = T.new(name: "ok")
      puts t.name
    RUBY

    out = IO.popen([RbConfig.ruby, "-e", script], err: %i[child out], &:read)
    assert_equal 0, $?.exitstatus, "child failed: #{out}"
    assert_match(/^ok$/, out)
  end
end
