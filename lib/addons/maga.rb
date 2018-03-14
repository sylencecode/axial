#!/usr/bin/env ruby

require 'marky_markov'

module Axial
  module Addons
    class MakeAmericaGreatAgain < Axial::Addon
      def initialize()
        super

        @markov  = MarkyMarkov::Dictionary.new('maga')
        @name    = 'make america great again'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?maga',  :send_maga
        on_channel '?trump', :send_maga
      end

      def send_maga(channel, nick, command)
        begin
          log "MAGA request from #{nick.uhost}"
          msg  = "#{Colors.gray}[#{Colors.red}MAGA!#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkred}#{nick.name}#{Colors.gray}]#{Colors.reset} "
          msg += @markov.generate_4_sentences
          channel.message(msg)
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
