require 'benchmark'

Benchmark.bm(7) do |x|
    x.report("first:")   { (1..10000).each { |i| i } }
      x.report("second:") { (1..10000).each { |i| i }}
        x.report("third:")  { (1..10000).each { |i| i }}
end
