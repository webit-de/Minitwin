# frozen_string_literal: true

require_relative "support/fixtures"
require_relative "support/schemas"
require "benchmark/ips"
require "benchmark/memory"
require "ostruct"

# CONSTRUCT: build a twin from source data. Minitwin gets a from_hash bar (no
# backing object — something Disposable cannot do) plus from_object across four
# backing types; Disposable wraps each backing type. Representable is N/A here:
# its nested from_hash parse raises on Ruby 4.0 (representable 3.2.0); it appears
# in the serialize benchmark (render) instead.
module Bench
  CONSTRUCT = lambda do |x|
    backing = backing_objects

    x.report("minitwin from_hash") { MtUser.from_hash(SRC_SYM) }
    backing.each do |name, model|
      x.report("minitwin from_object(#{name})") { MtUser.from_object(model) }
    end

    if AVAILABLE[:disposable]
      backing.each do |name, model|
        x.report("disposable new(#{name})") { DispUser.new(model) }
      end
    end
  end
end

puts "\n[bench] note: representable is N/A for CONSTRUCT (nested from_hash parse raises on Ruby 4.0)."

puts "\n================ CONSTRUCT — speed (iterations/sec) ================"
Benchmark.ips do |x|
  Bench::CONSTRUCT.call(x)
  x.compare!
end

puts "\n================ CONSTRUCT — memory (allocations) ================"
Benchmark.memory do |x|
  Bench::CONSTRUCT.call(x)
  x.compare!
end
