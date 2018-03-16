$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname('.'), 'lib')))
$stdout.sync = true
$stderr.sync = true

require 'yaml'

module Axial
  class Bot
    @class_instance = nil
    @class_props_yaml = ""

    def self.create (props_yaml)
      if (@class_instance.nil?)
        @class_props_yaml = props_yaml
        @class_instance = new
      end
      return @class_instance
    end

    def initialize()
      @props_yaml = Bot.instance_variable_get('@class_props_yaml')
      @props = YAML.load_file(File.join(File.dirname(__FILE__), '..', @props_yaml))
      load_defaults
      load_server_settings
      load_props
    end

    def self.instance()
      if (@class_instance.nil?)
        raise(RuntimeError, "Please create an instance of #{self.class} using #{self.class}.create")
      else
        return @class_instance
      end
    rescue Exception => ex
      puts "Bot initialization error: #{ex.class}: #{ex.message}"
      ex.backtrace.each do |i|
        puts i
      end
    end

    def run()
      instance_variables.each do |name|
        puts instance_variable_get(name)
      end
    end


    def load_defaults()
      @binds               = []
      @bot_running         = true
      @channels            = {}
      @connected_to_server = false
      @real_server_name    = ""
      @server_detected     = false
      @server_connection   = nil
    end

    def load_server_settings()
      @server_name    = @props['server']['name']     || 'irc.efnet.org'
      @server_port    = @props['server']['port']     || 6667
      @server_timeout = @props['server']['timeout']  || 10
      @ssl            = @props['server']['ssl']      || false
    end

    def load_props()
      @bot_nick       = @props['bot']['nick']        || 'unnamed'
      @bot_realname   = @props['bot']['real_name']   || 'unnamed'
      @bot_user       = @props['bot']['user_name']   || 'unnamed'
      @addon_list     = @props['addons']             || []
      @autojoin       = @props['channels']           || []
    end
  end
end