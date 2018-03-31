module Axial
  class MaskError < StandardError
  end

  class MaskUtils
    @do_not_wildcard = [
      '*.irccloud.com'
    ]

    def self.ensure_wildcard(in_mask)
      mask = in_mask.strip
      if (mask =~ /^(\S+)!(\S+)@(\S+)/)
        nick = Regexp.last_match[1]
        ident = Regexp.last_match[2]
        host = Regexp.last_match[3]
      elsif (mask =~ /^(\S+)@(\S+)/)
        nick = '*'
        ident = Regexp.last_match[1]
        host = Regexp.last_match[2]
      elsif (mask =~ /^@(\S+)/)
        nick = '*'
        ident = '*'
        host = Regexp.last_match[1]
      elsif (mask =~ /(\S+)/)
        nick = '*'
        ident = '*'
        host = Regexp.last_match[1]
      else
        raise(MaskError, "Could not generate a mask for '#{mask}'")
      end

      ident.gsub!(/^~/, '*')
      if (!ident.start_with?('*'))
        ident = "*" + ident
      end
      return "#{nick}!#{ident}@#{host}"
    end

    def self.get_mask_regexp(mask)
      mask = ensure_wildcard(mask)
      return Regexp.new('^' + Regexp.escape(mask).gsub(/\\\*/, '.*').gsub(/\\\?/, '?') + '$')
    end

    def self.get_mask_string_db(mask)
      mask = ensure_wildcard(mask)
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

    def self.masks_match?(left_mask, right_mask)
      left_mask = ensure_wildcard(left_mask)
      left_regexp = get_mask_regexp(left_mask)
      right_mask  = ensure_wildcard(right_mask)
      right_regexp = get_mask_regexp(right_mask)
      match = false
      puts left_regexp.source
      puts right_regexp.source
      if (right_regexp.match(left_mask))
        match = true
      elsif (left_regexp.match(right_mask))
        match = true
      end
      return match
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
