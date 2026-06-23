# frozen_string_literal: true

require_relative "support/fixtures"
require_relative "support/schemas"
require "benchmark/ips"
require "benchmark/memory"

# SERIALIZE: render a pre-built instance to a hash and to JSON. minitwin and
# representable both render to_hash + to_json. disposable is N/A: its
# to_nested_hash raises NameError (Disposable::Rescheme) on Ruby 4.0.
module Bench
  mt  = MtUser.from_hash(SRC_SYM)
  rep = AVAILABLE[:representable] ? UserRepresenter.new(ostruct_user) : nil

  TO_HASH = lambda do |x|
    x.report("minitwin to_hash")      { mt.to_hash }
    x.report("representable to_hash") { rep.to_hash } if rep
  end

  TO_JSON = lambda do |x|
    x.report("minitwin to_json")     { mt.to_json }
    x.report("representable to_json") { rep.to_json } if rep
  end
end

puts "\n[bench] note: disposable is N/A for SERIALIZE (to_nested_hash raises on Ruby 4.0)."

puts "\n================ SERIALIZE to hash — speed (iterations/sec) ================"
Benchmark.ips do |x|
  Bench::TO_HASH.call(x)
  x.compare!
end

puts "\n================ SERIALIZE to hash — memory (allocations) ================"
Benchmark.memory do |x|
  Bench::TO_HASH.call(x)
  x.compare!
end

puts "\n================ SERIALIZE to json — speed (iterations/sec) ================"
Benchmark.ips do |x|
  Bench::TO_JSON.call(x)
  x.compare!
end

puts "\n================ SERIALIZE to json — memory (allocations) ================"
Benchmark.memory do |x|
  Bench::TO_JSON.call(x)
  x.compare!
end
