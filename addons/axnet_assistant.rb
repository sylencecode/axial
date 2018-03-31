require 'axial/irc_types/nick'
require 'axial/addon'

module Axial
  module Addons
    class AxnetAssistant < Axial::Addon
      def initialize(bot)
        super

        @name    = 'axnet assistant'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        @request_timer                    = nil
        @requests                         = {}

        on_startup                        :start_request_timer
        on_reload                         :start_request_timer

        on_axnet    'ASSISTANCE_REQUEST', :handle_assistance_request
        on_axnet   'ASSISTANCE_RESPONSE', :handle_assistance_response

        on_self_join                      :send_axnet_op_request
        on_self_join                      :clear_pending_join_requests
        on_banned_from_channel            :request_unban
        on_channel_invite_only            :request_invite
        on_channel_full                   :request_limit_increase
        on_channel_keyword                :request_keyword
        on_mode :deops,                   :check_if_mode_deopped
        on_mode :ops,                     :check_if_mode_opped

        on_invite                         :handle_invite
      end

      def request_exists?(channel, request_type)
        key = channel.name.downcase
        exists = false
        if (@requests.has_key?(key))
          possible_requests = requests[key].select{ |request| request.type == request_type.to_sym }
        end
      end

      def check_if_mode_deopped(channel, mode)
        if (mode.deops.any?)
          mode.deops.each do |deop|
            if (deop == myself.name)
              send_axnet_op_request(channel)
            end
          end
        end
      end

      def check_if_mode_opped(channel, mode)
        if (mode.ops.any?)
          mode.deops.each do |op|
            if (op == myself.name)
              clear_pending_op_requests(channel)
            end
          end
        end
      end

      def clear_pending_join_requests(channel)

      end

      def request_unban(channel_name)
        LOGGER.debug("banned from channel #{channel_name}, sending request")
      end

      def request_keyword(channel_name)
        LOGGER.debug("channel #{channel_name} is keyword-protected, sending request")
      end

      def request_invite(channel_name)
        LOGGER.debug("channel #{channel_name} is invite only, sending request")
      end

      def request_limit_increase(channel_name)
        LOGGER.debug("channel #{channel_name} is full, sending request")
      end

      def send_axnet_op_request(channel)
        if (!channel.opped?)
          request_assistance(channel, :deopped)
        end
      end

      def handle_invite(nick, channel_name)
        possible_user = user_list.get_from_nick_object(nick)
        if (bot_or_director?(possible_user))
          LOGGER.debug("got asked to join #{channel_name} by #{nick.uhost}")
          server.join_channel(channel_name)
        end
        return possible_user
      end

      def stop_request_timer()
        LOGGER.debug("stopping request timer")
        timer.delete(@request_timer)
      end

      def start_request_timer()
        LOGGER.debug("starting request timer")
        @request_timer = timer.every_30_seconds(self, :check_for_requests)
      end

      def check_for_requests()
        channel_list.all_channels.each do |channel|
          if (!channel.opped?)
            send_axnet_op_request(channel)
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_axnet_request(handler, command)
        serialized_yaml = command.args
        axnet.relay_to_axnet(handler, 'COMPLAINT ' + serialized_yaml)
        request = YAML.load(serialized_yaml.gsub(/\0/, "\n"))
        bot = IRCTypes::Nick.from_uhost(server, request.uhost)

        if (bot.nil?)
          return
        end

        if (request.type == :deopped)
          channel = channel_list.get_silent(request.channel_name)

          if (channel.nil?)
            return
          elsif (!channel.synced?)
            return
          elsif (!channel.opped?)
            return
          end

          channel_nick = channel.nick_list.get_silent(bot.name)
          if (channel_nick.nil?)
            return
          end

          wait_a_sec

          if (!channel_nick.opped_on?(channel))
            channel.op(channel_nick)
          end
        end
      end

      def send_request(request)
        serialized_yaml = YAML.dump(request).gsub(/\n/, "\0")
        axnet.transmit_to_axnet('COMPLAINT ' + serialized_yaml)
      end

      def request_assistance(channel, type)
        if (channel.is_a?(IRCTypes::Channel))
          channel_name = channel.name
        else
          channel_name = channel
        end

        request = Axnet::AssistanceRequest.new(myself.uhost, channel_name, type.to_sym)

        send_request(request)
      end

      def get_bot_or_user(nick)
        possible_user = user_list.get_from_nick_object(nick)
        if (possible_user.nil?)
          possible_user = bot_list.get_from_nick_object(nick)
        end
        return possible_user
      end

      def get_bot_or_user_mask(mask)
        possible_user = user_list.get_user_from_mask(mask)
        if (possible_user.nil?)
          possible_user = bot_list.get_user_from_mask(mask)
        end
        return possible_user
      end

      def get_bots_or_users_mask(mask)
        bots_or_users = []
        user_list.get_users_from_mask(mask).each do |tmp_mask|
          bots_or_users.push(tmp_mask)
        end
        bot_list.get_users_from_mask(mask).each do |tmp_mask|
          bots_or_users.push(tmp_mask)
        end
        return bots_or_users
      end

      def bot_or_director?(user)
        return (!user.nil? && (user.bot? || user.director?))
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping request timer")
        stop_request_timer
      end
    end
  end
end
