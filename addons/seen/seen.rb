require 'axial/addon'
require 'axial/models/user'
require 'axial/models/mask'
require 'axial/timespan'

module Axial
  module IRCTypes
    class Nick
      attr_accessor :last_spoke
    end
  end
end

module Axial
  module Addons
    class Seen < Axial::Addon
      def initialize(bot)
        super

        @name                                 = 'seen/last spoke'
        @author                               = 'sylence <sylence@sylence.org>'
        @version                              = '1.1.0'

        on_channel   'seen|lastspoke|last',   :dcc_wrapper, :seen
        on_dcc       'seen|lastspoke|last',   :dcc_wrapper, :seen
        on_privmsg   'seen|lastspoke|last',   :dcc_wrapper, :seen

        on_who_list_entry                     :populate_last_spoke
        on_channel_any                        :update_last_spoke
        on_join                               :update_seen_join
        on_part                               :update_seen_part
        on_quit                               :update_seen_quit
        on_kick                               :update_seen_kick

        throttle                              3
      end

      def populate_last_spoke(channel, nick)
        if (nick.last_spoke.nil?)
          nick.last_spoke = {}
        elsif (!nick.last_spoke.key?(channel.name))
          nick.last_spoke[channel.name] = {}
        end
      end

      def scan_channels(channels_to_scan, subject_model, subject_nick_name) # rubocop:disable Metrics/AbcSize
        channels_to_scan.each do |channel|
          if (!subject_model.nil?)
            channel.nick_list.all_nicks.reject { |tmp_nick| tmp_nick == myself }.each do |subject_nick|
              # check for nicks associated with a known user
              possible_user = user_list.get_from_nick_object(subject_nick)
              if (possible_user.nil? || possible_user.id != subject_model.id)
                next
              end

              if (!on_channels.key?(channel))
                on_channels[channel] = []
              end
              on_channels[channel].push(subject_nick)
            end
          elsif (channel.nick_list.include?(subject_nick_name))
            seen_nick = channel.nick_list.get(subject_nick_name)
            if (!on_channels.key?(channel))
              on_channels[channel] = []
            end
            on_channels[channel].push(seen_nick)
          end
        end

        return on_channels
      end

      def update_last_spoke(channel, nick, text)
        if (nick.last_spoke.nil?)
          nick.last_spoke = {}
        end
        nick.last_spoke[channel.name] = { time: Time.now, text: text }
      end

      def seen(source, _user, nick, command) # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/MethodLength
        subject_nick_name = command.first_argument
        if (subject_nick_name.empty?)
          reply(source, nick, "usage: #{command.command} <nick>")
          return
        elsif (subject_nick_name.casecmp(nick.name.downcase).zero?)
          reply(source, nick, 'trying to find yourself?')
          return
        elsif (subject_nick_name.casecmp(myself.name.downcase).zero?)
          reply(source, nick, "i'm one handsome guy.")
          return
        end

        channels_to_scan = source.is_a?(IRCTypes::Channel) ? [ source ] : channel_list.all_channels
        subject_model = Models::User[name: subject_nick_name.downcase]

        on_channels = scan_channels(channels_to_scan, subject_model, subject_nick_name)

        if (on_channels.any?)
          seen_name = (subject_model.nil?) ? subject_nick_name : subject_model.pretty_name_with_color

          on_channels.each do |channel, tmp_nicks| # rubocop:disable Metrics/BlockLength
            latest_message = nil
            seen_nick_names = []
            tmp_nicks.each do |tmp_nick|
              seen_nick_names.push(tmp_nick.name)
              if (tmp_nick.last_spoke.nil?)
                tmp_nick.last_spoke = {}
              end
              if (!tmp_nick.last_spoke.key?(channel.name))
                next
              end

              last_spoke = tmp_nick.last_spoke[channel.name][:time]
              if (last_spoke.nil?)
                next
              end

              if (latest_message.nil? || latest_message > last_spoke)
                latest_message = last_spoke
              end
            end

            seen_nick_names.sort!
            same = false
            if (seen_nick_names.count > 2)
              nick_string = ''
              while (seen_nick_names.count > 2)
                nick_string += "'#{seen_nick_names.shift}', "
              end
              nick_string += "'#{seen_nick_names.shift}', and '#{seen_nick_names.shift}'"
            elsif (seen_nick_names.count == 2)
              nick_string = "'#{seen_nick_names.shift}' and '#{seen_nick_names.shift}'"
            else
              if (seen_nick_names.first.casecmp(subject_nick_name).zero?)
                same = true
              end
              nick_string = "'#{seen_nick_names.shift}'"
            end

            if (latest_message.nil?)
              last_spoke = TimeSpan.new(channel.joined_at, Time.now)
              if (same)
                reply(source, nick, "#{seen_name} is in channel #{channel.name} (idle since i joined #{last_spoke.approximate_to_s} ago)")
              else
                reply(source, nick, "#{seen_name} is in channel #{channel.name} as #{nick_string} (idle since i joined #{last_spoke.approximate_to_s} ago)")
              end
            else
              last_spoke = TimeSpan.new(latest_message, Time.now)
              if (same)
                reply(source, nick, "#{seen_name} is in channel #{channel.name} (idle for #{last_spoke.approximate_to_s})")
              else
                reply(source, nick, "#{seen_name} is in channel #{channel.name} as #{nick_string} (idle for #{last_spoke.approximate_to_s})")
              end
            end
          end
        else
          if (subject_model.nil?)
            reply(source, nick, "i don't know anything about #{subject_nick_name}")
            return
          end

          seen_at = TimeSpan.new(subject_model.seen.last, Time.now)
          if (subject_model.seen.status =~ /^for the first time/i)
            reply(source, nick, "i haven't seen #{subject_model.pretty_name_with_color} since his/her account was created #{seen_at.approximate_to_s} ago.")
          else
            reply(source, nick, "#{subject_model.pretty_name_with_color} was last seen #{subject_model.seen.status} #{TimeSpan.new(Time.now, subject_model.seen.last).approximate_to_s} ago")
          end
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_kick(channel, kicker_nick, kicked_nick, reason)
        if (!kicked_nick.last_spoke.nil?)
          kicked_nick.last_spoke.delete(channel.name)
        end
        user = Models::User.get_from_nick_object(kicked_nick)
        if (!user.nil?)
          status = "getting kicked from #{channel.name} by #{kicker_nick.name} (#{reason})"
          Models::Seen.upsert(user, Time.now, status)
          LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_join(channel, nick)
        if (nick.last_spoke.nil?)
          nick.last_spoke = {}
        end
        nick.last_spoke[channel.name] = {}
        user = Models::User.get_from_nick_object(nick)
        if (!user.nil?)
          status = "joining #{channel.name}"
          Models::Seen.upsert(user, Time.now, status)
          LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_part(channel, nick, reason)
        if (!nick.last_spoke.nil?)
          nick.last_spoke.delete(channel.name)
        end

        user = Models::User.get_from_nick_object(nick)
        if (user.nil?)
          return
        end

        status = (reason.empty?) ? "leaving #{channel.name}" : "leaving #{channel.name} (#{reason})"
        Models::Seen.upsert(user, Time.now, status)
        LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_quit(nick, reason)
        user = Models::User.get_from_nick_object(nick)
        if (!user.nil?)
          status = (reason.empty?) ? 'quitting IRC' : "quitting IRC (#{reason})"

          Models::Seen.upsert(user, Time.now, status)
          LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}", __FILE__, __LINE__)
        end
      end
    end
  end
end
