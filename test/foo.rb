# frozen_string_literal: true

require 'benchmark'
require 'bigdecimal/math'

# calculate pi to 10k digits
puts "#{(Benchmark.measure { BigMath.PI(100_000) })}"
