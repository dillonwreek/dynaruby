#!/usr/bin/env ruby
class Config
  def initialize
    @config ||= File.readlines("/etc/dynaruby.conf").map(&:chomp)
  end

  def username
    @username = @config[1]
  end

  def password
    @password = @config[3]
  end

  def hostnames
    @hostnames = @config[5..-1]
  end
end

config = Config.new
puts "Username: #{config.username}"
puts "Password: #{config.password}"
puts "Hostnames: #{config.hostnames}"
