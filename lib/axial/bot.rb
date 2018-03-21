$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname('.'), 'lib')))
$stdout.sync = true
$stderr.sync = true

require 'yaml'
require 'axial/log'
require 'axial/handlers/channel_handler'
require 'axial/handlers/connection_handler'
require 'axial/handlers/message_handler'
require 'axial/handlers/server_handler'
require 'axial/handlers/bind_handler'
require 'axial/handlers/patterns'
require 'axial/dispatchers/server_message_dispatcher'
require 'axial/server_interface'
require 'axial/axnet/user_list'
require 'axial/axnet/axnet_monitor'
require 'string/underscore'

module Axial
  class Bot
    attr_reader :addons, :binds, :nick, :user, :real_name, :server, :server_consumer, :channel_handler,
                :server_handler, :connection_handler, :server_interface, :message_handler, :bind_handler,
                :user_list

    attr_accessor :real_nick
    @class_instance = nil
    @class_props_yaml = ''
    @server = nil
    @user_list = Axnet::UserList.new

    def self.create(props_yaml)
      if (@class_instance.nil?)
        @class_props_yaml = props_yaml
        @class_instance = new
      end
      return @class_instance
    end

    def self.server()
      return @server
    end

    def self.server=(server)
      @server = server
    end

    def initialize()
      @props_yaml = Bot.instance_variable_get('@class_props_yaml')
      @props = YAML.load_file(@props_yaml)
      set_defaults
      load_server_settings
      load_properties
      load_consumers
      load_interfaces
      load_handlers
      load_dispatchers
      load_axnet
      load_addons
    end

    def load_consumers
      @server_consumer            = Consumers::RawConsumer.new(self, :receive_server_text)
      @server_consumer_monitor    = Monitor.new
    end

    def load_interfaces()
      @server_interface           = ServerInterface.new(self)
    end

    def load_handlers()
      @message_handler            = Handlers::MessageHandler.new(self)
      @server_handler             = Handlers::ServerHandler.new(self)
      @channel_handler            = Handlers::ChannelHandler.new(self)
      @bind_handler               = Handlers::BindHandler.new(self)
    end

    def load_axnet()
      @axnet_monitor              = Axnet::AxnetMonitor.new(self)
    end

    def load_dispatchers()
      @server_message_dispatcher  = Dispatchers::ServerMessageDispatcher.new(self)
    end

    def self.instance()
      if (@class_instance.nil?)
        raise(RuntimeError, "Please create an instance of Bot using Bot.create(conf/<filename>.yml)")
      else
        return @class_instance
      end
    end

    def run()
      @connection_handler = Handlers::ConnectionHandler.new(self, @server)
      @server_consumer.start
      while (@running)
        @connection_handler.loop
      end
    end

    def load_addons()
      if (@addon_list.count == 0)
        LOGGER.debug("No addons specified.")
      else
        @addon_list.each do |addon|
          load File.join(File.expand_path(File.join(File.dirname(__FILE__), '..', '..')), 'addons', "#{addon.underscore}.rb")
          addon_object = Object.const_get("Axial::Addons::#{addon}").new(self)
          @addons.push({name: addon_object.name, version: addon_object.version, author: addon_object.author, object: addon_object})
          addon_object.listeners.each do |listener|
            if (listener[:type] == :mode)
              puts "binding modes #{listener[:modes].inspect}"
              @binds.push(type: listener[:type], object: addon_object, command: listener[:command], method: listener[:method].to_sym, modes: listener[:modes])
            else
              @binds.push(type: listener[:type], object: addon_object, command: listener[:command], method: listener[:method].to_sym)
            end
          end
        end
      end
    end

    def unload_addons()
      classes_to_unload = []
      @addons.each do |addon|
        class_name = addon[:object].class.to_s.split('::').last
        classes_to_unload.push(class_name)
        if (addon[:object].respond_to?(:before_reload))
          addon[:object].public_send(:before_reload)
        end
      end

      @binds.clear
      @addons.clear

      classes_to_unload.each do |class_name|
        LOGGER.debug("removing class definition for #{class_name}")
        if (Object.constants.include?(:Axial))
          if (Axial.constants.include?(:Addons))
            if (Axial::Addons.constants.include?(class_name.to_sym))
              Axial::Addons.send(:remove_const, class_name.to_sym)
            end
          end
        end
      end
    end

    def receive_server_text(text)
      @server_consumer_monitor.synchronize do
        @server_message_dispatcher.dispatch(text)
      end
    end

    def autojoin_channels()
      @autojoin_channels.each do |channel|
        if (!channel.has_key?('password') || channel['password'].nil? || channel['password'].empty?)
          channel['password'] = ''
        end
        @server_interface.join(channel['name'], channel['password'])
      end
    end

    def set_defaults()
      @addons             = []
      @binds              = []
      @running            = true
    end
    private :set_defaults

    def load_server_settings()
      address             = @props['server']['address']  || 'irc.efnet.org'
      port                = @props['server']['port']     || 6667
      timeout             = @props['server']['timeout']  || 10
      ssl                 = @props['server']['ssl']      || false
      password            = @props['server']['password'] || ''
      @server             = IRCTypes::Server.new(address, port, ssl, password, timeout)
      Bot.server          = @server
    end
    private :load_server_settings

    def load_properties()
      @addon_list         = @props['addons']             || []
      @autojoin_channels  = @props['channels']           || []
      @nick               = @props['bot']['nick']        || 'unnamed'
      @real_name          = @props['bot']['real_name']   || 'unnamed'
      @user               = @props['bot']['user_name']   || 'unnamed'
      @real_nick          = @props['bot']['nick']        || 'unnamed'
    end
    private :load_properties
  end
end
