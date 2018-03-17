$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname('.'), 'lib')))
$stdout.sync = true
$stderr.sync = true

require 'yaml'
require 'log'
require 'handlers/server_handler'

module Axial
  class Bot
    attr_reader :server, :bot_nick, :bot_realname, :bot_user, :autojoin, :server_consumer
    @class_instance = nil
    @class_props_yaml = ""

    def self.create(props_yaml)
      puts "being created"
      if (@class_instance.nil?)
        @class_props_yaml = props_yaml
        @class_instance = new
      end
      return @class_instance
    end

    def initialize()
      @props_yaml = Bot.instance_variable_get('@class_props_yaml')
      @props = YAML.load_file(File.join(File.dirname(__FILE__), '..', @props_yaml))
      set_defaults
      load_server_settings
      load_properties
      @server_consumer = Consumers::RawConsumer.new(self, :dispatch_server)
      @server_consumer_monitor = Monitor.new
    end

    def self.instance()
      if (@class_instance.nil?)
        raise(RuntimeError, "Please create an instance of Bot using Bot.create(conf/<filename>.yml)")
      else
        return @class_instance
      end
    end

    def run()
      @server_handler = Handlers::ServerHandler.new(self, @server)
      @server_consumer.start
      while (@running)
        @server_handler.loop
      end
    end

    def dispatch_server(msg)
      @server_consumer_monitor.synchronize do
        puts "bot got message from server: #{msg}"
        case msg
          when /^NOTICE \S+ :(.*)/
            LOGGER.info("dispatch :server_notice, #{Regexp.last_match[1]}")
          when /^:\S+ ([0-9][0-9][0-9]) \S+ :{0,1}(.*)/
            puts "[#{Regexp.last_match[1]}] #{Regexp.last_match[2]}"
            #dispatch_numeric(Regexp.last_match[1], Regexp.last_match[2])
          else
            LOGGER.warn("Unhandled: #{msg}")
        end
      end
    end

    def set_defaults()
      @binds               = []
      @running             = true
      @channels            = {}
    end
    private :set_defaults

    def load_server_settings()
      address           = @props['server']['address']  || 'irc.efnet.org'
      port              = @props['server']['port']     || 6667
      timeout           = @props['server']['timeout']  || 10
      ssl               = @props['server']['ssl']      || false
      password          = @props['server']['password'] || ''
      @server           = Server.new(address, port, ssl, password, timeout)
    end
    private :load_server_settings

    def load_properties()
      @bot_nick         = @props['bot']['nick']        || 'unnamed'
      @bot_realname     = @props['bot']['real_name']   || 'unnamed'
      @bot_user         = @props['bot']['user_name']   || 'unnamed'
      @addon_list       = @props['addons']             || []
      @autojoin         = @props['channels']           || []
    end
    private :load_properties
  end
end