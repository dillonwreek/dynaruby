#!/usr/bin/env ruby
require "fileutils"
require "io/console"
require "base64"
require "openssl"

module Installer
  def catch_ctrl_c
    Signal.trap("INT") { puts " Stopping..."; exit 130 } #gracefully exit
  end

  def start
    !File.exist?("/etc/dynaruby.conf") ? set_args : config_found
  end

  def config_found
    catch_ctrl_c
    puts "Config file already exists. Do you want to overwrite it? [y(es)/n(o)]"
    yes_or_no ? set_args : (puts "Aborting..."; exit)
  end

  def yes_or_no
    catch_ctrl_c
    positive_answers = ["y", "yes"]
    negative_answers = ["n", "no"]
    result = nil
    until result == true || result == false
      answer = STDIN.gets.downcase.chomp
      positive_answers.include?(answer) ? true : negative_answers.include?(answer) ? false : (puts "Please choose either y(es) or n(o) to confirm."; nil)
    end
    result
  end

  def set_args
    catch_ctrl_c
    #config structure is:
    #refresh time=
    #input
    #username=
    #input
    #password=
    #input
    #hostnames=
    #input
    #input
    #..
    config = []
    puts "Welcome, let's get started"
    puts "Please input how many times you want to check for an ip change:"
    config[0] = "refresh time="
    config[1] = STDIN.gets.chomp.to_i
    puts "Please input username:"
    config[2] = "username="
    config[3] = STDIN.gets.chomp
    puts "Please input password:"
    config[4] = "password="
    config[5] = STDIN.noecho(&:gets).chomp
    config[6] = "hostnames="
    puts "Please input hostname(s), tell me you're done with an empty line. Submit d to delete the last inputted hostname"
    until config.last == ""
      config << STDIN.gets.chomp
      config.last == "d" && config.size > 5 ? (puts "hostname removed."; config.pop; config.pop) : nil
    end
    config.pop
    config_file = File.open("/etc/dynaruby.conf", "w")
    config.each do |line|
      config_file.write("#{line}\n")
    end
    config_file.close
  end
end
