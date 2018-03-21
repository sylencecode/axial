require 'axial/addon'
require 'axial/models/user'
require 'axial/models/mask'

module Axial
  module Addons
    class WhoFrom < Axial::Addon
      def initialize(bot)
        super

        @name    = 'who from?'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?whofrom', :who_from
        on_channel '?who',     :who_from
      end

      def who_from(channel, nick, command)
        begin
          in_mask = command.args.strip
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          elsif (in_mask.empty?)
            channel.message("#{nick.name}: try ?whofrom <mask> instead of whatever you just did.")
          else
            users = Models::Mask.get_users_from_mask(in_mask).collect{|user| user.pretty_name}
            LOGGER.debug("#{nick.uhost} requested nicks from '#{in_mask}'")
            if (users.count > 0)
              user_string = users.join(', ')
              channel.message("#{nick.name}: possible users for '#{in_mask}': #{user_string}")
            else
              channel.message("#{nick.name}: i can't find an users matching '#{in_mask}'.")
            end
          end
        rescue Exception => ex
          LOGGER.error("#{self.class} error #{nick.uhost} to #{channel.name}: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end
    end
  end
end
