#!/usr/bin/env ruby
def main_page
  set_args
end

def set_args
  puts "please input username: "
  username = gets.chomp
  puts "please input password: "
  password = gets.chomp

  puts "please input hostname(s). Tell me you're done with 'c' "
  hostnames = []
  loop do
    hostnames << gets.chomp
    conf = hostnames.last
    break if hostnames.last == "c"
    if hostnames.last != "c" && hostnames.last.length == 1
      puts "wrong escape character. Please input c to confirm."
      hostnames.pop
    end
  end
  hostnames.pop
  hostnames_str = hostnames.to_s.gsub("[", "").gsub("]", "").gsub(/"/, "").gsub(",", " ")
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
  end
end

def check_ip
  ip = `curl ifconfig.co`.chomp
  if ip != last_ip
    last_ip = ip
  end
end

main_page
