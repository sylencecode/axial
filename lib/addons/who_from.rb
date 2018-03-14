#!/usr/bin/env ruby

require 'models/mask.rb'
require 'models/nick.rb'

module Axial
  module Addons
    class WhoFrom < Axial::Addon
      def initialize()
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
          nick_model = Models::Nick.get_if_valid(nick)
          if (nick_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          elsif (in_mask.empty?)
            channel.message("#{nick.name}: try ?whofrom <mask> instead of whatever you just did.")
          else
            nicks = Models::Mask.get_nicks_from_mask(in_mask).collect{|nick| nick.pretty_nick}
            log "#{nick.uhost} requested nicks from '#{in_mask}'"
            if (nicks.count > 0)
              nick_string = nicks.join(', ')
              channel.message("#{nick.name}: possible nicks for '#{in_mask}': #{nick_string}")
            else
              channel.message("#{nick.name}: i can't find any nicks matching '#{in_mask}'.")
            end
          end
        rescue Exception => ex
          log "#{self.class} error #{nick.uhost} to #{channel.name}: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end
    end
  end
end
