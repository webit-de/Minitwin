# Optional dry-types Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove dry-types as a hard runtime dependency so mini-twin works without it, while keeping full support when it's installed.

**Architecture:** Mirror the existing ActiveModel pattern — `begin/rescue LoadError` around the require, guard dry-types-specific constants with `defined?()`. Remove MiniTwin::Types module; users reference Dry::Types directly or use any callable for `type:`.

**Tech Stack:** Ruby, dry-types (optional), minitest

---

### Task 1: Move dry-types to optional dependency in gemspec

**Files:**
- Modify: `mini-twin.gemspec:19`

**Step 1: Update gemspec**

Change line 19 from:
```ruby
spec.add_dependency "dry-types", ">= 1.7"
```
to:
```ruby
spec.add_development_dependency "dry-types", ">= 1.7"
```

**Step 2: Update gemspec description**

Change line 11 from:
```ruby
spec.description = "A minimal twin/presenter object with nested/collection properties, type coercion via dry-types, and optional ActiveModel validations."
```
to:
```ruby
spec.description = "A minimal twin/presenter object with nested/collection properties, optional type coercion, and optional ActiveModel validations."
```

**Step 3: Run bundle install to verify**

Run: `bundle install`
Expected: Success, dry-types still installed as dev dependency

**Step 4: Commit**

```
git add mini-twin.gemspec
git commit -m "[TASK] Move dry-types from runtime to development dependency"
```

---

### Task 2: Make dry-types require optional in entry point

**Files:**
- Modify: `lib/mini_twin.rb:5`

**Step 1: Wrap require in begin/rescue**

Change line 5 from:
```ruby
require "dry-types"
```
to:
```ruby
begin
  require "dry-types"
rescue LoadError
end
```

**Step 2: Run tests to verify nothing breaks**

Run: `bundle exec rake test`
Expected: All tests pass (dry-types is still installed as dev dependency)

**Step 3: Commit**

```
git add lib/mini_twin.rb
git commit -m "[TASK] Make dry-types require optional with begin/rescue LoadError"
```

---

### Task 3: Delete MiniTwin::Types module

**Files:**
- Delete: `lib/mini_twin/types.rb`

**Step 1: Delete the file**

```bash
rm lib/mini_twin/types.rb
```

**Step 2: Run tests — expect failures**

Run: `bundle exec rake test`
Expected: Failures in tests that reference `Types::` or `MiniTwin::Types::` (this is expected, we fix tests in Task 5)

**Step 3: Commit**

```
git add lib/mini_twin/types.rb
git commit -m "[TASK] Remove MiniTwin::Types module — users reference Dry::Types directly"
```

---

### Task 4: Guard Dry::Types::CoercionError in types_helper.rb

**Files:**
- Modify: `lib/mini_twin/class_methods/types_helper.rb:57-62`

**Step 1: Update attempt_type_coercion**

Replace the current method:
```ruby
def attempt_type_coercion(raw_value, type)
  return raw_value unless type
  type.call(raw_value)
rescue ::Dry::Types::CoercionError, TypeError, ArgumentError
  raw_value
end
```

With:
```ruby
def attempt_type_coercion(raw_value, type)
  return raw_value unless type
  type.call(raw_value)
rescue *self.coercion_error_classes
  raw_value
end

def coercion_error_classes
  classes = [TypeError, ArgumentError]
  classes.unshift(::Dry::Types::CoercionError) if defined?(::Dry::Types::CoercionError)
  classes
end
```

**Step 2: Commit**

```
git add lib/mini_twin/class_methods/types_helper.rb
git commit -m "[TASK] Guard Dry::Types::CoercionError for when dry-types is not loaded"
```

---

### Task 5: Fix test references from MiniTwin::Types to Dry::Types

**Files:**
- Modify: `test/test_helper.rb` — add Types module definition
- Modify: all test files using `MiniTwin::Types::` — change to `Types::`

**Step 1: Add Types module to test_helper.rb**

Add after line 24 (`require "active_model"`), before the TestCase class:

```ruby
# Provide Types shorthand for dry-types in tests
# (MiniTwin no longer ships its own Types module)
require "mini_twin"
module Types
  include Dry.Types()
end
```

Note: `require "mini_twin"` is needed here to ensure mini_twin is loaded before defining Types, since Bundler auto-require may not have run yet at this point in the load sequence.

**Step 2: Replace MiniTwin::Types:: with Types:: in all test files**

These files need `MiniTwin::Types::` replaced with `Types::`:
- `test/types_integration_test.rb` — lines 7-8
- `test/edge_cases_test.rb` — lines 7, 67, 154, 261, 275, 285, 295
- `test/error_handling_test.rb` — line 88
- `test/rbs_generation_test.rb` — lines 27, 104-106
- `test/rbs_output_example_test.rb` — lines 11-21, 57-60
- `test/coverage_additional_test.rb` — line 32

For `MiniTwin::Types.Constructor(...)` (edge_cases_test.rb:295), change to `Types.Constructor(...)`.

**Step 3: Run tests**

Run: `bundle exec rake test`
Expected: All tests pass

**Step 4: Commit**

```
git add test/
git commit -m "[TASK] Update test type references from MiniTwin::Types to Types module"
```

---

### Task 6: Add test for plain lambda as type coercer

**Files:**
- Modify: `test/types_integration_test.rb`

**Step 1: Write the test**

Add to `test/types_integration_test.rb`:

```ruby
class LambdaTypeTwin < MiniTwin
  property :count, type: ->(v) { Integer(v) }, default: 0
  property :label, type: ->(v) { v.to_s.strip }
end

class LambdaTypeTest < ActiveSupport::TestCase
  test "lambda type coerces values" do
    twin = LambdaTypeTwin.from_hash(count: "42", label: "  hello  ")
    assert_equal 42, twin.count
    assert_equal "hello", twin.label
  end

  test "lambda type uses explicit default" do
    twin = LambdaTypeTwin.from_hash({})
    assert_equal 0, twin.count
  end
end
```

**Step 2: Run the test**

Run: `bundle exec ruby -Ilib -Itest test/types_integration_test.rb`
Expected: All tests pass

**Step 3: Commit**

```
git add test/types_integration_test.rb
git commit -m "[TASK] Add test for lambda as type: coercer"
```

---

### Task 7: Final verification

**Step 1: Run full test suite**

Run: `bundle exec rake test`
Expected: All tests pass, coverage meets thresholds

**Step 2: Verify no remaining MiniTwin::Types references**

Run: `grep -r "MiniTwin::Types" lib/ test/`
Expected: No output (no remaining references)

**Step 3: Squash-ready commit if needed**

All changes should already be committed individually. Verify with `git log --oneline`.
