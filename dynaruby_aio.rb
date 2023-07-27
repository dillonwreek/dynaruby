#!/usr/bin/env ruby
require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"

class Installer
  def catch_ctrl_c
    Signal.trap("INT") { puts " Stopping..."; exit 130 } #gracefully exit
  end

  def start
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
    puts "Let's get started with the configuration"
    puts "Please input username:"
    username = STDIN.gets.chomp
    puts "Please input password:"
    password = STDIN.noecho(&:gets).chomp
    puts "Please input hostname(s), tell me you're done with an empty line. Submit d to delete the last inputted hostname"
    hostnames = []
    number_of_hostnames = 1
    until hostnames.last == ""
      puts "Please input hostname number #{number_of_hostnames}:"
      hostnames << STDIN.gets.chomp
      if hostnames.last == "d"
        puts "hostname removed."
        number_of_hostnames = number_of_hostnames - 1
        hostnames.pop
        hostnames.pop
      else
        number_of_hostnames = number_of_hostnames + 1
      end
    end
    hostnames.pop

    encrypted_pswd = encrypt(password)

    args = ["username=", username, "password=", encrypted_pswd, "hostnames="]
    args += hostnames
    config = File.open("/etc/dynaruby.conf", "w")
    args.each do |arg|
      config.write("#{arg}\n")
    end
    copy_script
  end

  def encrypt(password)
    cipher = OpenSSL::Cipher::AES.new(256, :CBC)
    cipher.encrypt
    key = OpenSSL::Random.random_bytes(32)
    iv = OpenSSL::Random.random_bytes(16)
    merged_key_iv = Base64.strict_encode64(key) + "," + Base64.strict_encode64(iv)
    cipher.key = key
    cipher.iv = iv
    p "merged_key_iv = #{merged_key_iv}"
    bashrc = File.open("#{Dir.home}/.bashrc", "a")
    bashrc.write "export DYNARUBY_KEY='#{merged_key_iv}'\n"
    bashrc.close

    encrypted_pswd = cipher.update(password) + cipher.final
    encoded_pswd = Base64.strict_encode64(encrypted_pswd)
  end

  def copy_script
    p "Copying Dynaruby script to /usr/local/sbin/"
    FileUtils.cp("./dynaruby.rb", "/usr/local/sbin/dynaruby")
    p "Copying Dynaruby rc.d service script to /etc/rc.d/"
    #FileUtils.cp("./rc.d", "/etc/rc.d/dynaruby")
    p "Successfully installed Dynaruby!"
  end

  def enable_service
  end
end

class Config
  def initialize
    @config ||= File.readlines("/etc/dynaruby.conf").map(&:chomp)
  end

  def username
    @username = @config[1]
  end

  def password
    @password = decrypt(@config[3])
  end

  def hostnames
    @hostnames = @config[5..-1]
  end

  def decrypt(password)
    decipher = OpenSSL::Cipher::AES.new(256, :CBC)
    decipher.decrypt
    merged_key_iv_array = ENV["DYNARUBY_KEY"].split(",")
    decipher.key = Base64.decode64(merged_key_iv_array[0])
    decipher.iv = Base64.decode64(merged_key_iv_array[1])
    decrypted_pswd = decipher.update(Base64.decode64(password)) + decipher.final
  end
end

class CheckIP
  def initialize
    @last_ip = nil
  end

  def monitor_ip_changes
    puts "Checking for IP change"
    my_ip = Net::HTTP.get_response(URI("http://ifconfig.me/ip")).body.chomp
    if my_ip != @last_ip
      @last_ip != nil ? (puts "IP changed from #{@last_ip} to #{my_ip})") : (puts "Last IP was nil. Current IP: #{my_ip}")
      @last_ip = my_ip
      update_ip(my_ip)
    else
      #wait 5 minutes and try again
      p "IP unchanged. Waiting for 5 minutes and checking again"
      sleep 300
      monitor_ip_changes
    end
  end

  def update_ip(my_ip)
    config = Config.new
    url = URI("https://dynupdate.no-ip.com/nic/update?hostname=#{config.hostnames.join(" ")}&myip=#{my_ip}")
    authentication = Net::HTTP::Get.new(url)
    authentication.basic_auth config.username, config.password
    authorization = Base64.encode64("#{config.username}:#{config.password}")
    headers = { "Authorization" => "Basic #{authorization}", "User-Agent" => "Personal dynaruby/openbsd" }
    response = Net::HTTP.get_response(url, headers, authentication)
    response.body.include?("nochg") ? (puts "IP unchanged") : response.body.include?("good") ? (puts "IP updated") : (puts "Something went wrong updating IP")
    monitor_ip_changes
  end
end

accepted_args = ["-i", "-install"]
(File.exist?("/etc/dynaruby.conf") && !accepted_args.include?(ARGV[0])) ? nil : Installer.new.start
probe = CheckIP.new
probe.monitor_ip_changes
