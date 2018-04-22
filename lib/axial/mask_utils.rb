module Axial
  class MaskError < StandardError
  end

  class MaskUtils
    def self.ensure_wildcard(in_mask) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
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
        ident = '*' + ident
      end
      return "#{nick}!#{ident}@#{host}"
    end

    def self.get_mask_regexp(mask)
      mask = ensure_wildcard(mask)
      return Regexp.new('^' + Regexp.escape(mask).gsub(/\\\*/, '.*').gsub(/\\\?/, '?') + '$')
    end

    def self.masks_overlap?(left_mask, right_mask)
      match = false
      left_mask = ensure_wildcard(left_mask.split('@').last)
      right_mask = ensure_wildcard(right_mask.split('@').last)
      if (masks_match?(left_mask, right_mask))
        match = true
      end
      return match
    end

    def self.masks_match?(left_mask, right_mask)
      left_mask = ensure_wildcard(left_mask)
      left_regexp = get_mask_regexp(left_mask)
      right_mask  = ensure_wildcard(right_mask)
      right_regexp = get_mask_regexp(right_mask)
      match = false
      if (right_regexp.match(left_mask))
        match = true
      elsif (left_regexp.match(right_mask))
        match = true
      end
      return match
    end
  end
end
