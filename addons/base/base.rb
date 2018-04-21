require 'axial/addon'
require 'axial/color'

module Axial
  module Addons
    class Base < Axial::Addon
      def initialize(bot)
        super

        @name                   = 'basic public commands'
        @author                 = 'sylence <sylence@sylence.org>'
        @version                = '1.1.0'

        throttle                10

        on_channel    'help',   :channel_send_help
        on_channel   'about',   :send_about
        on_channel  'reload',   :reload_addons
        on_channel_emote        :channel_emote
      end

      def channel_emote(channel, _nick, emote)
        words = emote.split(/\s+/)
        if (words.select { |tmp_word| tmp_word.casecmp(myself.name).zero? }.empty?)
          return
        end

        timer.in_a_tiny_bit do
          channel.emote('ducks')
        end
      end

      def send_about(channel, _nick, _command) # rubocop:disable Metrics/AbcSize
        addon_name_length = @bot.addons.collect { |tmp_addon| tmp_addon[:name].length }.max
        addon_version_length = @bot.addons.collect { |tmp_addon| tmp_addon[:version].to_s.length }.max
        channel.message("#{Constants::AXIAL_LOGO} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (interpreter: ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        channel.message(' ')
        if (@bot.addons.any?)
          @bot.addons.each do |addon|
            channel.message(Color.gray(' + ') + Color.blue(addon[:name].rjust(addon_name_length)) + Color.gray(' | ') + "v#{addon[:version].to_s.rjust(addon_version_length)}" + Color.gray(' | ') + addon[:author])
          end
        else
          channel.message('no addons loaded.')
        end
      end

      def get_command_chunks(commands, max_command_length)
        command_chunks = []

        while (commands.count >= 6)
          chunk = []
          6.times do
            tmp_command = commands.shift.ljust(max_command_length)
            chunk.push(tmp_command)
          end
          command_chunks.push(chunk)
        end

        if (commands.any?)
          command_chunks.push(commands.collect { |tmp_command| tmp_command.ljust(max_command_length) })
        end

        return command_chunks
      end

      def get_names_with_binds() # rubocop:disable Naming/AccessorMethodName, Metrics/AbcSize
        exclude_addons = [ 'axnet assistant', 'axnet master', 'axnet slave', 'base' ]
        selected_addons = @bot.addons.reject { |tmp_addon| exclude_addons.include?(tmp_addon[:name].downcase) }
        names_with_binds = selected_addons.collect { |tmp_addon| { name: tmp_addon[:name], binds: tmp_addon[:object].binds.clone } }

        names_with_binds.each do |name_with_binds|
          name_with_binds[:binds].delete_if { |tmp_bind| tmp_bind[:type] != :channel || !tmp_bind[:command].is_a?(String) }
          name_with_binds[:binds].collect! { |tmp_bind| tmp_bind[:command] }
          name_with_binds[:binds].sort_by! { |tmp_command| tmp_command.gsub(/^\+/, '').gsub(/^-/, '') }
          name_with_binds[:binds].collect! { |tmp_command| @bot.channel_command_character + tmp_command }
        end

        names_with_binds.delete_if { |tmp_bind| tmp_bind[:binds].empty? }
        return names_with_binds
      end

      def print_channel_commands(channel, names_with_binds) # rubocop:disable Metrics/AbcSize
        if (names_with_binds.empty?)
          return
        end

        addon_name_length = names_with_binds.collect { |tmp_bind| tmp_bind[:name].length }.max + 2
        max_command_length = names_with_binds.collect { |tmp_bind| tmp_bind[:binds].collect(&:length).max }.max + 2

        names_with_binds.each do |name_with_binds|
          remaining_chunks = get_command_chunks(name_with_binds[:binds], max_command_length)

          first_chunk = remaining_chunks.shift
          channel.message(Color.blue(name_with_binds[:name].rjust(addon_name_length)) + Color.gray(' | ') + first_chunk.join(Color.gray(' | ')))
          remaining_chunks.each do |tmp_chunk|
            channel.message(' '.ljust(addon_name_length) + Color.gray(' | ') + tmp_chunk.join(Color.gray(' | ')))
          end
        end
      end

      def channel_send_help(channel, _nick, _command)
        channel.message("                    #{Constants::AXIAL_LOGO} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        channel.message(' ')

        if (@bot.addons.empty?)
          channel.message('no addons loaded.')
          return
        end

        names_with_binds = get_names_with_binds

        print_channel_commands(channel, names_with_binds)
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def reload_addons(channel, nick, _command) # rubocop:disable Metrics/AbcSize
        user = user_list.get_from_nick_object(nick)
        if (user.nil? || !user.role.director?)
          return
        end

        if (@bot.addons.empty?)
          channel.message('no addons loaded.')
          return
        end

        LOGGER.info("#{user.pretty_name} reloaded addons.")
        addon_list = @bot.addons.reject { |addon| addon[:name] == 'base' }
        addon_names = addon_list.collect { |addon| addon[:name] }
        channel.message("unloading addons: #{addon_names.join(', ')}")
        @bot.git_pull
        @bot.reload_addons
        addon_list = @bot.addons.reject { |addon| addon[:name] == 'base' }
        addon_names = addon_list.collect { |addon| addon[:name] }
        channel.message("loaded addons: #{addon_names.join(', ')}")
      rescue Exception => ex
        channel.message("addon reload error: #{ex.class}: #{ex.message}")
        LOGGER.error("addon reload error: #{ex.class}: #{ex.message}")
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
