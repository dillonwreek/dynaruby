#!/usr/bin/env ruby
require "io/console"
require "uri"

class UserInput
  def yes_or_no
    Signal.trap("INT") { puts " Stopping..."; exit 130 } #gracefully exit
    loop do
      @answer = gets.chomp
      return true if @answer == "y" || @answer == "yes"
      return false if @answer == "n" || @answer == "no"
      puts "please choose either y(es) or n(o) to confirm."
    end
  end

  #method to set the arguments for the curl command.
  def set_args
    args = []
    Signal.trap("INT") { puts " Stopping..."; exit 130 } #gracefully exit

    #config will look like this
    #username=
    #input
    #password=
    #input
    #hostnames=
    #input
    #input
    #..

    puts "Please input username:"
    args[0] = "username="
    args[1] = gets.chomp
    puts "Please input password:"
    args[2] = "password="
    args[3] = STDIN.noecho(&:gets).chomp # do not echo password
    puts "Please input hostname(s), tell me you're done with an empty line. Submit d to delete the last inputted hostname"
    args[4] = "hostnames="
    i = 5
    until args.last == ""
      Signal.trap("INT") { puts " Stopping..."; exit 130 } # gracefully exit
      args[i] = gets.chomp
      p args[i]

      if args[i] == "d" && i > 5
        puts "hostname removed."
        args.pop # remove d
        args.pop # remove last hostname
        i = i - 1
      elsif args[i] == "d" && i == 5 # dont remove things that arent hostnames from the config
        puts "you need to input an hostname before you can remove one"
        args.pop
      else
        i += 1
      end
    end
    args.pop #remove confirmation line
    confirm_args(args)
  end

  #confirm_args asks for confirmation and goes back to set_args if confirmation fails
  def confirm_args(args)
    puts "Is this ok? (y/n) #{args}"
    if !yes_or_no
      set_args
    else
      config = File.open("/etc/dynaruby.conf", "a")
      args.each do |arg|
        config.write("#{arg}\n")
      end
      config.close
    end
    puts "Arguements written to /etc/dynaruby.conf"
  end
end

class CheckIP
  #method to check the ip, simple curl to ifconfig.co. IPs are public variables to be more accessible
  def check
    @ip = `curl ifconfig.co`.chomp
    if @ip != @last_ip
      puts "IP changed from #{@last_ip} to #{@ip}"
      @last_ip = @ip
      populate_hostnames
    end
  end

  #populate a hostnames array from the line 5 onward in the config.
  def populate_hostnames
    hostnames = []
    args = File.readlines("/etc/dynaruby.conf").map(&:chomp)
    if args.size > 5 # does the config contain more than one hostname?
      for i in 5..args.size - 1
        hostnames << args[i]
      end
    else
      hostnames = args.last #if not just set the hostname to the last line
    end
    update_ip(hostnames)
  end

  def update_ip(hostnames)
    url = URI("https://dynupdate.no-ip.com/nic/update")
    agent = "Personal dynaruby/openbsd"
    args = File.readlines("/etc/dynaruby.conf").first(4).map(&:chomp) #grab only the first four lines of the config(username and password)
    hostnames.each do |hostname| # loop through the hostnames and send the request to the no-ip API endpoint
      puts "username= #{args[1]} password= #{args[3]}"
      response = `curl --get --silent --show-error --user-agent '#{agent}' --user #{args[1]}:#{args[3]} -d 'hostname=#{hostname}' -d  "myip=#{@ip}" #{url}`
      check_response(response, hostname)
    end
  end

  #tell the user if the request was successful or not
  def check_response(response, hostname)
    if response.include?("nochg")
      puts "hostname #{hostname} was already up-to-date"
    elsif response.include?("good")
      puts "hostname #{hostname} updated"
    else
      puts "something went wrong updating hostname #{hostname}, error: #{response}"
      check
    end
  end
end

input = UserInput.new
probe = CheckIP.new

puts "DynaRuby is an ipv4 no-ip client written in Ruby. Version: 0.1 - Made with love by Dillon"
config = "/etc/dynaruby.conf"
if !File.exist?(config)
  puts "Config file not found. Creating one..."
  input.set_args
end
probe.check

#to do:

#schedule check_ip
#change curl to the appropriate ruby way of doing it (http)
