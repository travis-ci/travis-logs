# encoding: binary

# Removes any bytes from a string that are not valid unicode
class StringCleaner
  attr_reader :bytes, :buffer, :outstanding

  def self.clean(str)
    new.tap { |c| c << str }.to_s
  end

  def initialize(str = nil)
    @bytes = []
    clear_buffer
  end

  def <<(input)
    return self << input.bytes          if input.respond_to? :bytes
    return input.each { |b| self << b } if input.respond_to? :each

    case input
    when 001..127 then add(input)
    when 128..191 then fill_buffer(input)
    when 192..223 then start_buffer(input, 2)
    when 224..239 then start_buffer(input, 3)
    when 240..247 then start_buffer(input, 4)
    when 248..251 then start_buffer(input, 5)
    when 252..253 then start_buffer(input, 6)
    else clear_buffer
    end
  end

  def to_s
    bytes.pack('C*').force_encoding('utf-8')
  end

  private

    def clear_buffer
      start_buffer(nil, 0)
    end

    def start_buffer(byte, size)
      @buffer, @outstanding = Array(byte), size
    end

    def fill_buffer(byte)
      buffer << byte
      add(buffer)  if buffer.size == outstanding
      clear_buffer if buffer.size > outstanding
    end

    def add(input)
      clear_buffer
      bytes.concat Array(input)
    end
end
