module Manymo
  module ConsoleTunnel
    def initialize(server, display, password)
      @server = server
      @display = display
      @password = password
      @connected = false
      @q = []
    end

    def onclose(&blk)
      @onclose = blk
    end

    def post_init
      #puts "opening ws wss://#{@server}/console_tunnel?display=#{@display}&password=#{@password}"
      @ws = Faye::WebSocket::Client.new("wss://#{@server}/console_tunnel?display=#{@display}&password=#{@password}")
      @ws.on :open do
        @connected = true
        flush
      end

      @ws.on :message do |msg|
        #puts "console incoming: #{msg.data}"
        send_data msg.data
      end

      @ws.on :close do |event|
        if @onclose
          close_event = TunnelCloseEvent.new(:websocket)
          close_event.websocket_event = event
          @onclose.call(close_event)
          @onclose = nil
        end
        @ws = nil
        close_connection
      end  
    end

    def unbind
      if @onclose
        close_event = TunnelCloseEvent.new(:local)
        @onclose.call(close_event)
        @onclose = nil
      end
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

