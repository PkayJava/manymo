module Manymo
  class TunnelCloseEvent
    attr_accessor :reason
    attr_accessor :websocket_event

    def initialize(reason)
      @reason = reason
    end

    def normal_closure?
      @reason == :websocket && @websocket_event.code == 1000
    end

    def authorization_denied?
      @reason == :websocket && @websocket_event.code == 4008
    end

    def emulator_terminated?
      @reason == :websocket && @websocket_event.code == 4009
    end
  end

end