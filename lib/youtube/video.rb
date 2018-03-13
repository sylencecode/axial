require_relative '../duration.rb'

module YouTube
  class Video
    attr_accessor :id, :title, :duration, :view_count, :found, :json, :description, :url
    def initialize()
      @found = false
      @id = "unknown id"
      @title = "unknown title"
      @view_count = 0
      @json = ""
      @duration = Duration.new
      @description = ""
      @url = ""
    end 

    def irc_description()
      short_description = @description.clone
      short_description.strip!
      short_description = short_description
      if (short_description.length > 219)
        short_description = URIUtils.strip_html(short_description)
        short_description = short_description[0..219] + "..."
      end
      return short_description
    end
  end
end
