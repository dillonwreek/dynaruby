#/usr/bin/env ruby
require "fileutils"
require "io/console"
require "uri"
require "net/http"

def main_page
  puts "DynaRuby is a client written in Ruby that allows you to update any given NoIP hostname"
  puts "version 0.1. Made with love by Dillon"

  conf_file = "/etc/dynaruby.conf"
  if !File.exist?(conf_file)
    puts "Config file not found, want to create one? (y/n)"
    loop do
      answer = gets.chomp
      break if answer == "y"
      if answer == "n"
        puts "we need a config file."
        exit
      end
      puts "please input y(es) or n(o) to confirm." if answer != "y" && answer != "n"
    end
    set_args
  else
    check_ip
  end
end

def set_args
  puts "please input username: "
  username = gets.chomp
  puts "Note: Sometimes characters won't be escaped correctly by noip if your password has symbols. Consider changing your password if you're facing issues."
  puts "please input password: "
  password = STDIN.noecho(&:gets).chomp

  puts "please input hostname(s). Tell me you're done with an empty line. Delete last inputted hostname by typing d and pressing enter"

  hostnames = []
  n = 0
  loop do
    puts "hostname #{n + 1}: "
    hostnames << gets.chomp
    conf = hostnames.last
    break if hostnames.last == ""
    if hostnames.last == "d"
      puts "hostname removed."
      hostnames.pop
      n = n - 1
    else
      n += 1
    end
  end

  hostnames.pop
  confirm_args(username, password, hostnames)
end

private

def confirm_args(username, password, hostnames)
  puts "Is this ok? (y/n) username: #{username} password: #{password} hostnames: #{hostnames}"
  loop do
    answer = gets.chomp
    break if answer == "y" || answer == "yes"
    set_args if answer == "n" || answer == "no"

    puts "please choose either y(es) or n(o) to confirm the args." if answer != "y" && answer != "n"
  end

  FileUtils.touch("/etc/dynaruby.conf")
  config = File.open("/etc/dynaruby.conf", "w")
  if hostnames.size > 1
    puts "if you have multiple hostnames, we'll create a new file /etc/dynaruby_hostnames.conf"
    FileUtils.touch("/etc/dynaruby_hostnames.conf")
    hostnames_config = File.open("/etc/dynaruby_hostnames.conf", "a")
    hostnames.each do |hostname|
      hostnames_config.write("#{hostname}\n")
    end
    hostnames_config.close
  end
  config.write("#{username}\n#{password}\n#{hostnames.first}")
  config.close

  check_ip
end
