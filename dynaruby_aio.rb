#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"

class Client
  def initialize
    puts "Initializing..."
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
    File.exist?("/etc/dynaruby.conf") ? @config_file = File.readlines("/etc/dynaruby.conf").map(&:chomp) : @config_file = false
  end

  def sleep_time_in_minutes
    @config_file[1].to_i * 60
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

  def start_installation
    !File.exist?("/etc/dynaruby.conf") ? set_args : config_found
  end

  def config_found
    puts "Config file already exists. Do you want to overwrite it? [y(es)/n(o)]"
    yes_or_no ? set_args : (puts "Aborting..."; exit 130) #branchless confirmation
  end

  def yes_or_no
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
    config = []
    puts "Let's get started setting up the config"
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

    puts "Please input the frequency of the check for an ip change in minutes:"
    config[0] = "time="
    config[1] = STDIN.gets.chomp.to_i
    puts "Please input username:"
    config[2] = "username="
    config[3] = STDIN.gets.chomp
    puts "Please input password (noecho):"
    config[4] = "password="
    config[5] = STDIN.noecho(&:gets).chomp
    config[6] = "hostnames="
    number_of_hostnames = 0
    puts "Please input hostname(s), tell me you're done with an empty line. Submit d to delete the last inputted hostname"
    until config.last == ""
      p = "Please input hostname number #{number_of_hostnames + 1}. Submit d to delete, or empty line to continue:"
      config << STDIN.gets.chomp
      config.last == "d" && config.size > 5 ? (puts "hostname removed."; config.pop; config.pop; number_of_hostnames -= 1) : nil
    end
    config.pop

    config[5] = encrypt(config[5])

    config_file = File.open("/etc/dynaruby.conf", "w")
    config.each do |arg|
      config_file.write("#{arg}\n")
    end
    config_file.close
    puts "Config written to /etc/dynaruby.conf"

    copy_script
  end

  def copy_script
    File.exist?("/usr/local/sbin/dynaruby") ? FileUtils.rm("/usr/local/sbin/dynaruby") : nil
    File.exist?("/etc/systemd/system/dynaruby.service") ? FileUtils.rm("/etc/systemd/system/dynaruby.service") : nil
    FileUtils.copy("#{Dir.pwd}/dynaruby_aio.rb", "/usr/local/sbin/dynaruby")
    os == "linux" ? FileUtils.copy("#{Dir.pwd}/dynaruby.service", "/etc/systemd/system/dynaruby.service") : os == "bsd" ? FileUtils.copy("./dynaruby.rcd", "/etc/rc.d/dynaruby") : (puts "Unrecognized OS. Please install the dynaruby service manually. Your detected os is: #{RUBY_PLATFORM}")
    puts "Successfully installed Dynaruby!"
  end

  def write_env_to_shell(merged_key_iv)
    os == "linux" ? write_service_script(merged_key_iv) : os == "bsd" ? write_rcd_script(merged_key_iv) : (puts "Unrecognized OS. Please install the dynaruby service manually. Your detected os is: #{RUBY_PLATFORM}")
  end

  def write_service_script(merged_key_iv)
    p "merged_key_iv: #{merged_key_iv}"
    !File.exist?("#{Dir.pwd}/dynaruby.service") ? download_service_script : nil
    dynaruby_service = File.readlines("#{Dir.pwd}/dynaruby.service").map(&:chomp)
    dynaruby_service[5] = "Environment=\"DYNARUBY_KEY=#{merged_key_iv}\"\n"
    File.open("#{Dir.pwd}/dynaruby.service", "w") do |file|
      dynaruby_service.each { |line| file.puts(line) }
    end
  end

  def download_service_script
    begin
      dynaruby_service_raw = Net::HTTP.get_response(URI("https://raw.githubusercontent.com/dillonwreek/dynaruby/main/dynaruby.service"))
    rescue StandardError => error
      puts "Error downloading the service script: #{error}, try again?"; yes_or_no ? download_service_script : (puts "Aborting..."; exit 130)
    end
    puts "Successfully downloaded the service script!"

    dynaruby_service_lines = dynaruby_service_raw.response.body.split("\n")
    File.open("#{Dir.pwd}/dynaruby.service", "w") do |file|
      dynaruby_service_lines.each { |line| file.puts(line) }
    end
  end

  def write_rcd_script(merged_key_iv)
    p "merged_key_iv: #{merged_key_iv}"
    !File.exist?("#{Dir.pwd}/dynaruby.rcd") ? download_rcd_script : nil
    dynaruby_rcd = File.readlines("#{Dir.pwd}/dynaruby.rcd").map(&:chomp)
    dynaruby_rcd[8] = "env DYNARUBY_KEY=#{merged_key_iv} ${daemon}"
    File.open("#{Dir.pwd}/dynaruby.rcd", "w") do |file|
      dynaruby_rcd.each { |line| file.puts(line) }
    end
  end

  def download_rcd_script
    begin
      dynaruby_rcd_raw = Net::HTTP.get_response(URI("https://raw.githubusercontent.com/dillonwreek/dynaruby/main/dynaruby.rcd"))
    rescue StandardError => error
      puts "Error downloading the rcd script: #{error}, try again?"; yes_or_no ? download_rcd_script : (puts "Aborting..."; exit 130)
    end
    puts "Successfully downloaded the rcd script!"
    dynaruby_rcd_lines = dynaruby_rcd_raw.response.body.split("\n")
    File.open("#{Dir.pwd}/dynaruby.rcd", "w") do |file|
      dynaruby_rcd_lines.each { |line| file.puts(line) }
    end
  end

  def os
    RUBY_PLATFORM.include?("linux") ? "linux" : RUBY_PLATFORM.include?("bsd") ? "bsd" : RUBY_PLATFORM.include?("darwin") ? (puts "macOS is not supported."; exit 130) : (puts "Unrecognized OS. Please install the dynaruby service manually. Your detected os is: #{RUBY_PLATFORM}")
  end

  private

  def encrypt(password)
    cipher = OpenSSL::Cipher::AES.new(256, :CBC)
    cipher.encrypt
    key = OpenSSL::Random.random_bytes(32)
    iv = OpenSSL::Random.random_bytes(16)
    merged_key_iv = Base64.strict_encode64(key) + "," + Base64.strict_encode64(iv)
    write_env_to_shell(merged_key_iv)
    cipher.key = key
    cipher.iv = iv
    encrypted_pswd = cipher.update(password) + cipher.final
    encoded_pswd = Base64.strict_encode64(encrypted_pswd)
  end

  def decrypt(encrypted_password)
    decipher = OpenSSL::Cipher::AES.new(256, :CBC)
    decipher.decrypt
    merged_key_iv_array = ENV["DYNARUBY_KEY"].split(",")
    decipher.key = Base64.decode64(merged_key_iv_array[0])
    decipher.iv = Base64.decode64(merged_key_iv_array[1])
    decrypted_pswd = decipher.update(Base64.decode64(encrypted_password)) + decipher.final
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
      puts "Error: #{error}.. Waiting for #{config.sleep_time_in_minutes} minutes and checking again"
      sleep config.sleep_time_in_minutes
      check_ip_change(config)
    end
    case @last_ip
    when nil
      puts "IP was nil. Changing to #{new_ip}"; @last_ip = new_ip; update_ip(config, new_ip)
    when new_ip
      puts "IP unchanged, sleeping for #{config.sleep_time_in_minutes} minutes and checking again"; sleep config.sleep_time_in_minutes; check_ip_change(config)
    else
      puts "IP changed, updating from #{@last_ip} to #{new_ip}"; update_ip(config, new_ip)
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
      puts "Error: #{error}... Waiting for 1 minute and trying again"
      sleep 60
      update_ip(config, new_ip)
    end
    #parse response
    response.body.include?("nochg") ? (puts "IP unchanged, NOIP parsed the request and found that the IPs are the same") : response.body.include?("good") ? (puts "IP updated, NOIP acknowledged the change") : (puts "Something went wrong updating the IP. The response from NOIP was:"; puts response.body; puts "Trying again"; sleep 15; update_ip(config, new_ip))

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
