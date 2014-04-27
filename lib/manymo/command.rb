require "optparse"

module Manymo
  class Command
    class <<self
      def start(argv)
        @argv = argv
        @options = {}
        @parser = OptionParser.new do |opts|
          opts.banner = <<EOT
manymo - Manymo Command Line Tool (Version #{Manymo::VERSION})

Full documentation at https://www.manymo.com/pages/documentation/manymo-command-line-tool
 
Usage:

manymo [options] COMMAND [ARGUMENTS]

Commands:
        launch EMULATORNAME          Launch a headless emulator and make it appear like a local device
        list                         List emulators; use the name attribute with the launch command
        shutdown [SERIALNUMBER]      Shutdown specified headless emulator or tunnel, or all if serial number omitted 
        token                        Display a prompt to enter authorization token
        tunnel TUNNELKEY             Make an in-browser emulator appear like a local device

Options:
EOT

          opts.on("--adb-path PATH_TO_ADB", "Specify path to adb executable; otherwise uses the one in your path") do |v|
            @options[:adb_path] = v
          end
        end
        
        begin
          @parser.parse!
        rescue
          usage
          exit
        end

        command = @argv[0]

        @adb = ADB.new(@options[:adb_path])

        @adb.ensure_available

        @service = Service.new

        case command
        when /token/
          get_auth_token(true)
        when /tunnel/
          args = @argv[1].split(':')
          if args.count == 3
            tunnel(*args)
          else
            usage
          end
        when /list/
          list_emulators
        when /launch/
          if @argv[1]
            launch(@argv[1])
          else
            usage
          end
        when /shutdown/
          shutdown(@argv[1])
        when /version/
          puts "Version #{CLIENT_VERSION}"
        else
          usage
        end
      end

      def usage
        puts "#{@parser.banner}#{@parser.summarize.join("\n")}"
      end


      def list_emulators  
        puts @service.get("/emulators")
      end

      def launch(name)
        hostname, emulator_console_port, password = get("/emulators/launch_emulator/#{name}").split(":")
        #puts "Tunnel is #{hostname}:#{emulator_console_port}:#{password}"
        local_port = tunnel(hostname, emulator_console_port, password, true)
        puts "Emulator launched; local serial number is: localhost:#{local_port + 1}"    
      end

      def start_tunnel(server, port, password)
        tunnel = Tunnel.new(server, port, password)
        serial_number = tunnel.start
        if serial_number
          puts "Tunnel established; local serial number is: " unless silent
        else
          STDERR.puts "Error launching tunnel to emulator."
          exit 1
        end
      end
    end
  end
end
