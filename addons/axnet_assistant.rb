require 'axial/addon'
require 'axial/mask_utils'
require 'axial/irc_types/nick'
require 'axial/axnet/assistance_request'
require 'axial/axnet/assistance_response'

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

        on_banned_from_channel            :request_unban
        on_channel_invite_only            :request_invite
        on_channel_full                   :request_limit_increase
        on_channel_keyword                :request_keyword

        on_mode :deops,                   :check_if_deopped
        on_mode :ops,                     :check_if_opped

        on_self_join                      :check_if_opped
        on_self_join                      :clear_pending_join_requests

        on_invite                         :handle_invite
      end

      def clear_pending(channel, type)
        if (channel.is_a?(IRCTypes::Channel))
          key = channel.name.downcase
        else
          key = channel.downcase
        end

        if (@requests.has_key?(key))
          @requests[key].delete(type.to_sym)
        end
      end

      def queue_request(channel, type)
        if (channel.is_a?(IRCTypes::Channel))
          key = channel.name.downcase
        else
          key = channel.downcase
        end

        if (!@requests.has_key?(key))
          @requests[key] = [ type.to_sym ]
        elsif (!@requests[key].include?(type.to_sym))
          @requests[key].push(type.to_sym)
          request(key, type.to_sym)
        end
      end

      def request(channel, type)
        if (channel.is_a?(IRCTypes::Channel))
          channel_name = channel.name.downcase
        else
          channel_name = channel.downcase
        end

        if (myself.uhost.empty?)
          LOGGER.warn("cannot dispatch assistance request, bot uhost is unknown")
        else
          bot_nick = IRCTypes::Nick.new(nil)
          bot_nick.uhost = myself.uhost
          request = Axnet::AssistanceRequest.new(bot_nick, channel_name, type.to_sym)
          send_request(request)
        end
      end

      def clear_pending_join_requests(channel)
        clear_pending(channel, :keyword)
        clear_pending(channel, :full)
        clear_pending(channel, :invite)
        clear_pending(channel, :banned)
      end

      def check_if_deopped(channel, nick, mode)
        if (mode.deops.any?)
          mode.deops.each do |deop|
            if (deop == myself.name)
              queue_request(channel, :op)
            end
          end
        end
      end

      def check_if_opped(channel, nick = nil, mode = nil)
        if (mode.nil?)
          if (!channel.opped?)
            queue_request(channel, :op)
          end
        elsif (mode.ops.any?)
          mode.ops.each do |op|
            if (op == myself.name)
              clear_pending(channel, :op)
            end
          end
        end
      end

      def request_unban(channel_name)
        queue_request(channel_name, :banned)
      end

      def request_keyword(channel_name)
        queue_request(channel_name, :keyword)
      end

      def request_invite(channel_name)
        queue_request(channel_name, :invite)
      end

      def request_limit_increase(channel_name)
        queue_request(channel_name, :full)
      end

      def handle_invite(nick, channel_name)
        possible_user = get_bot_or_user(nick)
        if (bot_or_director?(possible_user))
          clear_pending(channel_name, :invite)
          if (!server.trying_to_join.has_key?(channel_name.downcase))
            server.trying_to_join[channel_name.downcase] = ''
          end
          server.join_channel(channel_name)
        end
        return possible_user
      end

      def check_for_requests()
        @requests.each do |channel_name, pending_requests|
          pending_requests.each do |pending_request|
            request(channel_name, pending_request)
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_assistance_request(handler, command)
        serialized_yaml = command.args
        if (axnet.master?)
          axnet.relay(handler, 'ASSISTANCE_REQUEST ' + serialized_yaml)
        end

        request = YAML.load(serialized_yaml.gsub(/\0/, "\n"))

        case request.type
          when :op
            handle_op_request(request.channel_name, request.bot_nick)
          when :invite
            handle_invite_request(request.channel_name, request.bot_nick)
          when :full
            handle_full_request(request.channel_name, request.bot_nick)
          when :keyword
            handle_keyword_request(request.channel_name, request.bot_nick)
          when :banned
            handle_banned_request(request.channel_name, request.bot_nick)
        end
      end

      def handle_invite_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)
        if (!channel.nil? && channel.opped?)
          channel.invite(bot_nick.name)
        end
      end

      def handle_assistance_response(handler, command)
        serialized_yaml = command.args
        if (axnet.master?)
          axnet.relay(handler, 'ASSISTANCE_RESPONSE ' + serialized_yaml)
        end

        response = YAML.load(serialized_yaml.gsub(/\0/, "\n"))

        case response.type
          when :keyword
            handle_keyword_response(response.channel_name, response.response)
          else
            LOGGER.warn("unknown axnet assistance response: #{response.inspect}")
        end
      end

      def handle_keyword_response(channel_name, keyword)
        if (server.trying_to_join.has_key?(channel_name.downcase))
          server.trying_to_join[channel_name.downcase] = keyword
        end
      end

      def handle_banned_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)
        if (!channel.nil?)
          if (channel.opped?)
            response_mode = IRCTypes::Mode.new
            channel.ban_list.all_bans.each do |ban|
              if (MaskUtils.masks_match?(ban.mask, bot_nick.uhost))
                response_mode.unban(ban.mask)
              end
            end

            if (response_mode.any?)
              channel.set_mode(response_mode)
            end

            channel.invite(bot_nick.name)
          end
        end
      end

      def handle_keyword_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)
        if (!channel.nil?)
          if (channel.mode.keyword?)
            response = Axnet::AssistanceResponse.new(channel.name, :keyword, channel.mode.keyword)
            send_response(response)
          end
        end
      end

      def handle_full_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)
        if (!channel.nil? && channel.opped?)
          if (channel.mode.limit?)
            response_mode = IRCTypes::Mode.new
            response_mode.limit = channel.nick_list.count + 1
            channel.set_mode(response_mode)
            channel.invite(bot_nick.name)
          end
        end
      end

      def handle_op_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)

        if (channel.nil?)
          return
        elsif (!channel.synced?)
          return
        elsif (!channel.opped?)
          return
        end

        channel_nick = channel.nick_list.get_silent(bot_nick)
        if (channel_nick.nil?)
          return
        end

        wait_a_sec

        if (!channel_nick.opped_on?(channel))
          channel.op(channel_nick)
        end
      end

      def send_request(request)
        LOGGER.debug("sending assistance request: #{request.type}, #{request.channel_name}, #{request.bot_nick.uhost}")
        serialized_yaml = YAML.dump(request).gsub(/\n/, "\0")
        axnet.send('ASSISTANCE_REQUEST ' + serialized_yaml)
      end

      def send_response(response)
        LOGGER.debug("sending asssistance response: #{response.type}, #{response.channel_name}, #{response.response}")
        serialized_yaml = YAML.dump(response).gsub(/\n/, "\0")
        axnet.send('ASSISTANCE_RESPONSE ' + serialized_yaml)
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

      def stop_request_timer()
        LOGGER.debug("stopping request timer")
        timer.delete(@request_timer)
      end

      def start_request_timer()
        LOGGER.debug("starting request timer")
        @request_timer = timer.every_30_seconds(self, :check_for_requests)
      end

      def bot_or_director?(user)
        return (!user.nil? && (user.bot? || user.director?))
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping request timer")
        stop_request_timer
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
