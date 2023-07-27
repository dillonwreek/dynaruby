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
    positive_answers = ["y", "yes"]
    negative_answers = ["n", "no"]
    result = nil
    until result == true || result == false
      answer = STDIN.gets.downcase.chomp
      positive_answers.include?(answer) ? true : negative_answers.include?(answer) ? false : (puts "Please choose either y(es) or n(o) to confirm."; nil)
    end
    result
  end

  def os
    case RUBY_PLATFORM
    when /linux/
      "linux"
    when /bsd/
      "bsd"
    end
  end
end
