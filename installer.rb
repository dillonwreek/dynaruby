#THIS FILE IS NOT OK. IT SHOULD BE UPDATED TO USE THE SAME CLASSES AS DYNARUBY. I WANT THE INSTALLER TO SET THE CONFIG,
##BUT I ALSO WANT DYNARUBY TO BE ABLE TO INDEPENDANTLY UPDATE THE CONFIG FILE IN CASE IT IS DELETED OR LOST

#!/usr/bin/env ruby
require "fileutils"
require "io/console"

def install
  puts "Thank you for choosing Dynaruby! Placing files.."
  #`cp ./dynaruby.rb /usr/local/sbin/dynaruby`
  FileUtils.cp("./dynaruby.rb", "/usr/local/sbin/dynaruby")
  if !File.exist?("/etc/dynaruby.conf")
    generate_config
  end
end

def yes_or_no
  Signal.trap("INT") { puts " Stopping..."; exit 130 }
  loop do
    @answer = gets.chomp
    break if @answer == "y" || @answer == "yes"
    break if @answer == "n" || @answer == "no"
    puts "please choose either y(es) or n(o) to confirm." if answer != "y" && answer != "n" && answer != "no" && answer != "yes"
  end
  return true if @answer == "y" || @answer == "yes"
  return false if @answer == "n" || @answer == "no"
end

def generate_config
  puts "Config file not found, want to create one? (y/n)"
  if yes_or_no
    set_args
  else
    puts "we need a config file."
    generate_config
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
  end
end

install
