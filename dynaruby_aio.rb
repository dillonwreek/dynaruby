#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"

def logger(phrase)
  puts phrase
  begin
    File.open("/var/log/dynaruby.log", "a") { |file| file.puts(phrase) }
  rescue StandardError => error
    abort "Error: #{error}"
  end
end

class Client
  def initialize
    if ARGV[0] == "-install" || ARGV[0] == "-i" || !File.exist?("/etc/dynaruby.conf")
      @mode = "Install"
    else
      @mode = "Update"
    end
  end

  def mode
    @mode
  end
end

class Config
  def initialize
    if File.exist?("/etc/dynaruby.conf")
      @config_file = File.readlines("/etc/dynaruby.conf").map(&:chomp)
    else
      @config_file = nil
    end
  end

  def sleep_time_in_minutes
    @config_file[1].to_i
  end

  def username
    @config_file[3]
  end

  def password
    decrypted_password = decrypt(@config_file[5])
  end

  def hostnames
    @config_file[7..-1]
  end

  def os
    if RUBY_PLATFORM.include?("linux")
      "linux"
    elsif RUBY_PLATFORM.include?("darwin")
      "darwin"
    elsif RUBY_PLATFORM.include?("bsd")
      "bsd"
    end
  end

  def start_installation
    !File.exist?("/etc/dynaruby.conf") ? set_args : config_found
  end

  def config_found
    puts "Config file already exists. Do you want to overwrite it? [y(es)/n(o)]"
    if yes_or_no
      set_args
    else
      puts "Aborting..."; abort "User aborted"
    end
  end

  def yes_or_no
    loop do
      answer = STDIN.gets.downcase.chomp
      return true if answer == "y" || answer == "yes"
      return false if answer == "n" || answer == "no"
      puts "Please choose either y(es) or n(o)"
    end
  end

  def set_args
    config = []
    logger("Let's get started setting up the config")
    #Config file is structured as follows:
    #time=
    #input
    #username=
    #input
    #password=
    #input
    #hostnames=
    #input
    #input
    #..

    puts "Please input the frequency of the check for an ip change in minutes:"
    config[0] = "time="
    config[1] = STDIN.gets.chomp.to_i * 60
    puts "Please input username:"
    config[2] = "username="
    config[3] = STDIN.gets.chomp
    puts "Please input password (noecho):"
    config[4] = "password="
    config[5] = encrypt(STDIN.noecho(&:gets).chomp)
    config[6] = "hostnames="
    number_of_hostnames = 0
    puts "Please input hostname(s), tell me you're done with an empty line. Submit d to delete the last inputted hostname"
    until config.last == ""
      puts "Please input hostname number #{number_of_hostnames + 1}. Submit d to delete, or empty line to continue:"
      config << STDIN.gets.chomp
      if config.last == "d" && number_of_hostnames > 0
        puts "hostname removed."
        config.pop
        config.pop
        number_of_hostnames -= 1
      elsif (config.last == "d" && number_of_hostnames < 1)
        puts "There are no hostnames to delete."
        config.pop
      else
        number_of_hostnames += 1
      end
    end
    config.pop

    config_file = File.open("/etc/dynaruby.conf", "w")
    config.each do |arg|
      config_file.write("#{arg}\n")
    end
    config_file.close
    logger("Config written to /etc/dynaruby.conf")
    copy_script
  end

  def copy_script
    logger("Copying script to /usr/local/bin")
    File.exist?("/usr/local/sbin/dynaruby") ? FileUtils.rm("/usr/local/sbin/dynaruby") : nil
    FileUtils.copy(__FILE__, "/usr/local/sbin/dynaruby")
    logger("Successfully installed Dynaruby! The program will now install the appropriate service files")
    copy_service
  end

  def write_env_to_service(os, merged_key_iv)
    if os == "linux"
      p "merged_key_iv: #{merged_key_iv}"
      if !File.exist?("#{Dir.pwd}/dynaruby.service")
        logger("Service file not found. Downloading service script...")
        download_service(os)
      end
      dynaruby_service = File.readlines("#{Dir.pwd}/dynaruby.service").map(&:chomp)
      dynaruby_service[5] = "Environment=\"DYNARUBY_KEY=#{merged_key_iv}\"\n"
      File.open("#{Dir.pwd}/dynaruby.service", "w") do |file|
        dynaruby_service.each { |line| file.puts(line) }
      end
    elsif os == "bsd"
      #todo
    end
  end

  def copy_service
    logger("Copying service script")
    if os == "linux"
      FileUtils.mv("#{Dir.pwd}/dynaruby.service", "/etc/systemd/system/dynaruby.service")
    elsif os == "bsd"
      #todo
    end
  end

  def download_service(os)
    if os == "linux"
      begin
        service_raw = Net::HTTP.get_response(URI("https://raw.githubusercontent.com/dillonwreek/dynaruby/main/dynaruby.service"))
      rescue StandardError => error
        logger("Error downloading the service script: #{error}, try again?"); yes_or_no ? download_service : (puts "Aborting..."; abort "User aborted")
      end
      service_file = File.open("#{Dir.pwd}/dynaruby.service", "w")
    elsif os == "bsd"
      begin
        service_raw = Net::HTTP.get_response(URI("https://raw.githubusercontent.com/dillonwreek/dynaruby/main/dynaruby.rcd"))
      rescue StandardError => error
        logger("Error downloading the service script: #{error}, try again?"); yes_or_no ? download_service : (puts "Aborting..."; abort "User aborted")
      end
      service_file = File.open("#{Dir.pwd}/dynaruby.rcd", "w")
    end
    service_lines = service_raw.response.body.split("\n")
    service_lines.each { |line| service_file.puts(line) }
    service_file.close
    logger("Successfully downloaded the service script!")
  end

  private

  def encrypt(password)
    cipher = OpenSSL::Cipher::AES.new(256, :CBC)
    cipher.encrypt
    key = OpenSSL::Random.random_bytes(32)
    iv = OpenSSL::Random.random_bytes(16)
    merged_key_iv = Base64.encode64(key) + "," + Base64.encode64(iv)
    write_env_to_service(os, merged_key_iv)
    puts "THIS KEY IS FUNDAMENTAL TO DECRYPT YOUR NO-IP PASSWORD. DO NOT SHARE IT WITH ANYONE"
    puts "DYNARUBY_KEY: #{merged_key_iv}"
    cipher.key = key
    cipher.iv = iv
    encrypted_pswd = cipher.update(password) + cipher.final
    encoded_pswd = Base64.encode64(encrypted_pswd)
  end

  def decrypt(password)
    decipher = OpenSSL::Cipher::AES.new(256, :CBC)
    decipher.decrypt
    begin
      merged_key_iv_array = ENV["DYNARUBY_KEY"].split(",")
    rescue StandardError => error
      logger("Error loading the DYNARUBY_KEY. It's probably not set. Ruby error: #{error}.."); abort "INVALID DYNARUBY_KEY"
    end
    decipher.key = Base64.decode64(merged_key_iv_array[0])
    decipher.iv = Base64.decode64(merged_key_iv_array[1])
    decrypted_pswd = decipher.update(Base64.decode64(password)) + decipher.final
  end
