require "net/https"
require "uri"

module Manymo
  class Service
    HOST= ENV["MANYMO_API_HOST"] || "www.manymo.com"
    BASE_URL="https://#{HOST}/api/v1"
    def get(endpoint)
      auth_token = AuthToken.get
      #puts "Auth token: #{auth_token}"
      uri = URI.parse(BASE_URL + endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      if uri.scheme == 'https'
        http.use_ssl = true
      end
      
      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "OAuth token=#{auth_token}"
      request["Accept"] = "text/plain"
      
      begin
        response = http.request(request)
        if response.code.to_i / 100 == 2
          response.body
        elsif response.code.to_i == 401
          puts "Invalid authorization token."
          AuthToken.get(true)
          get(endpoint)
        else
          STDERR.puts "Error #{response.code}: #{response.body}"
          exit 1
        end
      rescue SystemExit, Interrupt
        exit 1
      rescue Exception => e
        STDERR.puts "Error: #{e.inspect}"
        STDERR.puts "Please check that your network is connected and that no firewall rules are blocking #{uri.scheme} requests."
        exit 1
      end    
    end
  end
end