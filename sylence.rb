#!/usr/bin/env ruby
$stdout.sync = true
$stderr.sync = true

if (ENV['REMOTE_DEBUG'] == "true")
  my_axial_pid      = Process.pid
  my_rubymine_pid = %x(ps -h -x -o ppid -q #{Process.pid}).split(/n/).first.to_i
  my_sshd_pid =     %x(ps -h -x -o ppid -q #{my_rubymine_pid}).split(/n/).first.to_i

  axial_pids = %x(pgrep -f '^/code/test/sylence.rb' | grep -v pgrep).split(/\n/)
  axial_pids.each do |axial_pid|
    if (axial_pid.to_i != my_axial_pid)
      %x(kill -9 #{axial_pid})
    end
  end

  rubymine_pids = %x(pgrep -f 'JETBRAINS_REMOTE_RUN' | grep -v pgrep).split(/\n/)
  rubymine_pids.each do |rubymine_pid|
    if (rubymine_pid.to_i != my_rubymine_pid)
      %x(kill -9 #{rubymine_pid})
    end
  end

  ssh_notty_pids = %x(pgrep -f 'sshd: axial@notty' | grep -v pgrep).split(/\n/)
  ssh_notty_pids.each do |ssh_notty_pid|
   if (ssh_notty_pid.to_i != my_sshd_pid)
     %x(kill -9 #{ssh_notty_pid})
   end
  end
end

require_relative 'lib/axial/bot.rb'

config_file = 'conf/sylence.yml'

bot = Axial::Bot.new(File.join(File.dirname(__FILE__), config_file))
bot.run
