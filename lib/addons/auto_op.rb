#!/usr/bin/env ruby

module Axial
  module Addons
    class AutoOp < Axial::Addon
      def initialize()
        super

        @name    = 'auto_op'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_join    :auto_op
      end

      def auto_op(channel, nick)
        begin
          # need to make a sloppy get masks and return a nick thing...
          user_mask = MaskUtils.ensure_wildcard(nick.uhost)
          user = Axial::Models::Mask.get_nick_from_mask(user_mask)
          if (!user.nil?)
            channel.op(nick)
            log "auto-opped #{nick.uhost} in #{channel.name} (user: #{user.pretty_nick})"
          end
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          log "#{self.class} error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end
    end
  end
end
