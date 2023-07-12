#!/usr/bin/env ruby
class Config
  def read_from_file
    @config ||= File.readlines("/etc/dynaruby.conf").map(&:chomp)
  end

  def username
    @config[1]
  end

  def password
    @config[3]
  end

  def hostnames
    hostnames = []
    @config[5..-1].each do |hostname|
      hostnames << hostname
    end
    hostnames
  end
end

config = Config.new
config.read_from_file
loop do
  puts config.username
  puts config.password
  puts config.hostnames
end
