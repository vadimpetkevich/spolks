require 'zlib'

TimeoutException = Class.new(Exception)
ReceivePackageException = Class.new(Exception)
BrokenPackageException = Class.new(Exception)
SendPackageException = Class.new(Exception)
ConfirmFailedException = Class.new(Exception)
class UnknownConfNumber < Exception
  attr_reader :sender
  def initialize(sender, message)
    @sender = sender
    super(message)
  end
end

class Package
  MAX_DATA_SIZE = 8192
  DATA_LENGTH_LENGTH = MAX_DATA_SIZE.to_s.length
  CONF_NUMBER_LENGTH = 4
  CRC32_LENGTH = (2**32 - 1).to_s.length
  HEADER_LENGTH = DATA_LENGTH_LENGTH + CONF_NUMBER_LENGTH + CRC32_LENGTH
  MAX_PACKAGE_LENGTH = HEADER_LENGTH + MAX_DATA_SIZE
  CONF_TIMEOUT = 1
  REFUSED_COUNT = 20

  attr_reader :content

  def initialize(data, conf_number)
    data = data.to_s[0...MAX_DATA_SIZE]
    conf_number = conf_number.to_i.to_s[0...CONF_NUMBER_LENGTH]
    @content = format(
      '%s%s%s%s',
      data.length.to_s.ljust(DATA_LENGTH_LENGTH),
      conf_number.ljust(CONF_NUMBER_LENGTH),
      Zlib::crc32(data).to_s.ljust(CRC32_LENGTH),
      data
    )
  end
  def empty?
    @content.length == HEADER_LENGTH
  end
  def data_size
    @content.size - HEADER_LENGTH
  end
  def get_data
    @content[HEADER_LENGTH..-1]
  end
  def get_header
    @content[0...HEADER_LENGTH]
  end
  def parse_header
    header = self.get_header
    begin
      header_params = [
        Integer(header.slice!(0...DATA_LENGTH_LENGTH)),
        Integer(header.slice!(0...CONF_NUMBER_LENGTH)),
        Integer(header.slice!(0...CRC32_LENGTH))
      ]
    end
    header_params
  end
  def send(s, need_conf, host, port)
    refused_count = 0
    begin
      s.send(@content, 0, host, port)
    rescue Exception => ex
      refused_count += 1
      unless refused_count > REFUSED_COUNT
        sleep 1
        retry
      end

      raise SendPackageException.new(
        format(
          '%s %s',
          ex.message,
          "more than #{REFUSED_COUNT} times in a row"
        )
      )
    end

    if need_conf
      data_size, conf_number, crc32 = self.parse_header
      begin
        response = Package.receive(s, Package::CONF_TIMEOUT, false)
      rescue Exception => ex
        raise ConfirmFailedException.new(ex.message)
      else
        raise UnknownConfNumber.new(response.last, 'unknown conf_number') unless response.first.to_i == conf_number
      end
    end
  end
  def self.parse_header(header)
    if header.length == Package::HEADER_LENGTH
      header = header.clone
    else
      raise ArgumentError.new('invalid header length')
    end

    [
      Integer(header.slice!(0...DATA_LENGTH_LENGTH)),
      Integer(header.slice!(0...CONF_NUMBER_LENGTH)),
      Integer(header.slice!(0...CRC32_LENGTH))
    ]
  end
  def self.receive(s, package_timeout, need_conf)
    refused_count = 0
    begin
      ready = IO.select([s], nil, nil, package_timeout)
      raise TimeoutException.new('package_timeout wasted') if ready.nil?
      package, sender = s.recvfrom(MAX_PACKAGE_LENGTH)
    rescue TimeoutException => timeout_ex
      raise timeout_ex
    rescue Exception => ex
      refused_count += 1
      unless refused_count > REFUSED_COUNT
        sleep 1
        retry
      end

      raise ReceivePackageException(
        format(
          '%s%s',
          ex.message,
          "more than #{REFUSED_COUNT} times in a row"
        )
      )
    end

    header = package[0...HEADER_LENGTH]
    data = package[HEADER_LENGTH..-1]

    begin
      data_size, conf_number, crc32 = Package.parse_header(header)
    rescue ArgumentError => header_param_broken
      raise BrokenPackageException.new(
        format(
          '%s: %s',
          'Broken header',
          header_param_broken.message
        )
      )
    end

    unless crc32 == Zlib::crc32(data)
      raise BrokenPackageException.new('CRC32 does not match.')
    end

    if need_conf
      conf_package = Package.new(conf_number, 0)
      begin
        conf_package.send(s, false, sender.last, sender[1])
      rescue SendPackageException => send_confirm_ex
        raise ConfirmFailedException.new(send_confirm_ex.message)
      end
    end

    return data, conf_number, sender
  end
end