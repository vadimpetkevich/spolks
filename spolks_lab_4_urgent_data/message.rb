class SendException < Exception
  attr_reader :destination_id

  def initialize destination_id, message
    @destination_id = destination_id
    super message
  end
end
class SendPackageException < SendException
  attr_reader :package_number

  def initialize package_number, destination_id, message
    @package_number = package_number
    super(destination_id, message)
  end
end
class SendMessageException < SendException
  attr_reader :message_number

  def initialize message_number, destination_id, message
    @message_number = message_number
    super(destination_id, message)
  end
end
class SendFileException < SendException
  attr_reader :file_name

  def initialize file_name, destination_id, message
    @file_name = file_name
    super(destination_id, message)
  end
end

class BrokenException < Exception
  attr_reader :sender_id

  def initialize sender_id, message
    @sender_id = sender_id
    super message
  end
end
class BrokenPackageException < BrokenException
end
class BrokenMessageException < BrokenException
end
class BrokenFileException < BrokenException
end

class TimeoutException < Exception
  attr_reader :host_ip

  def initialize host_ip, message
    @host_ip = host_ip
    super message
  end
end
class HandlerDisconnectException < Exception
  attr_reader :host_ip

  def initialize host_ip, message
    @host_ip = host_ip
    super message
  end
end

class Package
  MAX_DATA_LENGTH = 8192
  DATA_LENGTH_LENGTH = MAX_DATA_LENGTH.to_s.length

  attr_reader :content

  def initialize data
    data = data[0...MAX_DATA_LENGTH]
    @content = data.length.to_s.ljust(DATA_LENGTH_LENGTH) + data
  end
  def empty?
    @content.length == DATA_LENGTH_LENGTH ? true : false
  end
  def get_data
    @content[DATA_LENGTH_LENGTH..-1]
  end
  # Exceptions: SendPackageException
  def send s, s_addrinfo
    begin
      s.write @content
      if Random.rand(0..4) == 0
        puts '!'
        s.send('!', Socket::MSG_OOB)
      end
    rescue Exception => ex
      raise SendPackageException.new(self.object_id, s_addrinfo.ip_address, ex.message)
    end
  end
  # Exceptions: HandlerDisconnectException, TimeoutException, BrockenPackageException
  # => String
  def self.receive s, s_addrinfo, package_wait_time
    data_length = ''
    while data_length.length < Package::DATA_LENGTH_LENGTH
      ready = IO.select([s], nil, [s], package_wait_time)
      raise TimeoutException.new(s_addrinfo.ip_address, 'package_wait_time wasted') if ready.nil?

      unless ready[2].empty?
        puts s.recv(1, Socket::MSG_OOB)
      else
        receive_data = s.recvfrom(DATA_LENGTH_LENGTH - data_length.length)
        if receive_data[0].length == 0
          raise HandlerDisconnectException.new(s_addrinfo.ip_address, 'recvfrom returned 0 bytes')
        end

        data_length << receive_data[0]
      end
    end

    begin
      data_length = Integer(data_length)
    rescue ArgumentError => ex
      raise BrokenPackageException.new(s_addrinfo.ip_address, ex.message)
    end

    data = ''
    while data.length < data_length do
      ready = IO.select([s], nil, nil, package_wait_time)
      raise TimeoutException.new(s_addrinfo.ip_address, 'package_wait_time wasted') if ready.nil?

      receive_data = s.recvfrom(data_length - data.length)
      if receive_data[0].length == 0
          raise HandlerDisconnectException.new(s_addrinfo.ip_address, 'recvfrom returned 0 bytes')
        end

      data << receive_data[0]
    end
    data
  end
