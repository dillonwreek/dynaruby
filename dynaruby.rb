#!/usr/bin/env ruby
require "fileutils"
require "io/console"
require "uri"
require_relative "user_input"

class UserInput
  #a simple method to DRY user confirmation
  def yes_or_no
    Signal.trap("INT") { puts " Stopping..."; exit 130 }
    loop do
      @answer = gets.chomp
      return true if @answer == "y" || @answer == "yes"
      return false if @answer == "n" || @answer == "no"
      puts "please choose either y(es) or n(o) to confirm."
    end
  end
end

#script starts here
def main_page
  anser = UserInput.new
  p answer
  if false
    if __dir__ != "/usr/local/sbin"
      puts 'Warning: script isn\'t in /usr/local/sbin.'
      puts "Please use the installer to place the scripts in their appropriate directories and generate a config. If you already have the config file, you can just place this script under /usr/local/sbin."
      exit
    end
  end
  conf_file = "/etc/dynaruby.conf"
  if !File.exist?(conf_file)
    puts "Config file not found, want to create one? (y/n)"
    if yes_or_no
      set_args
    else
      puts "we need a config file."
      main_page
    end
  else
    check_ip
  end
end

#set the arguments for the config
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
    Signal.trap("INT") { puts " Stopping..."; exit 130 }
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

#confirm the arguments, and write them to the config. The config will look different if you have multiple hostnames.
def confirm_args(username, password, hostnames)
  puts "Is this ok? (y/n) username: #{username} password: #{password} hostnames: #{hostnames}"
  if !yes_or_no
    set_args
  else
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
end

#curls ifconfig.co for the pubip.
def check_ip
  ip = `curl ifconfig.co`.chomp
  if ip != @last_ip
    @last_ip = ip
    puts "IP changed to #{ip}"
    populate_hostnames(ip)
  else
    puts "else"
    check_ip
  end
end

#send the request to the No-IP API endpoint
def populate_hostnames(ip)
  puts "Populating hostnames"

  if File.exist?("/etc/dynaruby_hostnames.conf") #if the user has multiple hostnames..
    hostnames = File.readlines("/etc/dynaruby_hostnames.conf").map(&:chomp)
    config = File.readlines("/etc/dynaruby.conf").map(&:chomp)
  else
    config = File.readlines("/etc/dynaruby.conf").map(&:chomp)
    hostnames = [config[2]]
  end
  update_hostnames(config, hostnames, ip)
end

def update_hostnames(config, hostnames, ip)
  url = URI("https://dynupdate.no-ip.com/nic/update")
  agent = "Personal dynaruby/openbsd"
  hostnames.each do |hostname|
    response = `curl --get --silent --show-error --user-agent '#{agent}' --user #{config[0]}:#{config[1]} -d "hostname=#{hostname}" -d "myip=#{ip}" #{url}`
    check_response(response, config)
  end
end

#dirty way to check for the response type
def check_response(response, config)
  if response.include?("nochg")
    puts "hostname #{config[2]} was already up-to-date"
  elsif response.include?("good")
    puts "hostname #{config[2]} updated"
  else
    puts "something went wrong updating hostname #{config[2]}, error: #{response}"
    check_ip
  end
end

puts "DynaRuby is an ipv4 no-ip client written in Ruby. v 0.1 Made with love by Dillon"

#run the script
main_page
