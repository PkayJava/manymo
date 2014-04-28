require 'eventmachine'
require "socket"
require 'fileutils'
require 'shellwords'

module Manymo
  class Tunnel
    include EM::Deferrable
    attr_accessor :serial_number

    def initialize(server, port, password, adb)
      @shutdown = false
      @server = server
      @port = port
      @password = password
      @display = (port.to_i - 5554) / 2
      @adb = adb
      EM::next_tick {
        start
      }
      @adb_tunnels = []
    end

    def lockfile_for_port(port)
      File.expand_path("~/.manymo/.tunnel_#{port}.lock")
    end

    def create_lockfile(port)
      # Raises Errno::EEXIST if lockfile cannot be created
      tunnel_lockfile = lockfile_for_port(port)
      if File.exists?(tunnel_lockfile) && (Time.new - File.mtime(tunnel_lockfile)) > 60
        File.unlink(tunnel_lockfile)
      end
      File.open(tunnel_lockfile, File::WRONLY|File::CREAT|File::EXCL) { |file| file.write $$ }
    end

    def remove_lockfile(port)
      begin
        File.unlink(lockfile_for_port(port))
      rescue Errno::ENOENT
      end
    end

    def find_available_local_emulator_port
      (5554...5754).step(2) do |local_port|
        created_lock = false
        begin
          create_lockfile(local_port)
          created_lock = true
          socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
          socket.bind(Socket.pack_sockaddr_in( local_port, '127.0.0.1' ))
          socket.close
          return local_port
        rescue Errno::EADDRINUSE, Errno::EEXIST
          remove_lockfile(local_port) if created_lock
        end
      end
      nil
    end

    def is_device_listed?(console_port)
      devices_output = `#{@adb.path.shellescape} devices`
      #puts "output #{devices_output}"
      devices_output.match(/emulator-#{console_port}/)
    end

    def start_tunnels_with_local_port(local_port)
      #puts "Starting tunnels for #{local_port}"
      EventMachine::start_server '0.0.0.0', local_port, ConsoleTunnel, @server, @display, @password do |tunnel|
        tunnel.onclose { |event|
          if event.authorization_denied?
            self.fail("Authorization denied for console connection.")
          end
        }
      end
      EventMachine::start_server '0.0.0.0', local_port+1, ADBTunnel, @server, @display, @password do |tunnel|
        @adb_tunnels << tunnel
        tunnel.onclose { |event|
          puts "adb closed: #{event}"
          @adb_tunnels.delete(tunnel)
          if event.authorization_denied?
            shutdown("Authorization denied for adb connection.")
          elsif event.emulator_terminated?
            shutdown("Emulator terminated.")
          elsif @adb_tunnels.empty? && !@shutdown
            # retry
            puts "adb tunnel closed. retrying..."
            connect_emulator_to_adb_server(local_port)
          end
        }
      end
      connect_emulator_to_adb_server(local_port)

      @timeout_timer = EM::Timer.new(50) do 
        shutdown("Timed out attempting to connect to emulator.")
      end
    end

    def connect_emulator_to_adb_server(port)
      connection_verifier = ADBConnectionVerifier.new(port)
      connection_verifier.callback {
        @serial_number = "emulator-#{port}"

        # This will start adb server if it isn't started
        listed = is_device_listed?(port)

        if !listed
          s = TCPSocket.open('localhost', 5037)
          #s.puts("0012host:emulator:#{port+1}")
          # Check again
          listed = is_device_listed?(port)
          listed = true
        end

        if listed
          @timeout_timer.cancel if @timeout_timer
          puts "Tunnel established; local serial number is: " + @serial_number
        else
          shutdown("Error connecting emulator to adb server.")
        end        
      }
      connection_verifier.errback {
        shutdown("Error connecting to emulator emulator.")
      }
    end

    def shutdown(reason)
      @shutdown = true
      self.fail(reason)
    end

    def start
      local_port = find_available_local_emulator_port
      if local_port
        begin
          start_tunnels_with_local_port(local_port)
        ensure
          remove_lockfile(local_port)
        end
      else
        self.fail("Unable to allocate local port in range 5554-5754 for tunnel")
      end
    end
  end
end