end
class Message
  MAX_DATA_LENGTH = 1_073_741_824 # 1Gb
  PACKAGE_COUNT_LENGTH = ((MAX_DATA_LENGTH/Package::MAX_DATA_LENGTH) + 1).to_s.length

  attr_reader :content

  def initialize data
    data = data[0...MAX_DATA_LENGTH]

    @content = []
    begin
      package = Package.new( data.slice!(0...Package::MAX_DATA_LENGTH) )
      @content << package
    end until(data.length == 0)
    @content.unshift(@content.length.to_s.ljust PACKAGE_COUNT_LENGTH)
  end
  def empty?
    @content[1].empty?
  end
  def get_data
    data = ''
    @content.each_with_index {|e, i| data << e.get_data if i > 0}
    return data
  end
  # Exceptions: SendMessageException
  def send s, s_addrinfo
    @content.each_with_index do |e, i|
      begin
        if i > 0
          e.send s, s_addrinfo
        else
          s.write e
        end
      rescue SendPackageException => ex
        raise SendMessageException.new(self.object_id, ex.destination_id, ex.message)
      rescue Exception => ex
        raise SendMessageException.new(self.object_id, s_addrinfo.ip_address, ex.message)
      end
    end
  end
  # Exceptions: HandlerDisconnectException, BrokenMessageException, TimeoutException
  # => String
  def self.receive s, s_addrinfo, message_wait_time, package_wait_time
    package_count = ''
    while package_count.length < Message::PACKAGE_COUNT_LENGTH
      ready = IO.select([s], nil, nil, message_wait_time)
      raise TimeoutException.new(s_addrinfo.ip_address, 'message_wait_time wasted') if ready.nil?

      receive_data = s.recvfrom(PACKAGE_COUNT_LENGTH - package_count.length)
      if receive_data[0].length == 0
        raise HandlerDisconnectException.new(s_addrinfo.ip_address, 'recvfrom returned 0 bytes')
      end

      package_count << receive_data[0]
    end

    begin
      package_count = Integer(package_count)
    rescue ArgumentError => ex
      raise BrokenMessageException.new(s_addrinfo.ip_address, ex.message)
    end

    data = ''
    begin
      package_count.times() do
        data << Package.receive(s, s_addrinfo, package_wait_time)
      end
    rescue BrokenPackageException => ex
      raise BrokenMessageException.new(ex.sender_id, ex.message)
    end

    data
  end
end

class TFile < Message
  attr_reader :file_name

  def initialize file_name, data
    @file_name = file_name
    super(data)
  end
  # Exceptions: SendFileException
  def send s, s_addrinfo
    @content.each_with_index do |e, i|
      begin
        if i > 0
          e.send s, s_addrinfo
          puts 'Sent '.blue + e.get_data.length.to_s + ' bytes'
          sleep(0.5)
        else
          s.write e
        end
      rescue SendPackageException => ex
        raise SendFileException.new(@file_name, s_addrinfo.ip_address, ex.message)
      rescue Exception => ex
        raise SendFileException.new(@file_name, s_addrinfo.ip_address, ex.message)
      end
    end
  end
  # Exceptions: HandlerDisconnectException, BrokenFileException, TimeoutException
  # => String
  def self.receive_and_save file_name, s, s_addrinfo, file_wait_time, package_wait_time
    package_count = ''
    while package_count.length < Message::PACKAGE_COUNT_LENGTH
      ready = IO.select([s], nil, nil, file_wait_time)
      raise TimeoutException.new(s_addrinfo.ip_address, 'file_wait_time wasted') if ready.nil?

      receive_data = s.recvfrom(PACKAGE_COUNT_LENGTH - package_count.length)
      if receive_data[0].length == 0
        raise HandlerDisconnectException.new(s_addrinfo.ip_address, 'recvfrom returned 0 bytes')
      end

      package_count << receive_data[0]
    end

    begin
      package_count = Integer(package_count)
    rescue ArgumentError => ex
      raise BrokenFileException.new(s_addrinfo.ip_address, ex.message)
    end

    file = File.new(format('%s%s', 'files/', file_name), 'a')

    begin
      package_count.times() do
        new_data = Package.receive(s, s_addrinfo, package_wait_time)
        puts 'Accepted '.blue + new_data.length.to_s + ' bytes'
        sleep(0.5)
        file.write new_data
      end
    rescue BrokenPackageException => ex
      raise BrokenFileException.new(ex.sender_id, ex.message)
    end
  end
end