#!/usr/bin/env ruby

require 'marky_markov'

module Axial
  module Addons
    class Trump < Axial::Addon
      def initialize()
        super

        @markov  = MarkyMarkov::Dictionary.new('trump')
        @name    = 'make america great again'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?trump', :send_trump
        on_channel '?maga',  :send_trump
      end

      def send_trump(channel, nick, command)
        begin
          log "trump quote request from #{nick.uhost}"
          msg  = "#{$irc_gray}[#{$irc_magenta}trump#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkmagenta}#{nick.name}#{$irc_gray}]#{$irc_reset} "
          msg += @markov.generate_4_sentences
          channel.message(msg)
        rescue Exception => ex
          channel.message("Trump error: #{ex.class}: #{ex.message}")
          log "Trump error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end
    end
  end
end
