require 'bcrypt'
require 'axial/addon'
require 'axial/colors'
require 'axial/constants'
require 'axial/timespan'
require 'axial/models/user'
require 'axial/models/mask'
require 'axial/models/ban'

module Axial
  module Addons
    class UserManagement < Axial::Addon
      def initialize(bot)
        super

        @name                                   = 'user management'
        @author                                 = 'sylence <sylence@sylence.org>'
        @version                                = '1.1.0'

        throttle                                3

        @foreign_tables = {
            DB_CONNECTION[:rss_feeds] => { model: Models::RssFeed, set_unknown: true },
            DB_CONNECTION[:things]    => { model: Models::Thing, set_unknown: true },
            DB_CONNECTION[:bans]      => { model: Models::Ban, set_unknown: true },
            DB_CONNECTION[:seens]     => { model: Models::Seen, set_unknown: false },
            DB_CONNECTION[:masks]     => { model: Models::Mask, set_unknown: false }
        }

        load_binds
      end

      def load_binds()
        load_channel_binds
        load_dcc_binds
        load_privmsg_binds
        load_reload_binds
        load_startup_binds
      end

      def load_channel_binds()
        on_channel                   'addmask', :dcc_wrapper, :add_mask
        on_channel                   'adduser', :dcc_wrapper, :add_user
        on_channel        'delmask|deletemask', :dcc_wrapper, :delete_mask
        on_channel        'deluser|deleteuser', :dcc_wrapper, :delete_user
        on_channel                   'setrole', :dcc_wrapper, :set_role
        on_channel                       'ban', :dcc_wrapper, :ban
        on_channel                     'unban', :dcc_wrapper, :unban
        on_channel               'who|whofrom', :dcc_wrapper, :who_from
      end

      def load_dcc_binds()
        on_dcc                 'addmask|+mask', :dcc_wrapper, :add_mask
        on_dcc                 'adduser|+user', :dcc_wrapper, :add_user
        on_dcc      'delmask|deletemask|-mask', :dcc_wrapper, :delete_mask
        on_dcc      'deluser|deleteuser|-user', :dcc_wrapper, :delete_user
        on_dcc                       'setrole', :dcc_wrapper, :set_role
        on_dcc                      'ban|+ban', :dcc_wrapper, :ban
        on_dcc                    'unban|-ban', :dcc_wrapper, :unban
        on_dcc                       'whofrom', :dcc_wrapper, :who_from
        on_dcc       'clearpass|clearpassword', :silent, :dcc_wrapper, :clear_other_user_password
        on_dcc           'setpass|setpassword', :silent, :dcc_wrapper, :set_other_user_password
        on_dcc                          'note', :dcc_wrapper, :set_note

        on_dcc                  'banlist|bans', :dcc_ban_list
        on_dcc                'userlist|users', :dcc_user_list
        on_dcc                         'whois', :dcc_whois
        on_dcc                      'password', :silent, :dcc_wrapper, :set_password
      end

      def load_privmsg_binds()
        on_privmsg             'pass|password', :silent, :dcc_wrapper, :set_password
        on_privmsg       'setpass|setpassword', :silent, :dcc_wrapper, :set_other_user_password
        on_privmsg   'clearpass|clearpassword', :dcc_wrapper, :clear_other_user_password
      end

      def load_reload_binds()
        on_reload                               :update_user_list
        on_reload                               :update_ban_list
      end

      def load_startup_binds()
        on_startup                              :update_user_list
        on_startup                              :update_ban_list
      end

      def who_from(source, user, nick, command)
        subject_mask = command.first_argument
        if (user.nil? || !user.role.manager?)
          dcc_access_denied(source)
        elsif (subject_mask.empty?)
          reply(source, nick, "usage: #{command.command} <mask>")
        else
          possible_user_names = Models::User.get_users_from_overlap(subject_mask).collect(&:pretty_name_with_color).join(', ')
          if (users.any?)
            reply(source, nick, "possible users for '#{subject_mask}': #{possible_user_names}")
          else
            reply(source, nick, "no users matching '#{in_mask}'.")
          end
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def complex_password?(source, nick, password)
        complex_password = false
        if (password.length < 8)
          reply(source, nick, 'password too short. please use at least 8 characters.')
        else
          points = 0

          if (password.scan(/[a-z]/).any?)
            points += 1
          end

          if (password.scan(/[A-Z]/).any?)
            points += 1
          end

          if (password.scan(/[0-9]/).any?)
            points += 1
          end

          special_characters = Regexp.new('[' + Regexp.escape('!@#$%^&*()_+-=[]{}\\|\'",.<>/?;:') + ']')
          if (password.scan(special_characters).any?)
            points += 1
          end

          if (points < 3)
            reply(source, nick, 'password is too simple. please include at least 3 of the 4 following: lowercase letters, uppercase letters, numbers, and/or special characters.')
          else
            complex_password = true
          end
        end
        return complex_password
      end

      def set_note(source, user, nick, command) # rubocop:disable Metrics/AbcSize
        if (user.nil? || !user.role.op?)
          dcc_access_denied(source)
          return
        end

        subject_nickname, note = command.one_plus
        if (subject_nickname.empty?)
          reply(source, nick, "usage: #{command.command} <user> [note]")
          return
        end

        subject_model = Models::User.get_from_nickname(subject_nickname)
        if (!can_modify?(source, user, nick, subject_nickname, subject_model, true, true))
          return
        end

        if (note.empty?)
          reply(source, nick, "note for #{subject_model.pretty_name_with_color}: #{subject_model.note }.")
          return
        end

        subject_model.update(note: note)
        reply(source, nick, "updated note for #{subject_model.pretty_name_with_color}.")
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def clear_other_user_password(source, user, nick, command) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        subject_nickname = command.first_argument
        if (user.nil? || !user.role.director?)
          dcc_access_denied(source)
          return
        end

        subject_model = Models::User.get_from_nickname(subject_nickname)
        if (subject_model.nil?)
          reply(source, nick, "user '#{subject_nickname}' does not exist.")
          return
        end

        if (!can_modify?(source, user, nick, subject_nickname, subject_model))
          return
        end

        if (!subject_model.password_set?)
          reply(source, nick, "#{subject_model.pretty_name_with_color} does not have a password set.")
          return
        end

        subject_model.update(password: '')
        update_user_list
        reply(source, nick, "password for #{subject_model.pretty_name_with_color} cleared. please instruct the user to reset their password as soon as possible.")
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def set_other_user_password(source, user, nick, command) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        if (user.nil? || !user.role.op?)
          dcc_access_denied(source)
          return
        end

        subject_nickname, new_password = command.two_arguments
        if (new_password.empty?)
          reply(source, nick, "usage: #{command.command} <user> <new_password>")
          return
        end

        subject_model = Models::User.get_from_nickname(subject_nickname)
        if (subject_model.nil?)
          reply(source, nick, "user '#{subject_nickname}' does not exist.")
          return
        end

        if (!can_modify?(source, user, nick, subject_nickname, subject_model, true, false))
          dcc_broadcast(Color.red_arrow + user.pretty_name_with_color + " tried to change password for user #{subject_model.pretty_name_with_color}.", :director)
          LOGGER.warn(user.pretty_name + " tried to change password for user #{subject_model.pretty_name_with_color}.")
          return
        end

        if (complex_password?(source, nick, new_password))
          subject_model.set_password(new_password)
          update_user_list
          reply(source, nick, "password for #{subject_model.pretty_name_with_color} changed.")
          dcc_broadcast(Color.blue_arrow + user.pretty_name_with_color + " has changed the password for user #{subject_model.pretty_name_with_color}.", :director)
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def set_initial_user_password(user_model, source, nick, command)
        new_password = command.first_argument
        if (new_password.empty?)
          reply(source, nick, "usage: #{command.command} <new_password>")
          return
        end

        if (!complex_password?(source, nick, new_password))
          return
        end

        user_model.set_password(new_password)
        update_user_list
        reply(source, nick, 'password set.')
        dcc_broadcast(Color.blue_arrow + user.pretty_name_with_color + ' has set an initial password.', :director)
      end

      def set_user_password(user_model, source, nick, command)
        if (!user_model.password?(old_password))
          reply(source, nick, 'old password is incorrect.')
          dcc_broadcast(Color.red_arrow + " failed password change attempt from #{dcc.user.pretty_name_with_color}#{Colors.reset}.", :director)
          return
        end

        if (!complex_password?(source, nick, new_password))
          return
        end

        user_model.set_password(new_password)
        update_user_list
        reply(source, nick, 'password changed.')
        dcc_broadcast(Color.blue_arrow + " #{user.pretty_name_with_color} has changed his/her password.", :director)
      end

      def set_password(source, user, nick, command)
        user_model = Models::User[id: user.id]
        if (user_model.password.nil? || user_model.password.empty?)
          set_initial_user_password(user_model, source, nick, command)
          return
        end

        old_password, new_password = command.two_arguments # rubocop:disable Lint/UselessAssignment
        if (new_password.empty?)
          reply(source, nick, "usage: #{command.command} <old_password> <new_password>")
          return
        end

        set_user_password(user_model, source, nick, command)
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def output_mask_user_conflicts(source, nick, subject_mask, conflicts)
        counter = 0
        conflicts.each do |subject_model, masks|
          counter += 1
          msg  = "mask '#{subject_mask}' conflicts with: " + subject_model.pretty_name_with_color + ' '
          msg += '(' + masks.collect(&:mask).join(', ') + ')'
          reply(source, nick, msg)
          if (counter < 3)
            next
          end

          if (!source.is_a?(IRCTypes::DCC))
            reply(source, nick, "... and #{conflicts.count - 3} more. review the rest via dcc or provide a more specific mask.")
            break
          end
        end
      end

      def get_mask_user_conflicts(subject_mask)
        conflicting_masks = {}
        subject_mask = MaskUtils.ensure_wildcard(subject_mask)
        subject_models = Models::User.get_users_from_mask(subject_mask)

        if (subject_models.any?)
          subject_models.each do |subject_model|
            conflicting_masks[subject_model] = []
            masks = subject_model.get_masks_from_overlap(subject_mask)
            masks.each do |mask|
              conflicting_masks[subject_model].push(mask)
            end
          end
        end
        return conflicting_masks
      end

      def add_user(source, user, nick, command) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        subject_nickname, subject_mask = command.two_arguments
        if (user.nil? || !user.role.op?)
          dcc_access_denied(source)
          return
        end

        if (subject_mask.empty?)
          reply(source, nick, "usage: #{command.command} <username> <mask>")
          return
        end

        subject_model = Models::User.get_from_nickname(subject_nickname)
        if (!subject_model.nil?)
          reply(source, nick, "user #{subject_model.pretty_name_with_color} already exists.")
          return
        end

        conflicts = get_mask_user_conflicts(subject_mask)
        if (conflicts.any?)
          output_mask_user_conflicts(source, nick, subject_mask, conflicts)
        else
          subject_model = Models::User.create_from_nickname_mask(user.pretty_name, subject_nickname, subject_mask)
          update_user_list
          wildcard_mask = MaskUtils.ensure_wildcard(subject_mask)
          reply(source, nick, "user #{subject_model.pretty_name} created with mask '#{wildcard_mask}' and the role of #{Role.basic.name_with_color}.")
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_foreign_tables(subject_model)
        @foreign_tables.each do |table, model_params|
          if (!table.nil?)
            if (model_params[:set_unknown])
              model_params[:model].delete_or_unknown(subject_model.id)
            else
              table.where(user_id: subject_model.id).delete
            end
          end
        end
      end

      # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/MethodLength,Metrics/ParameterLists
      def can_modify?(source, user, nick, subject_nickname, subject_model, can_change_self = false, can_root_change_root = false)
        can_modify = false
        if (subject_model.nil?)
          reply(source, nick, "user '#{subject_nickname}' does not exist.")
        elsif (subject_model.name.casecmp('unknown').zero?)
          reply(source, nick, "the reserved 'unknown' user cannot be modified within the #{Constants::AXIAL_NAME} runtime.")
        elsif (user.id == subject_model.id)
          if (can_change_self)
            can_modify = true
          else
            reply(source, nick, 'you may not modify your own attributes.')
            return
          end
        elsif (subject_model.role.root?)
          if (can_root_change_root)
            can_modify = true
          else
            reply(source, nick, "#{subject_model.role.plural_name_with_color} cannot be modified within the #{Constants::AXIAL_NAME} runtime.")
          end
        elsif (subject_model.role == user.role)
          reply(source, nick, "#{user.role.plural_name_with_color} are not allowed to modify other #{subject_model.role.plural_name}.")
        elsif (user.role < subject_model.role)
          reply(source, nick, "#{user.role.plural_name_with_color} are not allowed to modify #{subject_model.role.plural_name}.")
        else
          can_modify = true
        end

        return can_modify
      end
      # rubocop:enable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/MethodLength,Metrics/ParameterLists

      def db_delete_user(subject_model)
        deleted_user_name = nil
        if (!subject_model.nil?)
          deleted_user_name = subject_model.pretty_name
          subject_model.destroy
          update_user_list
        end
        return deleted_user_name
      end

      def delete_user(source, user, nick, command)
        subject_nickname = command.first_argument
        if (user.nil? || !user.role.op?)
          dcc_access_denied(source)
        elsif (subject_nickname.empty?)
          reply(source, nick, "usage: #{command.command} <username>")
        else
          subject_model = Models::User.get_from_nickname(subject_nickname)
          if (can_modify?(source, user, nick, subject_nickname, subject_model))
            update_foreign_tables(subject_model)
            deleted_user_name = db_delete_user(subject_model)
            reply(source, nick, "user '#{deleted_user_name}' deleted.")
          end
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def db_destroy_collection(collection)
        collection.each(&:destroy)
      end

      # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/MethodLength
      def delete_mask(source, user, nick, command)
        subject_nickname, subject_mask, force_command = command.three_arguments
        if (user.nil? || !user.role.op?)
          dcc_access_denied(source)
          return
        elsif (subject_mask.empty?)
          reply(source, nick, "usage: #{command.command} <username> <mask> [-force]")
          return
        end

        force = (force_command.casecmp('-force').zero?) ? true : false
        subject_mask  = MaskUtils.ensure_wildcard(subject_mask)
        subject_model = Models::User.get_from_nickname(subject_nickname)
        if (subject_model.nil?)
          reply(source, nick, "user '#{subject_nickname}' not found.")
          return
        end

        if (!can_modify?(source, user, nick, subject_nickname, subject_model))
          return
        end

        mask_models = subject_model.get_masks_from_overlap(subject_mask)
        if (mask_models.empty?)
          reply(source, nick, "'#{subject_model.pretty_name}' doesn't include mask '#{subject_mask}'.")
          return
        end

        if (mask_models.count == 1)
          old_mask = mask_models.first.mask
          db_destroy_collection(mask_models)
          update_user_list
          reply(source, nick, "mask '#{old_mask}' removed from #{subject_model.pretty_name_with_color}.")
        elsif (mask_models.count > 1 && !force)
          output_mask_conflicts(source, user, nick, mask_models, subject_mask)
        else
          db_destroy_collection(mask_models)
          update_user_list
          reply(source, nick, "#{mask_models.count} masks matching '#{subject_mask}' were removed from #{subject_model.pretty_name_with_color}.")
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
      # rubocop:enable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/MethodLength

      def add_mask(source, user, nick, command) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        subject_nickname, subject_mask = command.two_arguments
        if (user.nil? || !user.role.op?)
          dcc_access_denied(source)
          return
        end

        if (subject_mask.empty?)
          reply(source, nick, "usage: #{command.command} <username> <mask>")
          return
        end

        subject_mask  = MaskUtils.ensure_wildcard(subject_mask)
        subject_model = Models::User.get_from_nickname(subject_nickname)
        if (subject_model.nil?)
          reply(source, nick, "user '#{subject_nickname}' not found.")
          return
        end

        if (!can_modify?(source, user, nick, subject_nickname, subject_model))
          return
        end

        conflicts = get_mask_user_conflicts(subject_mask)
        if (conflicts.any?)
          output_mask_user_conflicts(source, nick, subject_mask, conflicts)
        else
          Models::Mask.create(mask: subject_mask, user_id: subject_model.id)
          update_user_list
          reply(source, nick, "mask '#{subject_mask}' added to #{subject_model.pretty_name_with_color}.")
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def output_mask_conflicts(source, user, nick, subject_collection, subject_mask)
        if (subject_collection.count > 1)
          reply(source, nick, "provide a more specific mask or use the -force switch to remove all masks overlapping '#{subject_mask}'.")
          return
        end

        counter = 0
        subject_collection.each do |mask_model|
          counter += 1
          reply(source, nick, "mask '#{subject_mask}' overlaps with: #{mask_model.mask})")
          if (counter < 3)
            next
          end

          if (!source.is_a?(IRCTypes::DCC)) # rubocop:disable Style/Next
            reply(source, nick, "... and #{mask_models.count - 3} more. review the rest via dcc or provide a more specific mask.")
            if (user.role.manager?)
              reply(source, nick, "alternatively, use the -force switch to remove all masks overlapping '#{subject_mask}'.")
            end
            break
          end
        end
      end

      def can_unban?(source, user, nick, subject_mask, force) # rubocop:disable Metrics/PerceivedComplexity
        can_unban = false
        possible_bans = Models::Ban.get_bans_from_overlap(subject_mask)
        if (possible_bans.empty?)
          can_unban = true
        else
          restricted_ban_masks = []
          possible_bans.sort_by { |ban| ban.user.role.numeric }.reverse.each do |possible_ban|
            # roles are sorted highest to lowest for this comparison loop
            if (!user.role.root?)
              if (user.role < possible_ban.user.role)
                # example: ops may bans set by other ops but not managers+
                restricted_ban_masks.push(possible_ban.mask)
              end

              # wtf here
            elsif (!force && possible_bans.count > 1)
              restricted_ban_masks.push(possible_ban.mask)
            end
          end
          if (restricted_ban_masks.empty?)
            can_unban = true
          elsif (force)
            reply(source, nick, "cannot force unban of mask '#{subject_mask}' on the following masks due to access controls: #{restricted_ban_masks.join(', ')}. use a more specific mask.")
          else
            reply(source, nick, "unbanning '#{subject_mask}' would remove multiple bans: #{restricted_ban_masks.join(', ')} - either use a more specific mask or apply the -force switch.")
          end
        end
        return can_unban
      end

      def unban(source, user, nick, command) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        subject_mask, force_command = command.two_arguments

        if (user.nil? || !user.role.op?)
          dcc_access_denied(source)
          return
        end

        if (subject_mask.empty?)
          reply(source, nick, "usage: #{command.command} <mask> [-force]")
          return
        end

        force = (force_command.casecmp('-force').zero?) ? true : false

        subject_mask = MaskUtils.ensure_wildcard(subject_mask)
        ban_models   = Models::Ban.get_bans_from_overlap(subject_mask)
        if (ban_models.empty?)
          reply(source, nick, "no bans found matching '#{subject_mask}'.")
          return
        end

        if (!can_unban?(source, user, nick, subject_mask, force))
          return
        end

        db_destroy_collection(ban_models)
        update_ban_list
        if (ban_models.count == 1)
          reply(source, nick, "mask '#{ban_models.first.mask}' removed from ban list.")
        else
          msg  = ban_models.count + ' bans matching ' + subject_mask + ' were removed from ban list: '
          msg += ban_models.collect(&mask).join(', ')
          reply(source, nick, msg)
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def can_ban?(source, user, nick, subject_mask, force) # rubocop:disable Metrics/PerceivedComplexity,Metrics/MethodLength
        can_ban = false
        if (myself.match_mask?(subject_mask))
          reply(source, nick, "please don't ask me to ban myself.")
          return false
        end

        possible_users = Models::User.get_users_from_overlap(subject_mask)
        if (possible_users.empty?)
          can_ban = true
        else
          protected_user_names = []
          possible_users.sort_by { |tmp_user| tmp_user.role.numeric }.reverse.each do |possible_user|
            # roles are sorted highest to lowest for this comparison loop
            if (!user.role.root?)
              if (user.role <= possible_user.role)
                # example: ops cannot ban other ops, but managers+ can
                protected_user_names.push(possible_user.pretty_name_with_color)
              end
            elsif (!force)
              protected_user_names.push(possible_user.pretty_name_with_color)
            end
          end
          if (protected_user_names.empty?)
            can_ban = true
          elsif (force)
            reply(source, nick, "forcing a ban of mask '#{subject_mask}' would still ban protected users: #{protected_user_names.join(', ')}. use a more specific mask.")
          else
            reply(source, nick, "mask '#{subject_mask}' would ban users: #{protected_user_names.join(', ')} - either use a more specific mask or apply the -force switch.")
          end
        end
        return can_ban
      end

      # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/MethodLength
      def ban(source, user, nick, command)
        force = false
        subject_mask, reason = command.one_plus
        if (user.nil? || !user.role.op?)
          dcc_access_denied(source)
          return
        end

        if (subject_mask.empty?)
          reply(source, nick, "usage: #{command.command} <mask> <reason> [-force]")
          return
        end

        if (reason.empty?)
          reason = 'banned.'
        elsif (reason.casecmp('-force').zero?)
          reason = 'banned.'
          force  = true
        elsif (reason =~ / -force$/i)
          reason.gsub(/ -force$/i, '')
          force = true
        end

        subject_mask = MaskUtils.ensure_wildcard(subject_mask)
        ban_models   = Models::Ban.get_bans_from_overlap(subject_mask)

        if (!can_ban?(source, user, nick, subject_mask, force))
          return
        end

        # purposely looping twice here so that the user is not notified if the ban creation fails
        if (ban_models.any?)
          db_destroy_collection(ban_models)
        end

        ban_model = Models::Ban.create(mask: subject_mask, reason: reason, user_id: user.id, set_at: Time.now)
        update_ban_list

        if (ban_models.any?)
          reply(source, nick, "#{ban_models.count} bans matching '#{subject_mask}' were replaced by '#{ban_mask.mask}'.")
        else
          reply(source, nick, "ban '#{ban_model.mask}' added to ban list.")
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
      # rubocop:enable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/MethodLength

      def dcc_whois(dcc, command) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity
        subject_nickname = command.first_argument
        if (subject_nickname.empty?)
          dcc.message("usage: #{command.command} <username>")
          return
        end

        user_model = Models::User.get_from_nickname(subject_nickname)
        if (user_model.nil?)
          dcc.message("no user named '#{command.args}' was found.")
          return
        end

        dcc.message("user: #{user_model.pretty_name}")
        dcc.message("role: #{user_model.role.name_with_color}")
        dcc.message("created by #{user_model.created_by} on #{user_model.created.strftime('%A, %B %-d, %Y at %l:%M%p (%Z)').gsub(/\s+/, ' ')}")

        on_channels = {}

        channel_list.all_channels.each do |channel|
          channel.nick_list.all_nicks.reject { |tmp_nick| tmp_nick == myself }.each do |subject_nick|
            possible_user = user_list.get_from_nick_object(subject_nick)
            if (possible_user.nil? || possible_user.id != user_model.id)
              next
            end

            if (!on_channels.key?(channel))
              on_channels[channel] = []
            end
            on_channels[channel].push(subject_nick)
          end
        end

        if (dcc.user.role.op?)
          dcc.message('')
          dcc.message('associated masks:')
          dcc.message('')
          mask_length   = user_model.masks.collect { |mask_model| mask_model.mask.length }.max + 2
          user_model.masks.each do |mask_model|
            dcc.message("  #{mask_model.mask.ljust(mask_length)} - added #{mask_model.created.strftime('%Y-%m-%d %l:%M:%S%p (%Z)').gsub(/\s+/, ' ')}")
          end
        end

        dcc.message('')

        if (on_channels.empty?)
          if (user_model.seen.nil? || user_model.seen.status =~ /^for the first time/i)
            dcc.message('never seen before.')
          else
            dcc.message("last seen #{user_model.seen.status} #{TimeSpan.new(Time.now, user_model.seen.last).approximate_to_s} ago")
          end
        else
          dcc.message('currently active on:')
          dcc.message('')
          on_channels_output = []
          on_channels.each do |channel, nicks|
            nicks.each do |nick|
              if (nick.last_spoke.nil?)
                on_channels_output.push(left: "  #{channel.name} as #{nick.name}", right: '- status unknown')
                next
              elsif (!nick.last_spoke.key?(channel.name) || nick.last_spoke[channel.name][:time].nil?)
                last_spoke = TimeSpan.new(channel.joined_at, Time.now)
                on_channels_output.push(left: "  #{channel.name} as #{nick.name}", right: "- idle since I joined #{last_spoke.approximate_to_s} ago")
              else
                last_spoke = TimeSpan.new(nick.last_spoke[channel.name][:time], Time.now)
                on_channels_output.push(left: "  #{channel.name} as #{nick.name}", right: "- idle for #{last_spoke.approximate_to_s}")
              end
            end
          end

          channel_string_length = on_channels_output.collect { |left_right| left_right[:left].length }.max + 2
          on_channels_output.each do |left_right|
            dcc.message("#{left_right[:left].ljust(channel_string_length)}#{left_right[:right].nil? ? '' : ' ' + left_right[:right]}")
          end
        end

        if (!user_model.note.nil? && !user_model.note.empty?)
          if (dcc.user.role >= user_model.role)
            dcc.message('')
            dcc.message("note: #{user_model.note}")
          end
        end
      rescue Exception => ex
        dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dcc_user_list(dcc, _command) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity
        if (!dcc.user.role.op?)
          dcc.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
          return
        end

        user_models        = Models::User.all
        users              = []
        pretty_name_length = user_models.collect { |user_model| user_model.pretty_name.length }.max + 2
        created_length     = user_models.collect { |user_model| user_model.created.strftime('%m/%d/%Y').length }.max + 2
        role_length        = user_models.collect { |user_model| user_model.role.name.length }.max + 2

        note_length = user_models.collect do |user_model|
          if (user_model.note.nil?)
            0
          else
            user_model.note.length
          end
        end.max

        seen_length = 0

        user_models.each do |user_model| # rubocop:disable Metrics/BlockLength
          if (user_model.name == 'unknown')
            next
          end

          user = {}

          user[:created]     = user_model.created.strftime('%m/%d/%Y')
          user[:pretty_name] = user_model.pretty_name
          user[:role]        = user_model.role.name
          user[:role_color]  = user_model.role.color

          if (user_model.note.nil?) # rubocop:disable Style/ConditionalAssignment
            user[:note] = ''
          elsif (dcc.user.role < user_model.role)
            user[:note] = ''
          else
            user[:note] = user_model.note
          end

          on_channels = {}

          channel_list.all_channels.each do |channel|
            channel.nick_list.all_nicks.reject { |tmp_nick| tmp_nick == myself }.each do |subject_nick|
              possible_user = user_list.get_from_nick_object(subject_nick)
              if (possible_user.nil? || possible_user.id != user_model.id)
                next
              end

              if (!on_channels.key?(channel))
                on_channels[channel] = []
              end
              on_channels[channel].push(subject_nick)
            end
          end

          if (on_channels.any?) # rubocop:disable Style/ConditionalAssignment
            user[:seen] = "active (#{on_channels.keys.collect(&:name).join(', ')})"
          elsif (user_model.seen.nil?)
            user[:seen] = 'never'
          elsif (user_model.seen.status =~ /^for the first time/i)
            user[:seen] = 'never'
          else
            user[:seen] = TimeSpan.new(Time.now, user_model.seen.last).approximate_to_s + ' ago'
          end

          if (user[:seen].length > seen_length)
            seen_length = user[:seen].length
          end

          users.push(user)
        end

        seen_length = (seen_length < 8) ? 8 : seen_length + 2
        note_length = (note_length < 8) ? 8 : note_length + 2

        top_bar    = "#{Colors.gray}.#{'-' * (pretty_name_length + 2)}.#{'-' * (role_length + 2)}.#{'-' * (created_length + 2)}.#{'-' * (seen_length + 2)}.#{'-' * (note_length + 2)}.#{Colors.reset}"
        middle_bar = "#{Colors.gray}|#{'-' * (pretty_name_length + 2)}+#{'-' * (role_length + 2)}+#{'-' * (created_length + 2)}+#{'-' * (seen_length + 2)}+#{'-' * (note_length + 2)}|#{Colors.reset}"
        bottom_bar = "#{Colors.gray}`#{'-' * (pretty_name_length + 2)}'#{'-' * (role_length + 2)}'#{'-' * (created_length + 2)}'#{'-' * (seen_length + 2)}'#{'-' * (note_length + 2)}'#{Colors.reset}"

        if (users.empty?)
          dcc.message('user list is empty.')
        else
          dcc.message('current user list'.center(top_bar.length))
          dcc.message(top_bar)
          dcc.message("#{Colors.gray}|#{Colors.reset} #{'username'.center(pretty_name_length)} #{Colors.gray}|#{Colors.reset} #{'role'.center(role_length)} #{Colors.gray}|#{Colors.reset} #{'created'.center(created_length)} #{Colors.gray}|#{Colors.reset} #{'last seen'.center(seen_length)} #{Colors.gray}|#{Colors.reset} #{'notes'.center(note_length)} #{Colors.gray}|#{Colors.reset}")
          dcc.message(middle_bar)
          %w[root director manager op friend basic].each do |role|
            users.select { |tmp_user| tmp_user[:role].downcase == role }.sort_by { |tmp_user| tmp_user[:created] }.each do |user|
              case user[:seen] # rubocop:disable Style/ConditionalAssignment
                when /^active/
                  seen_color = Colors.green
                when 'never'
                  seen_color = Colors.red
                else
                  seen_color = ''
              end
              dcc.message("#{Colors.gray}|#{Colors.reset} #{Colors.cyan}#{user[:pretty_name].ljust(pretty_name_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{user[:role_color]}#{user[:role].center(role_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{user[:created].ljust(created_length)} #{Colors.gray}|#{Colors.reset} #{seen_color}#{user[:seen].rjust(seen_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{user[:note].ljust(note_length)} #{Colors.gray}|#{Colors.reset}")
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

      def dcc_ban_list(dcc, _command) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        if (!dcc.user.role.op?)
          dcc.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
          return
        end

        ban_models    = Models::Ban.all
        set_at_length = ban_models.collect { |ban_model| "#{TimeSpan.new(Time.now, ban_model.set_at).approximate_to_s} ago".length }.max + 2
        mask_length   = ban_models.collect { |ban_model| ban_model.mask.length }.max + 2
        set_by_length = ban_models.collect { |ban_model| ban_model.user.pretty_name.length }.max + 2
        reason_length = ban_models.collect { |ban_model| ban_model.reason.length }.max + 2

        top_bar    = "#{Colors.gray}.#{'-' * (mask_length + 2)}.#{'-' * (set_at_length + 2)}.#{'-' * (set_by_length + 2)}.#{'-' * (reason_length + 2)}.#{Colors.reset}"
        middle_bar = "#{Colors.gray}|#{'-' * (mask_length + 2)}+#{'-' * (set_at_length + 2)}+#{'-' * (set_by_length + 2)}+#{'-' * (reason_length + 2)}|#{Colors.reset}"
        bottom_bar = "#{Colors.gray}`#{'-' * (mask_length + 2)}'#{'-' * (set_at_length + 2)}'#{'-' * (set_by_length + 2)}'#{'-' * (reason_length + 2)}'#{Colors.reset}"

        if (ban_models.empty?)
          dcc.message('ban list is empty.')
        else
          dcc.message('current ban list'.center(top_bar.length))
          dcc.message(top_bar)
          msg  = "#{Colors.gray}|#{Colors.reset} #{Colors.blue}#{'mask'.center(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} "
          msg += "#{'created'.center(set_at_length)} #{Colors.gray}|#{Colors.reset} "
          msg += "#{Colors.cyan}#{'set by'.center(set_by_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} "
          msg += "#{Colors.red}#{'reason'.center(reason_length)}#{Colors.reset} "
          msg += "#{Colors.gray}|#{Colors.reset}"
          dcc.message(msg)
          dcc.message(middle_bar)
          ban_models.each do |ban_model|
            msg  = "#{Colors.gray}|#{Colors.reset} #{Colors.blue}#{ban_model.mask.ljust(mask_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} "
            msg += "#{TimeSpan.new(Time.now, ban_model.set_at).approximate_to_s} ago".rjust(set_at_length) + " #{Colors.gray}|#{Colors.reset} "
            msg += "#{ban_model.user.role.color}#{ban_model.user.pretty_name.ljust(set_by_length)} #{Colors.gray}|#{Colors.reset} "
            msg += "#{Colors.red}#{ban_model.reason.ljust(reason_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset}"
            dcc.message(msg)
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

      def set_role(source, user, nick, command) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        subject_nickname, new_role_name = command.two_arguments
        new_role_name = new_role_name.downcase
        if (user.nil? || !user.role.op?)
          dcc_access_denied(source)
          return
        end

        if (new_role_name.empty?)
          reply(source, nick, "usage: #{command.command} <username> <#{Role.basic.name_with_color}|#{Role.friend.name_with_color}|#{Role.op.name_with_color}|#{Role.manager.name_with_color}|#{Role.director.name_with_color}>")
          return
        end

        new_role = Role.from_possible_name(new_role_name)
        if (new_role.nil?)
          reply(source, nick, "'#{subject_nickname}' is not a valid role name.")
          return
        end

        subject_model = Models::User.get_from_nickname(subject_nickname)
        if (subject_model.nil?)
          reply(source, nick, "user '#{subject_nickname}' not found.")
          return
        end

        if (!can_modify?(source, user, nick, subject_nickname, subject_model))
          return
        end

        if (subject_model.role == new_role)
          reply(source, nick, "#{subject_model.pretty_name} has already been assigned the role of #{subject_model.role.name}.")
        else
          old_role = subject_model.role
          subject_model.update(role_name: new_role.name)
          update_user_list
          reply(source, nick, "user '#{subject_model.pretty_name}' has been assigned the role of #{new_role.name_with_color}. (was: #{old_role.name_with_color})")
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
