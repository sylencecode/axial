
ip = '74.208.183.199'

fragments = ip.split('.')

long_ip = 0

block = 4
fragments.each do |fragment|
  block -= 1
  long_ip += fragment.to_i * (256 ** block)
end

puts "\x01DCC CHAT #{long_ip} 6667\x01"
