
module Manymo
  class ADB
    attr_accessor :path
    def initialize(path = nil)
      @path = path
    end

    def ensure_available
      if @path
        if !File.exists?(@path)
          STDERR.puts "Specified ADB executable (#{@path}) not found."
          exit 1
        end
      else
        found_adb = false
        begin
          `adb version`
          found_adb = true
        rescue Errno::ENOENT
        end
        if (!found_adb)
          STDERR.puts "Could not find adb. Please install the Android SDK and make sure its platform-tools directory is in your PATH."
          exit 1
        end
      end
    end
  end
end