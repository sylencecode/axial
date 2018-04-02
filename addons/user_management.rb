require 'axial/addon'
require 'axial/colors'
require 'axial/timespan'
require 'axial/models/user'
require 'axial/models/mask'
require 'axial/models/ban'

module Axial
  module Addons
    class UserManagement < Axial::Addon
      def initialize(bot)
        super

        @name    = 'user management'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'
        @valid_roles = %w(director manager op friend)

        on_channel               'addmask',   :dcc_channel_wrapper, :add_mask
        on_channel               'adduser',   :dcc_channel_wrapper, :add_user
        on_channel    'delmask|deletemask',   :dcc_channel_wrapper, :delete_mask
        on_channel    'deluser|deleteuser',   :dcc_channel_wrapper, :delete_user
        on_channel               'setrole',   :dcc_channel_wrapper, :set_role
        on_channel                   'ban',   :dcc_channel_wrapper, :ban
        on_channel                 'unban',   :dcc_channel_wrapper, :unban

        on_dcc                   'addmask',   :dcc_channel_wrapper, :add_mask
        on_dcc                   'adduser',   :dcc_channel_wrapper, :add_user
        on_dcc        'delmask|deletemask',   :dcc_channel_wrapper, :delete_mask
        on_dcc                   'deluser',   :dcc_channel_wrapper, :delete_user
        on_dcc                   'setrole',   :dcc_channel_wrapper, :set_role
        on_dcc                       'ban',   :dcc_channel_wrapper, :ban
        on_dcc                     'unban',   :dcc_channel_wrapper, :unban

        on_dcc              'banlist|bans',   :dcc_ban_list
        on_dcc            'userlist|users',   :dcc_user_list
        on_dcc                     'whois',   :dcc_whois

        on_reload                             :update_user_list
        on_reload                             :update_ban_list
        on_startup                            :update_user_list
        on_startup                            :update_ban_list
      end

      def delete_mask(source, user, nick, command)
        if (user.nil? || !user.manager?)
          if (source.is_a?(IRCTypes::DCC))
            reply(source, nick, Constants::ACCESS_DENIED)
          end
          return
        end

        if (command.args.strip =~ /(\S+)\s+(\S+)/)
          subject_nickname, subject_mask = Regexp.last_match.captures
        else
          reply(source, nick, "try #{command.command} <nick> <mask>")
          return
        end

        subject_model = Models::User.get_from_nickname(subject_nickname)
        if (subject_model.nil?)
          reply(source, nick, "user '#{subject_nickname}' not found.")
          return
        end

        db_mask = subject_model.masks.select{ |mask| mask.mask.casecmp(subject_mask).zero? }.first
        if (db_mask.nil?)
          reply(source, nick, "#{subject_model.pretty_name} doesn't include mask '#{subject_mask}'.")
        else
          db_mask.destroy
          reply(source, nick, "mask '#{subject_mask}' removed from #{subject_model.pretty_name}.")
          update_user_list
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def add_mask(source, user, nick, command)
        if (user.nil? || !user.manager?)
          if (source.is_a?(IRCTypes::DCC))
            reply(source, nick, Constants::ACCESS_DENIED)
          end
          return
        end

        if (command.args.strip =~ /(\S+)\s+(\S+)/)
          subject_nickname, subject_mask = Regexp.last_match.captures
        else
          reply(source, nick, "try #{command.command} <nick> <mask>")
          return
        end

        subject_model = Models::User.get_from_nickname(subject_nickname)
        if (subject_model.nil?)
          reply(source, nick, "user '#{subject_nickname}' not found.")
          return
        end

        subject_mask = MaskUtils.ensure_wildcard(subject_mask)
        subject_models = Models::Mask.get_users_from_mask(subject_mask)
        if (subject_models.count > 0)
          reply(source, nick, "mask '#{subject_mask}' conflicts with: #{subject_models.collect{ |user| user.pretty_name }.join(', ')}")
          return
        end

        mask_model = Models::Mask.create(mask: subject_mask, user_id: subject_model.id)
        update_user_list
        reply(source, nick, "mask '#{subject_mask}' added to #{subject_model.pretty_name}.")
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def unban(source, user, nick, command)
        if (user.nil? || !user.op?)
          if (source.is_a?(IRCTypes::DCC))
            reply(source, nick, Constants::ACCESS_DENIED)
          end
          return
        end

        if (command.args.strip =~ /(\S+)/)
          mask = Regexp.last_match[1]
        else
          reply(source, nick, "try #{command.command} <mask>")
          return
        end

        mask = MaskUtils.ensure_wildcard(mask)

        bans = ban_list.get_bans_from_mask(mask)
        if (bans.count == 0)
          reply(source, nick, "no bans matching '#{mask}'")
          return
        end

        bans.each do |ban|
          ban_model = Models::Ban[mask: ban.mask]
          if (!ban_model.nil?)
            ban_model.delete
            reply(source, nick, "'#{ban.mask}' removed from banlist.")
          else
            reply(source, nick, "'#{ban.mask}' isn't in the database?")
          end
        end

        update_ban_list
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end


      def ban(source, user, nick, command)
        if (user.nil? || !user.op?)
          if (source.is_a?(IRCTypes::DCC))
            reply(source, nick, Constants::ACCESS_DENIED)
          end
          return
        end


        if (command.args.strip =~ /(\S+)(.*)/)
          mask, reason = Regexp.last_match.captures
        end

        if (mask.nil? || mask.strip.empty?)
          reply(source, nick, "try #{command.command} <mask> <reason>")
          return
        elsif (reason.nil? || reason.strip.empty?)
          reason = 'banned'
        end

        mask = MaskUtils.ensure_wildcard(mask.strip)
        reason = reason.strip

        begin
          bans = ban_list.get_bans_from_mask(mask)
          if (bans.count > 0)
            reply(source, nick, "mask '#{mask}' has already been banned by mask '#{bans.collect{ |ban| ban.mask }.join(', ')}'")
          else
            ban_model = Models::Ban.create(mask: mask, reason: reason, user_id: user.id, set_at: Time.now)
            update_ban_list
            reply(source, nick, "'#{ban_model.mask}' added to banlist.")
          end

          update_ban_list
        rescue Exception => ex
          reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def dcc_whois(dcc, command)
        if (command.args.empty?)
          dcc.message("usage: #{command.command} <username>")
          return
        end

        user_model = Models::User[name: command.args.downcase]
        if (user_model.nil?)
          dcc.message("no user named '#{command.args}' was found.")
          return
        end

        dcc.message("user: #{user_model.pretty_name}")
        dcc.message("role: #{user_model.role}")

        on_channels = {}

        channel_list.all_channels.each do |channel|
          channel.nick_list.all_nicks.each do |nick|
            possible_user = user_list.get_from_nick_object(nick)
            if (!possible_user.nil? && possible_user.id == user_model.id)
              if (!on_channels.has_key?(channel))
                on_channels[channel] = []
              end
              on_channels[channel].push(nick)
            end
          end
        end

        if (dcc.user.op?)
          dcc.message('')
          dcc.message("associated masks:")
          dcc.message('')
          user_model.masks.each do |mask|
            dcc.message("  #{mask.mask}")
          end
        end

        if (on_channels.any?)
          dcc.message('')
          dcc.message("currently active on:")
          dcc.message('')
          on_channels.each do |channel, nicks|
            dcc.message("  #{channel.name} as #{nicks.collect{ |tmp_nick| tmp_nick.name }.join(', ')}")
          end
        else
          dcc.message('')
          dcc.message("last seen #{user_model.seen.status} #{TimeSpan.new(Time.now, user_model.seen.last).approximate_to_s} ago")
        end
      rescue Exception => ex
        dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end


      def dcc_user_list(dcc, command)
        if (!dcc.user.op?)
          dcc.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
          return
        end

        users = []
        pretty_name_length = 0
        role_length = 0
        seen_length = 0
        mask_length = 0

        Models::User.all.each do |user_model|
          user = {}
          user[:pretty_name] = user_model.pretty_name
          if (user[:pretty_name].length > pretty_name_length)
            pretty_name_length = user[:pretty_name].length
          end

          user[:role] = user_model.role
          if (user[:role].length > role_length)
            role_length = user[:role].length
          end

          user[:seen] = TimeSpan.new(Time.now, user_model.seen.last).approximate_to_s + ' ago'
          if (user[:seen].length > seen_length)
            seen_length = user[:seen].length
          end

          user[:masks] = []
          user_model.masks.each do |mask|
            if (mask.mask.length > mask_length)
              mask_length = mask.mask.length
            end
            user[:masks].push(mask.mask)
          end
          users.push(user)
        end

        pretty_name_length += 4
        role_length += 2
        seen_length += 4
        mask_length += 2

        top_bar = "#{Colors.gray}.#{'-' * (pretty_name_length + 2)}.#{'-' * (role_length + 2)}.#{'-' * (seen_length + 2)}.#{'-' * (mask_length + 2)}.#{Colors.reset}"
        middle_bar = "#{Colors.gray}|#{'-' * (pretty_name_length + 2)}+#{'-' * (role_length + 2)}+#{'-' * (seen_length + 2)}+#{'-' * (mask_length + 2)}|#{Colors.reset}"
        bottom_bar = "#{Colors.gray}`#{'-' * (pretty_name_length + 2)}'#{'-' * (role_length + 2)}'#{'-' * (seen_length + 2)}'#{'-' * (mask_length + 2)}'#{Colors.reset}"

        if (users.empty?)
          dcc.message("user list is empty.")
        else
          dcc.message("current user list".center(top_bar.length))
          dcc.message(top_bar)
            dcc.message("#{Colors.gray}|#{Colors.reset} #{Colors.cyan}#{'username'.center(pretty_name_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{Colors.cyan}#{'role'.center(role_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{'last seen'.center(seen_length)} #{Colors.gray}|#{Colors.reset}#{Colors.darkcyan} #{'masks'.center(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
          dcc.message(middle_bar)
          users.select{ |tmp_user| tmp_user[:role].downcase == 'director' }.sort_by{ |tmp_user| tmp_user[:pretty_name] }.each do |user|
            dcc.message("#{Colors.gray}|#{Colors.reset} #{Colors.cyan}#{user[:pretty_name].ljust(pretty_name_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{Colors.blue}#{user[:role].center(role_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{user[:seen].rjust(seen_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{Colors.darkcyan}#{user[:masks].shift.ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
            user[:masks].each do |mask|
              dcc.message("#{Colors.gray}|#{Colors.reset} #{' '.ljust(pretty_name_length)} #{Colors.gray}|#{Colors.reset} #{' '.center(role_length)} #{Colors.gray}|#{Colors.reset} #{' '.rjust(seen_length)} #{Colors.gray}|#{Colors.reset}#{Colors.darkcyan} #{mask.ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
            end
          end
          users.select{ |tmp_user| tmp_user[:role].downcase == 'manager' }.sort_by{ |tmp_user| tmp_user[:pretty_name] }.each do |user|
            dcc.message("#{Colors.gray}|#{Colors.reset} #{Colors.cyan}#{user[:pretty_name].ljust(pretty_name_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{Colors.blue}#{user[:role].center(role_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{user[:seen].rjust(seen_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{Colors.darkcyan}#{user[:masks].shift.ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
            user[:masks].each do |mask|
              dcc.message("#{Colors.gray}|#{Colors.reset} #{' '.ljust(pretty_name_length)} #{Colors.gray}|#{Colors.reset} #{' '.center(role_length)} #{Colors.gray}|#{Colors.reset} #{' '.rjust(seen_length)} #{Colors.gray}|#{Colors.reset}#{Colors.darkcyan} #{mask.ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
            end
          end
          users.select{ |tmp_user| tmp_user[:role].downcase == 'op' }.sort_by{ |tmp_user| tmp_user[:pretty_name] }.each do |user|
            dcc.message("#{Colors.gray}|#{Colors.reset} #{Colors.cyan}#{user[:pretty_name].ljust(pretty_name_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{Colors.blue}#{user[:role].center(role_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{user[:seen].rjust(seen_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{Colors.darkcyan}#{user[:masks].shift.ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
            user[:masks].each do |mask|
              dcc.message("#{Colors.gray}|#{Colors.reset} #{' '.ljust(pretty_name_length)} #{Colors.gray}|#{Colors.reset} #{' '.center(role_length)} #{Colors.gray}|#{Colors.reset} #{' '.rjust(seen_length)} #{Colors.gray}|#{Colors.reset}#{Colors.darkcyan} #{mask.ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
            end
          end
          users.select{ |tmp_user| tmp_user[:role].downcase == 'friend' }.sort_by{ |tmp_user| tmp_user[:pretty_name] }.each do |user|
            dcc.message("#{Colors.gray}|#{Colors.reset} #{Colors.cyan}#{user[:pretty_name].ljust(pretty_name_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{Colors.blue}#{user[:role].center(role_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{user[:seen].rjust(seen_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{Colors.darkcyan}#{user[:masks].shift.ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
            user[:masks].each do |mask|
              dcc.message("#{Colors.gray}|#{Colors.reset} #{' '.ljust(pretty_name_length)} #{Colors.gray}|#{Colors.reset} #{' '.center(role_length)} #{Colors.gray}|#{Colors.reset} #{' '.rjust(seen_length)} #{Colors.gray}|#{Colors.reset}#{Colors.darkcyan} #{mask.ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
            end
          end
          dcc.message(bottom_bar)
        end
      rescue Exception => ex
        dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dcc_ban_list(dcc, command)
        if (!dcc.user.op?)
          dcc.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
          return
        end

        bans = []
        mask_length = 0
        set_at_length = 0
        set_by_length = 0
        reason_length = 0

        Models::Ban.all.each do |ban_model|
          ban = {}
          ban[:mask] = ban_model.mask
          if (ban[:mask].length > mask_length)
            mask_length = ban[:mask].length
          end

         # ban[:set_at] = ban_model.set_at.utc.strftime("%m/%d/%Y")

          ban[:set_at] = TimeSpan.new(Time.now, ban_model.set_at).approximate_to_s + ' ago'
          if (ban[:set_at].length > set_at_length)
            set_at_length = ban[:set_at].length
          end

          ban[:set_by] = ban_model.user.pretty_name
          if (ban[:set_by].length > set_by_length)
            set_by_length = ban[:set_by].length
          end

          ban[:reason] = ban_model.reason
          if (ban[:reason].length > reason_length)
            reason_length = ban[:reason].length
          end

          bans.push(ban)
        end

        mask_length += 4
        set_at_length += 2
        set_by_length += 4
        reason_length += 2

        top_bar = "#{Colors.gray}.#{'-' * (mask_length + 2)}.#{'-' * (set_at_length + 2)}.#{'-' * (set_by_length + 2)}.#{'-' * (reason_length + 2)}.#{Colors.reset}"
        middle_bar = "#{Colors.gray}|#{'-' * (mask_length + 2)}+#{'-' * (set_at_length + 2)}+#{'-' * (set_by_length + 2)}+#{'-' * (reason_length + 2)}|#{Colors.reset}"
        bottom_bar = "#{Colors.gray}`#{'-' * (mask_length + 2)}'#{'-' * (set_at_length + 2)}'#{'-' * (set_by_length + 2)}'#{'-' * (reason_length + 2)}'#{Colors.reset}"

        if (bans.empty?)
          dcc.message("ban list is empty.")
        else
          dcc.message("current ban list".center(top_bar.length))
          dcc.message(top_bar)
            dcc.message("#{Colors.gray}|#{Colors.reset} #{Colors.blue}#{'mask'.center(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{'created'.center(set_at_length)} #{Colors.gray}|#{Colors.reset} #{Colors.cyan}#{'set by'.center(set_by_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}#{Colors.red} #{'reason'.center(reason_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
          dcc.message(middle_bar)
          bans.each do |ban|
            dcc.message("#{Colors.gray}|#{Colors.reset} #{Colors.blue}#{ban[:mask].ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{ban[:set_at].rjust(set_at_length)} #{Colors.gray}|#{Colors.reset} #{Colors.cyan}#{ban[:set_by].ljust(set_by_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}#{Colors.red} #{ban[:reason].ljust(reason_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}")
          end
          dcc.message(bottom_bar)
        end
      rescue Exception => ex
        dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def reply(source, nick, text)
        if (source.is_a?(IRCTypes::Channel))
          source.message("#{nick.name}: #{text}")
        elsif (source.is_a?(IRCTypes::DCC))
          source.message(text)
        end
      end

      def dcc_channel_wrapper(*args)
        source = args.shift
        if (source.is_a?(IRCTypes::Channel))
          nick = args.shift
          command = args.shift
          method = args.shift
          user = user_list.get_from_nick_object(nick)
        elsif (source.is_a?(IRCTypes::DCC))
          nick = IRCTypes::Nick.new(nil)
          nick.name = source.user.pretty_name
          command = args.shift
          method = args.shift
          user = source.user
        end
        self.send(method, source, user, nick, command)
      end

      def update_user_list()
        new_user_list = Axnet::UserList.new
        Models::User.all.each do |user_model|
          user = Axnet::User.from_model(user_model)
          new_user_list.add(user)
        end
        axnet.update_user_list(new_user_list)
        axnet.broadcast_user_list
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_ban_list()
        new_ban_list = Axnet::BanList.new
        Models::Ban.all.each do |ban_model|
          ban = Axnet::Ban.new(ban_model.mask, ban_model.user.pretty_name, ban_model.reason, ban_model.set_at)
          new_ban_list.add(ban)
        end
        axnet.update_ban_list(new_ban_list)
        axnet.broadcast_ban_list
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def channel_set_role(channel, nick, command)
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil? || !user_model.manager?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end

          if (command.args.strip =~ /(\S+)\s+(\S+)/)
            subject_nickname = Regexp.last_match[1]
            subject_role = Regexp.last_match[2].downcase
          else
            channel.message("#{nick.name}: try ?setrole <user> <#{@valid_roles.join('|')}>")
            return
          end

          if (!@valid_roles.include?(subject_role))
            channel.message("#{nick.name}: roles must be one of: #{@valid_roles.join(', ')}")
            return
          end

          subject_model = Models::User.get_from_nickname(subject_nickname)
          if (subject_model.nil?)
            channel.message("#{nick.name}: user '#{subject_nickname}' not found.")
            return
          end

          if (user_model.id == subject_model.id)
            channel.message("#{nick.name}: sorry, you can't modify yourself.")
            return
          end

          if (subject_role == 'manager' && !user_model.director?) 
            channel.message("#{nick.name}: sorry, only directors can assign new managers.")
            return
          end

          if (subject_role == 'director')
            if (!user_model.director? || user_model.id != 1) 
              channel.message("#{nick.name}: sorry, only #{Models::User[id: 1].pretty_name} can assign new directors.")
              return
            end
          end

          if (subject_model.director? && user_model.id != 1)
            channel.message("#{nick.name}: sorry, only #{Models::User[id: 1].pretty_name} can modify users who are directors.")
            return
          end

          subject_model.update(role: subject_role)
          update_user_list
          channel.message("#{nick.name}: User '#{subject_model.pretty_name}' has been assigned the role of #{subject_role}.")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def channel_add_user(channel, nick, command)
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil? || !user_model.manager?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          if (command.args.strip =~ /(\S+)\s+(\S+)/)
            subject_nickname = Regexp.last_match[1]
            subject_mask = Regexp.last_match[2]
          else
            channel.message("#{nick.name}: try ?adduser <nick> <mask>")
            return
          end

          subject_model = Models::User.get_from_nickname(subject_nickname)
          if (!subject_model.nil?)
            channel.message("#{nick.name}: user #{subject_model.pretty_nick} already exists.")
            return
          end

          subject_mask = MaskUtils.ensure_wildcard(subject_mask)
          subject_models = Models::Mask.get_users_from_mask(subject_mask)
          if (subject_models.count > 0)
            channel.message("#{nick.name}: Mask '#{subject_mask}' conflicts with: #{subject_models.collect{ |user| user.pretty_name }.join(', ')}")
            return
          end

          subject_model = Models::User.create_from_nickname_mask(subject_nickname, subject_mask)
          update_user_list
          channel.message("#{nick.name}: User #{subject_model.pretty_name} created with mask '#{subject_mask}'.")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
