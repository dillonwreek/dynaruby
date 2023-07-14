#!/usr/bin/env ruby
def check
  if !File.exist?("/etc/dynaruby.conf")
    set_args
  else
    puts "You already have a config file. Want to create a new one? [y(es)/n(o)]"
    if yes_or_no
      set_args
    else
      puts "Exiting."
      exit
    end
  end
end

def yes_or_no
  loop do
    answer = gets.chomp.downcase
    if answer == "y" || answer == "yes"
      return true
    elsif answer == "n" || answer == "no"
      return false
    else
      puts "Please enter 'y(es)' or 'n(o)'"
    end
  end
end

def set_args
  puts "hello, you reached this method"
end

check
