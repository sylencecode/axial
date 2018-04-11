#!/usr/bin/env ruby

Dir.glob('**/**').each do |entry|
  depth = entry.split(/\//).count
  if (File.directory?(entry))
    if (entry !~ /^test/ && entry !~ /^tools/ && entry !~ /^conf/ && entry !~ /^certs/)
      File.open(File.join(entry, '.rubocop.yml'), 'w') do |handle|
        handle.puts('---')
        handle.puts('inherit_from: ../.rubocop.yml')
      end
    end
  end
end
