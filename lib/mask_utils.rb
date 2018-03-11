#!/usr/bin/env ruby

module Axial
  class MaskUtils 
    @do_not_wildcard = [
      '*.irccloud.com'
    ]

    def self.get_mask_regexp(mask)
      return Regexp.new('^' + Regexp.escape(mask).gsub(/\\\*/, '.*').gsub(/\\\?/, '?') + '$')
    end

    def self.get_mask_string_db(mask)
      if (mask !~ /^\S+@/)
        mask = "*@" + mask
      end
      if (mask !~ /^\S+!/)
        mask = "*!" + mask
      end
      #return Regexp.new('^' + Regexp.escape(mask).gsub(/\\\*/, '%').gsub(/\\\?/, '%').gsub(/\\\./, '.') + '$')
      return mask.gsub(/\*/, '%').gsub(/\?/, '%')
    end
  
    def self.mask_ipv4(host)
      host_parts = host.split(/\./)
      host_parts.pop
      host = host_parts.join('.') + '.*'
      return host
    end
  
    def self.mask_ipv6(host)
      host_parts = host.split(/:/)
      host_parts.pop
      host = host_parts.join(':') + ':*'
      return host
    end
  
    def self.mask_dns(host)
      host_parts = host.split(/\./)
      if host_parts.count > 2
        host_parts.shift
        host = '*.' + host_parts.join('.')
      end
      return host
    end
  
    def self.gen_wildcard_host(host)
      @do_not_wildcard.each do |domain|
        wc = get_mask_regexp(domain)
        if (wc.match(host))
          return host
        end
      end
  
      if (host =~ /^\d+\.\d+\.\d+\.\d+$/) # ipv4
        return mask_ipv4(host)
      elsif (host =~ /^\S+:.*:.*:.*:.*:.*:.*:\S+$/) # ipv6
        return mask_ipv6(host)
      else # dns
        return mask_dns(host)
      end
    end
  
    def self.strip_ident(ident)
      ident.gsub!(/^~/, '')
      if (ident.empty?)
        ident = '*'
      elsif (ident != '*')
        ident = '*' + ident
      end
      return ident
    end
  
    def self.gen_wildcard_mask(mask)
      if (mask =~ /^(\S+)!(\S+)@(\S+)$/)
        # TODO: mode to decide whether to include the nick in the mask?
        # nick = Regexp.last_match[1]
        nick = '*'
        ident = Regexp.last_match[2]
        host = Regexp.last_match[3]
        ident = strip_ident(ident)
        host = gen_wildcard_host(host)
        return "#{nick}!#{ident}@#{host}"
      else
        raise(RuntimeError, "to do: ensure you're checking for empty masks")
      end
    end
  end
end
