class String
  def cleanup()
    new_string = self

    # clean up some unicode
    new_string.gsub!(/\u2013/, '-')
    new_string.gsub!(/\u2014/, '--')
    new_string.gsub!(/\u2019/, "'")
    
    # strip other unicode?
#    encoding_options = {
#      :invalid           => :replace,
#      :undef             => :replace,
#      :replace           => '',
#      :universal_newline => true
#    }
#    new_string = new_string.encode(Encoding.find('ASCII'), encoding_options)

    # strip html
    new_string.gsub!(/<li>/, '* ')
    new_string.gsub!(/<\/?[^>]*>/, "")
    new_string.gsub!(/&amp;/, '&')
    new_string.gsub!(/&gt;/, '>')
    new_string.gsub!(/&lt;/, '<')
    # strip newlines and intermediate whitespace
    new_string.gsub!(/\s+/, ' ')
    return new_string
  end
end
