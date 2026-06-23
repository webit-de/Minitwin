# frozen_string_literal: true

require_relative "support/fixtures"
require_relative "support/schemas"
require "benchmark/ips"
require "benchmark/memory"

# MUTATE: change a field and push it back to the model in place. minitwin and
# disposable both do this; disposable's sync never validates, so the like-for-like
# bar is minitwin sync(validate: false). The default minitwin bar (sync validates)
# shows what that built-in validation pass costs on top. Representable is N/A, and
# Reform is omitted because its sync IS Disposable's sync (Reform extends it).
#
# VALIDATE: run validation on valid and invalid input. minitwin valid? (on a
# pre-built twin) vs Reform validate(params); both use the ActiveModel backend.
# Note: Reform has no validate-only call - validate(params) also POPULATES the
# form, so its bar includes population, whereas minitwin valid? is validation
# only. disposable/representable have no validation.
module Bench
  mt_sync   = MtUser.from_object(ostruct_user)
  disp_sync = AVAILABLE[:disposable] ? DispUser.new(ostruct_user) : nil

  MUTATE = lambda do |x|
    # validate: false isolates the write-back, apples-to-apples with disposable
    # (whose sync never validates).
    x.report("minitwin assign+sync (validate: false)") do
      mt_sync.name = "Changed"
      mt_sync.sync(validate: false)
    end
    # Default sync also runs a full valid? pass; this bar shows that cost.
    x.report("minitwin assign+sync (default, validates)") do
      mt_sync.name = "Changed"
      mt_sync.sync
    end
    if disp_sync
      x.report("disposable assign+sync") do
        disp_sync.name = "Changed"
        disp_sync.sync
      end
    end
  end

  mt_good     = MtUser.from_hash(SRC_SYM)
  mt_bad      = MtUser.from_hash(INVALID_SYM)
  reform_form = AVAILABLE[:reform] ? UserForm.new(ostruct_user) : nil

  VALIDATE_VALID = lambda do |x|
    x.report("minitwin valid? (valid)")  { mt_good.valid? }
    x.report("reform validate (valid)")  { reform_form.validate(SRC_SYM) } if reform_form
  end

  VALIDATE_INVALID = lambda do |x|
    x.report("minitwin valid? (invalid)") { mt_bad.valid? }
    x.report("reform validate (invalid)") { reform_form.validate(INVALID_SYM) } if reform_form
  end
end

puts "\n[bench] note: MUTATE — disposable sync never validates; minitwin sync(validate: false) is the like-for-like write-back. Reform's sync == Disposable's, so it is omitted here."
puts "[bench] note: representable is N/A for MUTATE; disposable/representable are N/A for VALIDATE."
puts "[bench] note: reform validate(params) also populates the form (no validate-only API); minitwin valid? is validation only."

puts "\n================ MUTATE — speed (iterations/sec) ================"
Benchmark.ips do |x|
  Bench::MUTATE.call(x)
  x.compare!
end

puts "\n================ MUTATE — memory (allocations) ================"
Benchmark.memory do |x|
  Bench::MUTATE.call(x)
  x.compare!
end

puts "\n================ VALIDATE valid object — speed (iterations/sec) ================"
Benchmark.ips do |x|
  Bench::VALIDATE_VALID.call(x)
  x.compare!
end

puts "\n================ VALIDATE invalid object — speed (iterations/sec) ================"
Benchmark.ips do |x|
  Bench::VALIDATE_INVALID.call(x)
  x.compare!
end
