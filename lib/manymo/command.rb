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
            start_tunnel(args[0], args[1], args[2])
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
        when /version/
          puts "Version #{Manymo::VERSION}"
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
          hostname, emulator_console_port, password = @service.get("/emulators/launch_emulator/#{name}").split(":")
          puts "Launched #{hostname}:#{emulator_console_port}:#{password}, connecting..."
          start_tunnel(hostname, emulator_console_port, password)
      end

      def start_tunnel(server, port, password)
        EM.run {
          # hit Control + C to stop
          Signal.trap("INT")  { EventMachine.stop }
          Signal.trap("TERM") { EventMachine.stop }
          EM
          tunnel = Tunnel.new(server, port, password, @adb)

          EM.add_shutdown_hook {
            tunnel.shutdown("Process terminated")
          }
          tunnel.errback{ |message|
            STDERR.puts message
            exit 1
          }
        }
      end
    end
  end
end
