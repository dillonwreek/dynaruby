#!/usr/bin/env ruby
require "fileutils"
require "io/console"
require "base64"
require "openssl"

def start
  !File.exist?("/etc/dynaruby.conf") ? set_args : config_found
end

def config_found
  puts "Config file already exists. Do you want to overwrite it? [y(es)/n(o)]"
  if yes_or_no
    set_args
  else
    puts "Aborting..."
    exit
  end
end

def yes_or_no
  positive_answers = ["y", "yes"]
  negative_answers = ["n", "no"]
  result = nil
  until result == true || result == false
    @answer = gets.downcase.chomp
    result = positive_answers.include?(@answer) ? true : negative_answers.include?(@answer) ? false : (puts "Please choose either y(es) or n(o) to confirm."; nil)
  end
  result
end

def set_args
  puts "Let's get started"
  puts "Please input username:"
  username = gets.chomp
  puts "Please input password:"
  password = STDIN.noecho(&:gets).chomp
  puts "Please input hostname(s), tell me you're done with an empty line. Submit d to delete the last inputted hostname"
  hostnames = []
  number_of_hostnames = 1
  until hostnames.last == ""
    puts "Please input hostname number #{number_of_hostnames}:"
    hostnames << gets.chomp
    if hostnames.last == "d"
      puts "hostname removed."
      number_of_hostnames = number_of_hostnames - 1
      hostnames.pop
      hostnames.pop
    end
    number_of_hostnames = number_of_hostnames + 1
  end
  encrypt(password)
end

def encrypt(password)
  cipher = OpenSSL::Cipher::AES.new(256, :CBC)
  cipher.encrypt
  p "password = #{password}"
  key = OpenSSL::Random.random_bytes(32)
  iv = OpenSSL::Random.random_bytes(16)
  merged_key_iv = Base64.encode64(key) + "," + Base64.encode64(iv)
  p "merged_key_iv = #{merged_key_iv}"
  bash = File.open("#{Dir.home}/.bashrc", "a")
  bash.write "export DYNARUBY_KEY='#{merged_key_iv}'"
  bash.close
end

encrypt("cocco")
