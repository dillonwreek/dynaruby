#!/usr/bin/env ruby
require "fileutils"
require "io/console"

def main_page
  puts "DynaRuby is an ipv4 no-ip client written in Ruby. v 0.1 Made with love by Dillon"

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
      puts "Please input y(es) or n(o) to confirm." if answer != "y" && answer != "n"
    end
    set_args
  else
    check_ip
  end
end

def set_args
  puts "please input username: "
  username = gets.chomp
  puts "Note: Sometimes characters won't be escaped correctly if your password has symbols. Consider changing your password if you're facing issues."
  puts "Please input password: "
  password = STDIN.noecho(&:gets).chomp

  puts "Please input hostname(s)/ Tell me you're done with an empty line. Submit d to delete the last inputted hostname"

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

  hstnames.pop
  confirm_args(username, password, hostnames)
end

def confirm_args(username, password, hostnames)
  loop do
    puts "Is this ok? (y/n) username: #{username} password: #{password} hostnames: #{hostnames}"
    answer = gets.chomp
    break if answer == "y" || answer == "yes"
    set_args if answer == "n" || answer == "no"
    puts "please choose either y(es) or n(o) to confirm the args." if answer != "y" && answer != "n"
  end
  config = File.open("/etc/dynaruby.conf", "w")
  if hostnames.size > 1
    puts "if you have multiple hostnames, we'll create a new file /etc/dynaruby_hostnames.conf"
    hostnames_config = File.open("/etc/dynaruby_hostnames.conf", "a")
    hostnames.each do |hostname|
      hostnames_config.write("#{hostname}\n")
    end
    hostnames_config.close
    config.write("#{username}\n#{password}")
    config.close
  else
    config.write("#{username}\n#{password}\n#{hostnames.first}")
    config.close
  end
  check_ip
end

def check_ip
  ip = `curl ifconfig.co`.chomp
  if ip != @last_ip
    @last_ip = ip
    puts "IP changed to #{ip}"
    update_ip(ip)
  else
    puts "else"
    check_ip
  end
end

def update_ip(ip)
  puts "Updating IP.."
  url = "https://dynupdate.no-ip.com/nic/update"
  agent = "Personal dynaruby/openbsd-v7.03"
  if File.exist?("/etc/dynaruby_hostnames.conf")
    hostnames = File.readlines("/etc/dynaruby_hostnames.conf").map(&:chomp)
    config = File.readlines("/etc/dynaruby.conf").map(&:chomp)
    hostnames.each do |hostname|
      puts "updating ip for hostname #{hostname}"
      res = `curl --get --silent --show-error --user-agent #{agent} --user #{config[0]}:#{config[1]} -d "hostname=#{hostname}" -d "myip=#{ip}" #{url}`
      if res.include?("nochg")
        puts "hostname #{hostname} was already up-to-date"
      elsif res.include?("good")
        puts "hostname #{hostname} updated"
      else
        puts "something went wrong updating hostname #{hostname}, error: #{res}"
      end
    end
  else
    config = File.readlines("/etc/dynaruby.conf").map(&:chomp)
    puts "updating ip for #{config[2]}"
    res = `curl --get --silent --show-error --user-agent #{agent} --user #{config[0]}:#{config[1]} -d "hostname=#{config[2]}" -d "myip=#{ip}" #{url}`
    if res.include?("nochg")
      puts "hostname #{config[2]} was already up-to-date"
    elsif res.include?("good")
      puts "hostname #{config[2]} updated"
    else
      puts "something went wrong updating hostname #{config[2]}, error: #{res}"
    end
  end
end

main_page
