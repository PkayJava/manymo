require 'eventmachine'

module Manymo
  class ADBConnectionVerifier
    include EM::Deferrable

    module ADBConnection
      def initialize(verifier)
        @verifier = verifier
        @packet = ADBPacket.new
      end

      def post_init
        #puts "Local adb socket opened. Sending CNXN packet."
        send_data ADBPacket.build("CNXN", 0x01000000, 0x00001000, "host::\x00").data
      end

      def receive_data(data)
        #puts "Client receive data!"
        remainder = @packet.consume(data)
        if @packet.complete?
          @verifier.succeed
          close_connection
        end
      end

      def unbind
        #@verifier.fail("Could not connect to adb over tunnel.")
      end
    end

    def initialize(port)
      EM.connect('127.0.0.1', port+1, ADBConnection, self)
    end
  end
end