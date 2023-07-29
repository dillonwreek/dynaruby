#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"

def catch_ctrl_c
  Signal.trap("INT") { puts " Stopping..."; exit 130 } #gracefully exit
end

module Installer
  def start_installation
    !File.exist?("/etc/dynaruby.conf") ? set_args : config_found
  end

  def config_found
    catch_ctrl_c
    puts "Config file already exists. Do you want to overwrite it? [y(es)/n(o)]"
    yes_or_no ? set_args : (puts "Aborting..."; exit 130) #branchless confirmation
  end

  def yes_or_no
    catch_ctrl_c
    positive_answers = ["y", "yes"]
    negative_answers = ["n", "no"]
    result = nil
    until result == true || result == false
      @answer = STDIN.gets.downcase.chomp
      #branchless way of checking for y or n + invalid input
      result = positive_answers.include?(@answer) ? true : negative_answers.include?(@answer) ? false : (puts "Please choose either y(es) or n(o) to confirm."; nil)
    end
    result
  end

  def set_args
    catch_ctrl_c
    config = []
    puts "Let's get started setting up the config"
    #Config file is structured as follows:
    #time=
    #input
    #username=
    #input
    #password=
    #input
    #hostnames=
    #input
    #input

    puts "Please input the frequency of the check for an ip change in minutes:"
    config[0] = "time="
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

    config[5] = Base64.encode64(encrypt(config[5]))

    config_file = File.open("/etc/dynaruby.conf", "w")
    config.each do |arg|
      config_file.write("#{arg}\n")
    end
    config_file.close
    puts "Config written to /etc/dynaruby.conf"

    copy_script
  end

  def copy_script
    FileUtils.copy("./dynaruby_aio.rb", "/usr/local/sbin/dynaruby")
    os == "linux" ? FileUtils.copy("./dynaruby.service", "/etc/systemd/system/dynaruby.service") : os == "bsd" ? FileUtils.copy("./dynaruby.rcd", "/etc/rc.d/dynaruby") : nil

    puts "Successfully installed Dynaruby!" and exit
  end

  def os
    case RUBY_PLATFORM
    when /darwin/
      "mac"
    when /linux/
      "linux"
    when /bsd/
      "bsd"
    end
  end
end
