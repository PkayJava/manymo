require "net/https"
require "uri"

module Manymo
  module API
    BASE_URL="https://www.manymo.com/api/v1"

    def get_auth_token(force = false)
      manymo_config_dir = File.expand_path('~/.manymo')
      auth_token_path = manymo_config_dir + '/auth_token'
      if ! force and File.exists?(auth_token_path)
        return File.read(auth_token_path)
      else
        print "Please visit https://www.manymo.com/user/client_applications to get your authorization token. Enter it here: "
        STDOUT.flush
        auth_token = STDIN.gets.chomp
        if auth_token.empty?
          STDERR.puts "No token supplied. Exiting."
          exit 1
        else
          begin
            if !File.exists?(manymo_config_dir)
              FileUtils.mkdir(manymo_config_dir)
            end
            File.open(auth_token_path, "w") do |auth_token_path_file_handle|
              auth_token_path_file_handle.write(auth_token)
            end
          rescue Errno::EACCES
            STDERR.puts "Unable to store api token in #{auth_token_path}. You will be prompted again, next time this command is run."
          end
        end
        return auth_token
      end
    end
  end

  def get(endpoint)
    auth_token = get_auth_token
    #puts "Auth token: #{auth_token}"
    uri = URI.parse(API_BASE_URL + endpoint)
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
        get_auth_token(true)
        get(endpoint)
      else
        STDERR.puts "Error #{response.code}: #{response.body}"
        exit 1
      end
    rescue SystemExit
      exit 1
    rescue Exception
      STDERR.puts "Error: #{$!}"
      STDERR.puts "Please check that your network is connected and that no firewall rules are blocking #{uri.scheme} requests."
      exit 1
    end    
  end

end