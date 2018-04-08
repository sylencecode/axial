$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

$stdout.sync = true
$stderr.sync = true

gem 'git'
require 'git'
require 'yaml'
require 'axial/log'
require 'axial/handlers/timer_handler'
require 'axial/handlers/channel_handler'
require 'axial/handlers/connection_handler'
require 'axial/handlers/message_handler'
require 'axial/handlers/server_handler'
require 'axial/handlers/bind_handler'
require 'axial/handlers/patterns'
require 'axial/handlers/dcc_state'
require 'axial/dispatchers/server_message_dispatcher'
require 'axial/interfaces/server_interface'
require 'string/underscore'

module Axial
  class Bot
    attr_reader   :addons, :binds, :nick, :user, :real_name, :server, :server_consumer, :channel_handler,
                  :server_handler, :connection_handler, :server_interface, :message_handler, :bind_handler,
                  :axnet, :ban_list, :user_list, :timer, :bot_list, :channel_command_character,
                  :dcc_command_character, :dcc_state

    attr_accessor :real_nick, :local_cn

    def initialize(config_yaml)
      @config_yaml = config_yaml
      set_defaults
      load_config
      load_server_settings
      load_consumers
      load_axnet
      load_interfaces
      load_handlers
      load_dispatchers
      load_addons
      notify_startup
    end

    def notify_startup()
      @bind_handler.dispatch_startup_binds
    end

    def load_consumers
      @server_consumer            = Consumers::RawConsumer.new
      @server_consumer_monitor    = Monitor.new

      @server_consumer.register_callback(self, :receive_server_text)
    end

    def load_interfaces()
      @server_interface           = Interfaces::ServerInterface.new(self)
    end

    def load_handlers()
      @message_handler            = Handlers::MessageHandler.new(self)
      @server_handler             = Handlers::ServerHandler.new(self)
      @channel_handler            = Handlers::ChannelHandler.new(self)
      @bind_handler               = Handlers::BindHandler.new(self)
      @timer                      = Handlers::TimerHandler.new
      @dcc_state                  = Handlers::DCCState

      @timer.start
    end

    def load_axnet()
      Kernel.load(File.expand_path(File.join(File.dirname(__FILE__), 'interfaces/axnet_interface.rb')))
      @axnet                      = Interfaces::AxnetInterface.new(self)
      @bot_list                   = Axnet::UserList.new
      @user_list                  = Axnet::UserList.new
      @ban_list                   = Axnet::BanList.new
      @local_cn                   = nil

      @axnet.register_queue_callback
      @axnet.start
    end

    def reload_axnet()
      @axnet.stop
      class_name = "Axial::Interfaces::AxnetInterface"
      LOGGER.debug("removing class definition for #{class_name}")
      if (Object.constants.include?(:Axial))
        if (Axial.constants.include?(:Interfaces))
          if (Axial::Interfaces.constants.include?(class_name.to_sym))
            LOGGER.debug("axnet interface found")
            Axial::Interfaces.send(:remove_const, class_name.to_sym)
            LOGGER.debug("axnet interface definition deleted")
          end
        end
      end
      Kernel.load(File.expand_path(File.join(File.dirname(__FILE__), 'interfaces/axnet_interface.rb')))
      old_axnet = @axnet
      @axnet = Interfaces::AxnetInterface.copy(self, old_axnet)
      @axnet.start
    end

    def load_dispatchers()
      @server_message_dispatcher  = Dispatchers::ServerMessageDispatcher.new(self)
    end

    def run()
      @connection_handler = Handlers::ConnectionHandler.new(self, @server)
      @server_consumer.start
      while (@running)
        @connection_handler.loop
      end
    end

    def reload_addons()
      unload_addons
      @config             = YAML.load_file(@config_yam)
      @addon_list         = @config['addons'] || []
      load_addons
      @bind_handler.dispatch_reload_binds
    end

    def load_addons()
      if (@addon_list.count == 0)
        LOGGER.debug("No addons specified.")
      else
        @addon_list.each do |addon|
          load File.join(File.expand_path(File.join(File.dirname(__FILE__), '..', '..')), 'addons', "#{addon.underscore}.rb")
          addon_object = Object.const_get("Axial::Addons::#{addon}").new(self)
          @addons.push({name: addon_object.name, version: addon_object.version, author: addon_object.author, object: addon_object})
          addon_object.binds.each do |bind|
            if (bind[:type] == :mode)
              @binds.push(type: bind[:type], object: addon_object, method: bind[:method], modes: bind[:modes], silent: bind[:silent])
            elsif (bind[:type] == :channel_leftover)
              if (bind.has_key?(:args) && bind[:args].any?)
                @binds.push(type: bind[:type], object: addon_object, text: bind[:text], method: bind[:method], args: bind[:args], silent: bind[:silent])
              else
                @binds.push(type: bind[:type], object: addon_object, text: bind[:text], method: bind[:method], silent: bind[:silent])
              end
            else
              if (bind.has_key?(:args) && bind[:args].any?)
                @binds.push(type: bind[:type], object: addon_object, command: bind[:command], method: bind[:method], args: bind[:args], silent: bind[:silent])
              else
                @binds.push(type: bind[:type], object: addon_object, command: bind[:command], method: bind[:method], silent: bind[:silent])
              end
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

    def git_pull()
      if (ENV['REMOTE_DEBUG'] != "true")
        repo_object = Git.open(File.expand_path(File.join(File.dirname(__FILE__), '..', '..')), log: LOGGER)
        repo_object.pull
      end
    end

    def whois_myself()
      @server_interface.send_raw("WHOIS #{@real_nick}")
    end

    def autojoin_channels()
      @autojoin_channels.each do |channel|
        if (!channel.has_key?('password') || channel['password'].nil? || channel['password'].empty?)
          channel['password'] = ''
        end
        if (!@server_interface.trying_to_join.has_key?(channel['name'].downcase))
          @server_interface.trying_to_join[channel['name'].downcase] = channel['password']
        end
        @server_interface.join_channel(channel['name'].downcase, channel['password'])
      end
    end

    def set_defaults()
      @addons                     = []
      @binds                      = []
      @running                    = true
    end
    private :set_defaults

    def load_server_settings()
      address                     = @config['server']['address']         || 'irc.efnet.org'
      port                        = @config['server']['port']            || 6667
      timeout                     = @config['server']['timeout']         || 10
      ssl                         = @config['server']['ssl']             || false
      password                    = @config['server']['password']        || ''

      @server                     = IRCTypes::Server.new(address, port, ssl, password, timeout)
    end
    private :load_server_settings

    def load_config()
      @config                     = YAML.load_file(@config_yaml)
      @addon_list                 = @config['addons']                    || []
      @autojoin_channels          = @config['channels']                  || []
      @nick                       = @config['bot']['nick']               || 'unnamed'
      @real_name                  = @config['bot']['real_name']          || 'unnamed'
      @user                       = @config['bot']['user_name']          || 'unnamed'
      @real_nick                  = @config['bot']['nick']               || 'unnamed'
      @dcc_command_character      = @config['dcc_command_character']     || '.'
      @channel_command_character  = @config['channel_command_character'] || '?'
      @real_nick                  = @config['bot']['nick']               || 'unnamed'
    end
    private :load_config
  end
end
