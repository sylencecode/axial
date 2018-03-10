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
          if (Models::Nick.exists?(nick))
            nick_model = Models::Nick[nick: nick.name.downcase]
            if (nick_model.match_mask?(nick.uhost))
              # this needs to get a lot smarter about setting modes...somehow needs to consolidate pending modes into one transaction
              channel.op(nick)
            end
          end
        rescue Exception => ex
          channel.message("AutoOp error: #{ex.class}: #{ex.message}")
          log "AutoOp error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end
    end
  end
end
