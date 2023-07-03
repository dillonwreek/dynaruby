#!/usr/bin/env ruby
def main_page
  puts "DynaRuby is a client written in Ruby that allows you to update any given NOIP hostname"
  puts "version 0.1. Made with love by Dillon"
  conf_file = "/etc/dynaruby.conf"
  if !File.exist?(conf_file)
    set_args
  else
    config = File.read(conf_file)
  end
end

def set_args
  puts "please input username: "
  username = gets.chomp
  puts "please input password: "
  password = gets.chomp

  puts "please input hostname(s). Tell me you're done with 'c' "
  hostnames = []
  n = 0
  loop do
    puts "hostname #{n + 1}: "
    hostnames << gets.chomp
    conf = hostnames.last
    break if hostnames.last == "c"
    if hostnames.last != "c" && hostnames.last.length == 1
      puts "wrong escape character. Please input c to confirm."
      hostnames.pop
    end
    n += 1
  end
  hostnames.pop
  hostnames_str = hostnames.to_s.gsub("[", "").gsub("]", "").gsub(/"/, "").gsub(",", "")
  check_args(username, password, hostnames_str)
end

def check_args(username, password, hostnames_str)
  loop do
    puts "Is this ok? (y/n) username: #{username} password: #{password} hostnames: #{hostnames_str}"
    answer = gets.chomp
    if answer == "n"
      set_args
    end
    break if answer == "y"

    if answer != "y" && answer != "n"
      puts "please input y or n to confirm the args."
    end

    `touch /etc/dynaruby.conf`
    config = File.open("/etc/dynaruby.conf", "w")
    config.write("#{username}\n#{password}\n#{hostnames_str}")
    config.close
  end
end

def check_ip
  ip = `curl ifconfig.co`.chomp
  if ip != last_ip
    last_ip = ip
  end
end

main_page
