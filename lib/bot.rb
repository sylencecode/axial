$:.unshift(File.expand_path(File.join(File.dirname('.'), 'lib')))
$stdout.sync = true
$stderr.sync = true

require 'yaml'
require 'timeout'
require 'socket'

require 'colors.rb'
require 'channel.rb'
require 'command.rb'
require 'constants.rb'
require 'addon.rb'
require 'log.rb'
require 'underscore.rb'

# handlers...need eventing
# require 'handlers/server_handler.rb'
# require 'handlers/message_handler.rb'

# move to an addon?
require 'models/init.rb'

class Bot
#  include Singleton
  @instance   = nil
  @props_yaml = nil

  def self.config=(props_yaml)
    @props_yml = props_yaml
  end

  def initialize()
    @props = YAML.load_file(File.join(File.dirname(__FILE__), '..', @props_file))
    load_defaults
    load_server_settings
    load_props
  end

  def load_defaults()
    @binds               = []
    @bot_running         = true
    @channels            = {}
    @connected_to_server = false
    @props_file          = props_file
    @real_server_name    = ""
    @server_detected     = false
    @serverconn          = nil
  end

  def load_server_settings()
    @server_name    = props['server']['name']     || 'irc.efnet.org'
    @server_port    = props['server']['port']     || 6667
    @server_timeout = props['server']['timeout']  || 10
    @ssl            = props['server']['ssl']      || false
  end

  def load_props()
    @bot_nick       = props['bot']['nick']        || 'unnamed'
    @bot_realname   = props['bot']['real_name']   || 'unnamed'
    @bot_user       = props['bot']['user_name']   || 'unnamed'
    @addon_list     = props['addons']             || []
    @autojoin       = props['channels']           || []
  end

  def self.instance()
    if (@instance.nil?)
      @instance = new
    else
      return @instance 
    end
  rescue Exception => ex
    puts "Bot initialization error: #{ex.class}: #{ex.message}"
    ex.backtrace.each do |i|
      puts i
    end
  end
end

Bot.new('asdf')
puts Bot.instance.inspect
#puts foo.obj.inspect
exit 0
 foo1 = Bot.instance()
 foo1.array.push(1)
 foo1.server = "server1"
 foo2 = Bot.instance()
 foo2.array.push(1)
 foo2.server = "server1"
 foo3 = Bot.instance()
 foo3.array.push(1)
 foo3.server = "server1"
 foo4 = Bot.instance()
 foo4.array.push(4)
 foo4.server = "server4"
 foo5 = Bot.instance()
 foo5.array.push(1)
 foo5.server = "server5"
# foo.run("botname")
 puts foo1.inspect 
 puts foo2.inspect
 puts foo3.inspect
