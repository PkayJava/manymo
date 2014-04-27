module Manymo
  class ADBStream
    attr_accessor :local_id, :remote_id
    attr_accessor :systemtype, :banner
    attr_accessor :window_length, :spoofed_ack_count

    def initialize(local_id, open_data)
      @spoofed_ack_count = 0
      @local_id = local_id
      @system_type, @banner = open_data.split(':')
    end

    def quick_ack
      @spoofed_ack_count += 1
      ADBPacket.build("OKAY", remote_id, local_id)
    end
  end
end
