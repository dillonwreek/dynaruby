Class UserInput
  def yes_or_no
    Signal.trap("INT") { puts " Stopping..."; exit 130 }
    loop do
      @answer = gets.chomp
      return true if @answer == "y" || @answer == "yes"
      return false if @answer == "n" || @answer == "no"
      puts "please choose either y(es) or n(o) to confirm."
    end
  end

  def set_args
    args=[]
    args[0]="username="
    puts "Please input username"
    args[1] << gets.chomp
    args[2] = "password="
    puts "Please input password"
    args[3] << STDIN.noecho(&:gets).chomp
    args[4] = "hostnames="
    i=5
    loop do
      Signal.trap("INT") { puts " Stopping..."; exit 130 }
      puts "Please input hostname(s), tell me you're done with an empty line. Submit d to delete the last inputted hostname"
      args[i] << gets.chomp
      i+=1
      break if args[i] == ""
      if args[i] == "d"
        puts "hostname removed."
        args.pop
        i = i - 1
      end
    end
    confirm_args(args)
  end


  def confirm_args(args)
    puts "Is this ok? (y/n) #{args}"
    if !yes_or_no
      set_args
    else
      config = File.open("/etc/dynaruby.conf", "a")
      args.each do |arg|
        config.write("#{arg}\n")
      end
    end
    puts "Arguements written to /etc/dynaruby.conf"
  end
end

Class CheckIP
def check_ip
  ip = `curl ifconfig.co`.chomp
  if ip != @last_ip
    @last_ip = ip
    puts "IP changed to #{ip}"
    update_ip(ip)
  end
end
end