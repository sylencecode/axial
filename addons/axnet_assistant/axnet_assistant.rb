require 'axial/addon'
require 'axial/mask_utils'
require 'axial/irc_types/nick'
require 'axial/axnet/assistance_request'
require 'axial/axnet/assistance_response'
require 'yaml'

module Axial
  module Addons
    class AxnetAssistant < Axial::Addon
      def initialize(bot)
        super

        @name                             = 'axnet assistant'
        @author                           = 'sylence <sylence@sylence.org>'
        @version                          = '1.1.0'

        @request_timer                    = nil
        @requests                         = {}
        @request_transmit_count           = 0
        @last_request                     = Time.now

        on_startup                        :start_request_timer
        on_startup                        :check_initial_requests
        on_reload                         :start_request_timer
        on_reload                         :check_initial_requests

        on_axnet    'ASSISTANCE_REQUEST', :handle_assistance_request
        on_axnet   'ASSISTANCE_RESPONSE', :handle_assistance_response

        on_banned_from_channel            :request_unban
        on_channel_invite_only            :request_invite
        on_channel_full                   :request_limit_increase
        on_channel_keyword                :request_keyword

        on_mode :deops,                   :create_op_request
        on_mode :ops,                     :cancel_op_request

        on_self_join                      :create_op_request
        on_self_join                      :clear_pending_join_requests

        on_self_part                      :clear_channel_after_part

        on_invite                         :handle_invite
      end

      def check_initial_requests()
        server.retry_joins
        channel_list.all_channels.each do |channel|
          if (!channel.opped?)
            create_op_request(channel)
          end
        end
      end

      def get_channel_name(channel_or_name)
        key = channel_or_name.is_a?(IRCTypes::Channel) ? channel_or_name.name.downcase : channel_or_name.downcase
        return key
      end

      def clear_channel_after_part(channel)
        key = get_channel_name(channel)
        @requests.delete(key)

        reset_request_count
      end

      def reset_request_count()
        @request_transmit_count = 0
        @request_timer&.interval = 3 ** @request_transmit_count
      end

      def cancel_request(channel, request_type)
        key = get_channel_name(channel)
        @requests.dig(key)&.delete(request_type)

        reset_request_count
      end

      def queue_request(channel, request_type)
        key = get_channel_name(channel)

        if (!@requests.key?(key))
          @requests[key] = [ request_type ]
        elsif (!@requests[key].include?(request_type))
          @requests[key].push(request_type)
          request(key, request_type)
        end

        reset_request_count
      end

      def request(channel, request_type)
        channel_name = get_channel_name(channel)

        if (myself.uhost.empty?)
          LOGGER.warn('cannot dispatch assistance request, bot uhost is unknown')
        else
          bot_nick = IRCTypes::Nick.new(nil)
          bot_nick.uhost = myself.uhost
          request = Axnet::AssistanceRequest.new(bot_nick, channel_name, request_type)
          send_request(request)
        end
      end

      def clear_pending_join_requests(channel)
        cancel_request(channel, :keyword)
        cancel_request(channel, :full)
        cancel_request(channel, :invite)
        cancel_request(channel, :banned)

        reset_request_count
      end

      # Queues an axnet assistance request for the bot to be opped by any available peers.
      # @param channel [String] url to preview
      # @param _nick [IRCTypes::Nick] unused, in method signature to allow response to channel_mode event
      # @param mode [IRCTypes::Mode] channel modes from an on_mode event, nil when invoked by self_join event
      def create_op_request(channel, _nick = nil, mode = nil)
        deopped_self = (mode.nil? || mode.deops.select { |deop| deop.casecmp(myself.name).zero? }.any?)

        if (!deopped_self)
          return
        end

        queue_request(channel, :op)
      end

      def cancel_op_request(channel, _nick, mode)
        if (mode.ops.select { |op| op.casecmp(myself.name).zero? }.empty?)
          return
        end

        cancel_request(channel, :op)
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
        LOGGER.debug("invited to join #{channel_name} by #{nick.uhost}")
        if (!server.trying_to_join.key?(channel_name.downcase))
          return
        end

        server.join_channel(channel_name)
      end

      def check_for_requests()
        if (@requests.empty?)
          return
        end

        @requests.each do |channel_name, pending_requests|
          pending_requests.each do |pending_request|
            request(channel_name, pending_request)
          end
        end

        if (@request_transmit_count >= 5)
          @request_transmit_count = 0
        else
          @request_transmit_count += 1
        end

        # adjust interval by 3 to the power of transmit count for variable frequency
        @request_timer.interval = 3 ** @request_transmit_count
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_assistance_request(handler, command) # rubocop:disable Metrics/MethodLength
        request_yaml_raw  = command.args
        request_yaml      = request_yaml_raw.tr("\0", "\n")

        if (axnet.master?)
          axnet.relay(handler, 'ASSISTANCE_REQUEST ' + request_yaml_raw)
        end

        safe_classes  = [
            Axnet::AssistanceRequest,
            IRCTypes::Nick,
            Symbol
        ]
        request       = YAML.safe_load(request_yaml, safe_classes, [], true)

        channel_name  = request.channel_name
        bot_nick      = request.bot_nick

        case request.type
          when :op
            handle_op_request(channel_name, bot_nick)
          when :invite
            handle_invite_request(channel_name, bot_nick)
          when :full
            handle_full_request(channel_name, bot_nick)
          when :keyword
            handle_keyword_request(channel_name, bot_nick)
          when :banned
            handle_banned_request(channel_name, bot_nick)
        end
      end

      def handle_invite_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)
        if (!channel&.opped?)
          return
        end

        channel.invite(bot_nick.name)
      end

      def handle_assistance_response(handler, command)
        response_yaml_raw = command.args
        response_yaml     = response_yaml_raw.tr("\0", "\n")

        if (axnet.master?)
          axnet.relay(handler, 'ASSISTANCE_RESPONSE ' + response_yaml_raw)
        end

        safe_classes    = [
            Axnet::AssistanceResponse,
            IRCTypes::Nick,
            Symbol
        ]
        response        = YAML.safe_load(response_yaml, safe_classes, [], true)

        case response.type
          when :keyword
            handle_keyword_response(response.channel_name, response.response)
          else
            LOGGER.warn("unknown axnet assistance response: #{response.inspect}")
        end
      end

      def handle_keyword_response(channel_name, keyword)
        if (!server.trying_to_join.key?(channel_name.downcase))
          return
        end

        server.trying_to_join[channel_name.downcase] = keyword
      end

      def handle_banned_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)
        if (!channel&.opped?)
          return
        end

        response_mode = IRCTypes::Mode.new(server)
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

      def handle_keyword_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)
        if (!channel&.mode&.keyword?)
          return
        end

        response = Axnet::AssistanceResponse.new(channel.name, :keyword, channel.mode.keyword)
        send_response(response)
      end

      def handle_full_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)
        if (!channel&.opped? || !channel&.mode&.limit?)
          return
        end

        response_mode = IRCTypes::Mode.new(server)
        response_mode.limit = channel.nick_list.count + 1
        channel.set_mode(response_mode)
        channel.invite(bot_nick.name)
      end

      def handle_op_request(channel_name, bot_nick)
        channel = channel_list.get_silent(channel_name)
        if (!channel&.synced? || !channel&.opped?)
          return
        end

        channel_nick = channel.nick_list.get_silent(bot_nick)
        if (channel_nick.nil?)
          return
        end

        wait_a_sec

        if (channel_nick.opped_on?(channel))
          return
        end

        channel.op(channel_nick)
      end

      def send_request(request)
        LOGGER.debug("sending assistance request: #{request.type}, #{request.channel_name}, #{request.bot_nick.uhost}")
        serialized_yaml = YAML.dump(request).tr("\n", "\0")
        axnet.send('ASSISTANCE_REQUEST ' + serialized_yaml)
      end

      def send_response(response)
        LOGGER.debug("sending asssistance response: #{response.type}, #{response.channel_name}, #{response.response}")
        serialized_yaml = YAML.dump(response).tr("\n", "\0")
        axnet.send('ASSISTANCE_RESPONSE ' + serialized_yaml)
      end

      def stop_request_timer()
        LOGGER.debug('stopping request timer')
        timer.delete(@request_timer)
      end

      def start_request_timer()
        LOGGER.debug('starting request timer')
        timer.get_from_callback_method(:check_for_requests).each do |tmp_timer|
          LOGGER.debug("removing previous request timer #{tmp_timer.callback_method}")
          timer.delete(tmp_timer)
        end
        @request_timer = timer.every_second(self, :check_for_requests)
      end

      def bot_or_director?(user)
        return (!user.nil? && (user.role.bot? || user.role.director?))
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping request timer")
        stop_request_timer
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}", __FILE__, __LINE__)
        end
      end
    end
  end
end
