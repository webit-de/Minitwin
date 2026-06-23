# frozen_string_literal: true

# Runs every benchmark script in sequence. Each script executes its benchmarks
# at require time.
require_relative "construct_bench"
require_relative "read_bench"
require_relative "serialize_bench"
require_relative "mutate_validate_bench"
