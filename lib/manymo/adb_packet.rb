
module Manymo
  class ADBPacket
    attr_accessor :data

    def initialize(data = "")
      @data = data
    end

    def self.build(cmd, arg0, arg1, body = "")
      # Should be 0x00000232 for a CNXN packet
      new(cmd + [arg0, arg1, body.length, compute_checksum(body), compute_magic(cmd)].pack("V*") + body)
    end

    def self.compute_magic(cmd)
      cmd.unpack("V").first ^ 0xffffffff
    end

    def consume(data)
      @data = @data + data
      remainder = ""
      if @data.length >= 16 && @data.length > data_length
        remainder = @data[data_length..-1]
        @data = @data[0,data_length]
      end
      remainder
    end

    def complete?
      @data.length >= 16 && @data.length == data_length
    end

    def command
      @data[0,4]
    end

    def arg0
      @data[4,4].unpack('V').first
    end

    def arg1
      @data[8,4].unpack('V').first
    end

    def payload_size
      @data[12,4].unpack('V').first
    end

    def checksum
      @data[16,4].unpack('V').first
    end

    def body
      @data[header_size..-1]
    end

    def magic
      @data[20,4].unpack('V').first
    end

    def self.compute_checksum(data)
      # Not really a crc32
      data.bytes.inject{|sum,x| sum + x } || 0
    end

    def computed_checksum
      self.class.compute_checksum(body)
    end

    def header_size
      24
    end

    def data_length
      payload_size + header_size
    end

    def checksum_ok?
      computed_checksum == checksum
    end

    def hex_str(v)
      "0x%08x" % v unless v.nil?
    end

    def to_s
      "#{command}(#{hex_str(arg0)}, #{hex_str(arg1)}), payload_size=#{payload_size}, checksum=#{hex_str(checksum)}, computed_checksum=#{hex_str(computed_checksum)}, magic=#{hex_str(magic)}, body=#{body.inspect}"
    end
  end
end