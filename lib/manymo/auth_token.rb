module Manymo
	class AuthToken
		def self.get(force = false)
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
end