end

class Updater
  def initialize
    @last_ip = nil
  end

  def check_ip_change(config)
    begin
      new_ip = Net::HTTP.get(URI("http://ifconfig.me/ip"))
    rescue StandardError => error
      logger("Error: #{error}.. Waiting for #{config.sleep_time_in_minutes} minutes and checking again")
      sleep config.sleep_time_in_minutes
      check_ip_change(config)
    end
    case @last_ip
    when nil
      @last_ip = new_ip
      logger("IP was nil. Changing to #{new_ip}"); @last_ip = new_ip; update_ip(config, new_ip)
    when new_ip
      logger("IP did not change, waiting for #{config.sleep_time_in_minutes} minutes and checking again")
      sleep config.sleep_time_in_minutes; check_ip_change(config)
    else
      logger("IP changed, updating from #{@last_ip} to #{new_ip}"); @last_ip = new_ip; update_ip(config, new_ip)
    end
  end

  def update_ip(config, new_ip)
    url = URI("https://dynupdate.no-ip.com/nic/update?hostname=#{config.hostnames.join(" ")}&myip=#{new_ip}")
    authentication = Net::HTTP::Get.new(url)
    authentication.basic_auth config.username, config.password
    authorization = Base64.encode64("#{config.username}:#{config.password}")
    headers = { "Authorization" => "Basic #{authorization}", "User-Agent" => "Personal dynaruby/openbsd-7.3" }

    # response
    begin
      response = Net::HTTP.get_response(url, headers, authentication)
    rescue StandardError => error
      logger("Error: #{error}... Waiting for 1 minute and trying again")
      sleep 60
      update_ip(config, new_ip)
    end
    if response.body.include?("nochg")
      logger("NO-IP parsed the request and found the IP is unchanged")
    elsif response.body.include?("good")
      logger("NO-IP acknowledged the change. IP updated")
    else
      logger("Something went wrong updating the IP. The response from NO-IP was:  #{response.body}. Trying again in 15 seconds")
      sleep 15; update_ip(config, new_ip)
    end
    # call to check again
    check_ip_change(config)
  end
end

dynaruby = Client.new
config = Config.new
updater = Updater.new

if dynaruby.mode == "Install"
  config.start_installation
elsif dynaruby.mode == "Update"
  updater.check_ip_change(config)
end
