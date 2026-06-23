# frozen_string_literal: true

require_relative "support/fixtures"
require_relative "support/schemas"
require "benchmark/ips"
require "benchmark/memory"

# READ: access a flat field, a nested field, and iterate the collection on a
# pre-built instance. Representable is N/A — it is a render/parse layer over the
# model, not a read-access layer.
module Bench
  mt   = MtUser.from_hash(SRC_SYM)
  disp = AVAILABLE[:disposable] ? DispUser.new(ostruct_user) : nil

  read = lambda do |o|
    o.name
    o.address.city
    o.roles.each { |r| r } # touch every element
  end

  READ = lambda do |x|
    x.report("minitwin read")    { read.call(mt) }
    x.report("disposable read")  { read.call(disp) } if disp
  end
end

puts "\n[bench] note: representable is N/A for READ (it is a render/parse layer, not a reader)."

puts "\n================ READ — speed (iterations/sec) ================"
Benchmark.ips do |x|
  Bench::READ.call(x)
  x.compare!
end

puts "\n================ READ — memory (allocations) ================"
Benchmark.memory do |x|
  Bench::READ.call(x)
  x.compare!
end
