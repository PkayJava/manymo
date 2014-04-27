module Manymo
  module ConsoleTunnel
    include EM::Deferrable    
    def initialize(server, tunnel_type, display, password)
      @server = server
      @tunnel_type = tunnel_type
      @display = display
      @password = password
      @connected = false
      @q = []
    end

    def post_init
      #puts "opening ws wss://#{@server}/#{@tunnel_type}?display=#{@display}&password=#{@password}"
      @ws = Faye::WebSocket::Client.new("wss://#{@server}/#{@tunnel_type}?display=#{@display}&password=#{@password}")
      @ws.on :open do
        @connected = true
        flush
      end

      @ws.on :message do |msg|
        #puts "console incoming: #{msg.data}"
        send_data msg.data
      end

      @ws.on :close do |event|
        if event.code == 4008
          self.fail("Authentication failed for console tunnel.")
        elsif event.code != 1000
          self.fail("console tunnel closed with error code #{event.code}.")
        end
        @ws = nil
        close_connection
      end  
    end

    def unbind
      if @ws
        @ws.close
        @ws = nil
      end
    end

    def flush
      if @connected
        @q.each do |msg|
          @ws.send msg.bytes.to_a
        end
        @q = []
      end
    end

    def receive_data(data)
      #puts "console outgoing: #{data.inspect}"
      @q << data
      flush
    end
  end
end

