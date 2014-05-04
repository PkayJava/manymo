require 'faye'

module Manymo
  module ADBTunnel

    def initialize(server, display, password)      
      #puts "ADBTunnel initialize"
      @server = server
      @display = display
      @password = password
      @connected = false
      @q = []
      @in_packet = ADBPacket.new
      @out_packet = ADBPacket.new
      @out_streams = {}
      @local_port, @local_ip = Socket.unpack_sockaddr_in(get_sockname)
      @peer_port, @peer_ip = Socket.unpack_sockaddr_in(get_peername)
    end

    def onclose(&blk)
      #puts "ADBTunnel onclose"
      @onclose = blk
    end

    def log_packet(prefix, pkt)
      #puts prefix + ": " + pkt.to_s
    end

    # Packet from local socket out to websocket
    def handle_outgoing_packet(p)
      log_packet "#{@peer_port} -> ws", p
      @ws.send p.data.bytes.to_a
      case p.command
      when "OPEN"
        @out_streams[p.arg0] = ADBStream.new(p.arg0, p.body)
      when "WRTE"
        stream = @out_streams[p.arg0]
        if stream
          ack = stream.quick_ack
          log_packet "+ws -> #{@peer_port}", ack
          send_data ack.data
        end
      end
    end

    # Packet from remote websocket to local socket
    def handle_incoming_packet(p)
      should_send = true
      case p.command
      when "CLSE"
        @out_streams.delete p.arg1
      when "OKAY"
        stream = @out_streams[p.arg1]
        if stream 
          if stream.spoofed_ack_count > 0
            stream.spoofed_ack_count -= 1
            should_send = false
            log_packet "-ws -> #{@peer_port}", p
          else
            stream.remote_id = p.arg0
          end
        end
      end
      if should_send
        log_packet "ws -> #{@peer_port}", p
        send_data p.data
      end
    end

    def post_init
      #puts "post_init: opening ws wss://#{@server}/adb_tunnel?display=#{@display}&password=#{@password}"
      @ws = Faye::WebSocket::Client.new("wss://#{@server}/adb_tunnel?display=#{@display}&password=#{@password}", nil, {ping: 10})
      @ws.on :open do
        @connected = true
        flush
      end

      @ws.on :message do |msg|
        data = msg.data.pack('c*')
        remainder = @in_packet.consume(data)
        while @in_packet.complete? do
          handle_incoming_packet(@in_packet)
          @in_packet = ADBPacket.new
          remainder = @in_packet.consume(remainder)
        end
      end

      @ws.on :close do |event|
        #puts "remote adb ws closed connection: #{event.code}"
        if @onclose
          close_event = TunnelCloseEvent.new(:websocket)
          close_event.websocket_event = event
          @onclose.call(close_event)
          @onclose = nil
        end
        close_connection
      end  
    end

    def unbind
      #puts "unbind local adb"
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
        @q.each do |data|
          remainder = @out_packet.consume(data)
          while @out_packet.complete? do
            handle_outgoing_packet(@out_packet)
            @out_packet = ADBPacket.new
            remainder = @out_packet.consume(remainder)
          end
        end
        @q = []
      end
    end

    def receive_data(data)
      #puts "local data: #{data.inspect}"
      @q << data
      flush
    end
  end
end
