#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"

def yes_or_no
  loop do
    answer = gets.downcase.chomp
    return true if answer == "y" || answer == "yes"
    return false if answer == "n" || answer == "no"
    puts "Please choose either y(es) or n(o)"
  end
end

def encrypt(string)
  Base64.encode64(string)
end

answer = yes_or_no
puts answer
config = ["time=", "1", "usename=", "dillonwreek@gmail.com", "password=", "CoccoBello", "hostnames=", "rails.ddns.net"]
config[5] = encrypt(STDIN.gets.chomp)
puts config
