require 'rest-client'
require 'uri'
require 'json'
require_relative '../site_rating.rb'

module WebOfTrust
  module API
    class PublicLinkJSON2
      @@wot_key = "f204e49afeeb0fd892e3a2643ceb1b7ea9e64a5e"
      @@rest_api = "https://api.mywot.com/0.4/public_link_json2"
      @@mappings = {
        "501" => :good_site,
      }
  
      def get_rating(in_uri)
        if (in_uri.kind_of?(String))
          uri = in_uri.strip
          if (uri.empty?)
            raise(ArgumentError, "Empty URI provided to WebOfTrust")
          elsif (!(uri =~ URI::regexp))
            raise(ArgumentError, "Invalid URI provided to WebOfTrust: #{uri}")
          end
        else
          raise(ArgumentError, "Invalid object provided to WebOfTrust: #{in_uri.class}")
        end
  
        site_rating = SiteRating.new
        site_uri = URI::parse(uri)
        site_host = site_uri.host.downcase
        params = Hash.new
        params[:key]             = @@wot_key
        params[:hosts]           = site_host + "/"
  
        rest_endpoint = URI::parse(@@rest_api)
        rest_endpoint.query = URI.encode_www_form(params)
  
        got_rating = false
        response = RestClient.get(rest_endpoint.to_s)
        json = JSON.parse(response)

        if (json.has_key?(site_host))
          site_data = json[site_host]
          if (site_data.has_key?('target'))
            site_rating.domain = site_data['target']
            if (site_data.has_key?('0') && site_data['0'].kind_of?(Array))
              trustworthiness = site_data['0']
              if (trustworthiness.kind_of?(Array))
                site_rating.trustworthiness.rating = trustworthiness[0]
                site_rating.trustworthiness.confidence = trustworthiness[1]
              end
            end
            if (site_data.has_key?('4') && site_data['4'].kind_of?(Array))
              child_safety = site_data['4']
              if (child_safety.kind_of?(Array))
                site_rating.child_safety.rating = child_safety[0]
                site_rating.child_safety.confidence = child_safety[1]
              end
            end
            if (site_data.has_key?('categories') && site_data['categories'].kind_of?(Hash))
              site_data['categories'].each do |category, confidence|
                if (confidence > 10)
                  site_rating.categories.push(category.to_sym)
                end
              end
            end

            if (site_data.has_key?('blacklists') && site_data['blacklists'].kind_of?(Hash))
              site_data['blacklists'].each do |blacklist, confidence|
                if (confidence > 10)
                  site_rating.blacklists.push(blacklist.to_sym)
                end
              end
            end
          end
        end
        return site_rating
      end
    end
  end
end
