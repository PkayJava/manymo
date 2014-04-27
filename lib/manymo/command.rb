
module Manymo
  class Command

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
