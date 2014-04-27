require 'eventmachine'
require "socket"
require 'fileutils'
require 'shellwords'

module Manymo
  class Tunnel
    def new(server, port, password, adb)
      @server = server
      @port = port
      @password = password
      @display = (port.to_i - 5554) / 2
      @adb = adb
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
          include Socket::Constants
          socket = Socket.new(AF_INET, SOCK_STREAM, 0)
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
      devices_output.match(/emulator-#{console_port}/)
    end

    def start_tunnels_with_local_port(local_port)
      EventMachine::start_server '0.0.0.0', local_port, 
        ConsoleTunnel, @server, "console_tunnel", display, password
      EventMachine::start_server '0.0.0.0', local_port+1, 
        ADBTunnel, @server, "adb_tunnel", display, password

      # This will start adb server if it isn't started
      listed = is_device_listed?(local_port)

      if !listed
        s = TCPSocket.open('localhost', 5037)
        s.puts("0012host:emulator:#{local_port+1}")
        # Check again
        listed = is_device_listed?(local_port)
      end

      if listed
        "emulator:#{port}"
      end
    end

    def start
      local_port = find_available_local_emulator_port
      if local_port
        begin
          ok = start_tunnels_with_local_port(local_port)
        ensure
          remove_lockfile(local_port)
        end
        return ok
      end
    end
  end
end
