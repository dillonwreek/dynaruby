#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"

def os
  if RUBY_PLATFORM.include?("darwin")
    "mac"
  elsif RUBY_PLATFORM.include?("linux")
    "linux"
  elsif RUBY_PLATFORM.include?("bsd")
    "bsd"
  end
end

def check_os(os)
  if os == "mac"
    puts "macOS is not supported."
  elsif os == "linux"
    puts "linux is not supported."
  elsif os == "bsd"
    puts "bsd is not supported."
  end
end

check_os(os)
