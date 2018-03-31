require 'securerandom'

module Axial
  module IRCTypes
    class Nick
      attr_accessor :name, :ident, :host, :user_model, :last_spoke
      attr_reader   :uuid

      def initialize(server_interface)
        @server_interface     = server_interface
        @name                 = ''
        @ident                = ''
        @host                 = ''
        @user_model           = nil
        @last_spoke           = {}
        @uuid                 = SecureRandom.uuid
        @voiced_channels      = []
        @opped_channels       = []
      end

      def set_opped(channel, toggle_value)
        if (toggle_value)
          if (!opped_on?(channel))
            @opped_channels.push(channel)
          end
        else
          if (opped_on?(channel))
            @opped_channels.delete_if{ |tmp_channel| tmp_channel.name.casecmp(channel.name).zero? }
          end
        end
      end

      def set_voiced(channel, toggle_value)
        if (toggle_value)
          if (!voiced_on?(channel))
            @voiced_channels.push(channel)
          end
        else
          if (voiced_on?(channel))
            @voiced_channels.delete_if{ |tmp_channel| tmp_channel.name.casecmp(channel.name).zero? }
          end
        end
      end

      def opped_on?(channel)
        opped_channels = @opped_channels.select{ |tmp_channel| tmp_channel.name.casecmp(channel.name).zero? }
        return opped_channels.any?
      end

      def voiced_on?(channel)
        voiced_channels = @voiced_channels.select{ |tmp_channel| tmp_channel.name.casecmp(channel.name).zero? }
        return voiced_channels.any?
      end

      def uhost()
        if (@name.empty? || @ident.empty? || @host.empty?)
          return ''
        else
          return "#{@name}!#{@ident}@#{@host}"
        end
      end

      def message(text)
        @server_interface.send_private_message(@name, text)
      end

      def ==(other_nick)
        return (self.uhost == other_nick.uhost)
      end

      def match_mask?(in_mask)
        match = false
        if (MaskUtils.masks_match?(uhost, in_mask))
          match = true
        end
        return match
      end

      def self.from_uhost(server_interface, uhost)
        if (uhost =~ /^(\S+)!(\S+)@(\S+)$/)
          name, ident, host = Regexp.last_match.captures
          nick = new(server_interface)
          nick.name = name
          nick.ident = ident
          nick.host = host
          return nick
        else
          return nil
        end
      end
    end
  end
end
