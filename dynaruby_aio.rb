#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"
require "logger"

#the namespace is here to make the LOGGER class available everywhere in the script
module Dynaruby
  #custom logger class to `puts` whats logged in the log file
  class Reporter
    def initialize
      @logger = Logger.new("/var/log/dynaruby.log", 10 * 1024 * 1024, progname: "dynaruby")
      @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    end

    def log(**phrase)
      level = case phrase
        in info: String => str then 1
        in warn: String => str then 2
        in error: String => str then 3
        in fatal: String => str then 4
        end
      puts str
      @logger.add(level, str)
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

  #class to handle config file and writing to it. Also copying the script and service to it's proper place
  class Config
    def initialize
      if File.exist?("/etc/dynaruby.conf")
        @config_file = File.readlines("/etc/dynaruby.conf", chomp: true)
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

    def start_installation
      !File.exist?("/etc/dynaruby.conf") ? prompt_args : config_found
    end

    def config_found
      puts "Config file already exists. Do you want to overwrite it? [y(es)/n(o)]"
      if prompt_confirmation
        prompt_args
      else
        puts "Aborting..."; abort "User aborted"
      end
    end

    def prompt_confirmation
      loop do
        answer = STDIN.gets.downcase.chomp
        return true if answer == "y" || answer == "yes"
        return false if answer == "n" || answer == "no"
        puts "Please choose either y(es) or n(o)"
      end
    end

    def prompt_args
      config = []
      LOGGER.log(info: "Let's get started setting up the config")
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
      loop do
        puts "Please input hostname number #{number_of_hostnames + 1}. Submit d to delete, or empty line to continue:"
        config << STDIN.gets.chomp
        if config.last == "" && number_of_hostnames > 0
          config.pop
          break
        elsif config.last == "d" && number_of_hostnames > 0
          puts "hostname removed."
          config.pop
          config.pop
          number_of_hostnames -= 1
        elsif config.last == "" && number_of_hostnames == 0
          puts "Please input at least one hostname"
          config.pop
        else
          number_of_hostnames += 1
        end
      end

      File.open("/etc/dynaruby.conf", "w") do |config_file|
        config.each { |line| config_file.puts(line) }
      end

      LOGGER.log(info: "Config written to /etc/dynaruby.conf")
      copy_script
      LOGGER.log(info: "Successfully installed Dynaruby!")
    end

    def copy_script
      FileUtils.copy(__FILE__, "/usr/local/sbin/dynaruby")
      LOGGER.log(info: "Dynaruby copied to /usr/local/sbin/dynaruby")
      if RUBY_PLATFORM.include?("linux")
        FileUtils.move("#{Dir.pwd}/dynaruby.service", "/etc/systemd/system/dynaruby")
        LOGGER.log(info: "dynaruby.service copied under /etc/systemd/system/dynaruby. make it executable and enable it with systemctl enable dynaruby - systemctl start dynaruby")
      elsif RUBY_PLATFORM.include?("bsd")
        FileUtils.move("#{Dir.pwd}/dynaruby.rcd", "/etc/rc.d/dynaruby")
        LOGGER.log(info: "rcd copied correctly under /etc/rc.d/dynaruby. Make it executable. Append 'pkg_scripts=dynaruby' and run rcctl enable dynaruby - rcctl start dynaruby")
      end
    end

    def download_service
      if RUBY_PLATFORM.include?("linux")
        begin
          service_raw = Net::HTTP.get_response(URI("https://raw.githubusercontent.com/dillonwreek/dynaruby/main/dynaruby.service"))
        rescue StandardError => error
          LOGGER.log(error: "Error downloading the service script: #{error}, try again?"); prompt_confirmation ? download_service : (abort "User aborted")
        end

        service_lines = service_raw.response.body.split("\n")
        service_file = File.open("#{Dir.pwd}/dynaruby.service", "w")
        service_lines.each { |line| service_file.puts(line) }
        service_file.close
        LOGGER.log(info: "Successfully downloaded the service script!")
      elsif RUBY_PLATFORM.include?("bsd")
        begin
          rcd_raw = Net::HTTP.get_response(URI("https://raw.githubusercontent.com/dillonwreek/dynaruby/main/dynaruby.rcd"))
        rescue StandardError => error
          LOGGER.log(error: "Error downloading the service script: #{error}, try again?"); prompt_confirmation ? download_service : (abort "User aborted")
        end

        rcd_lines = rcd_raw.response.body.split("\n")
        rcd_file = File.open("#{Dir.pwd}/dynaruby.rcd", "w")
        rcd_lines.each { |line| rcd_file.puts(line) }
        rcd_file.close
      end
    end

    def write_env_to_service(merged_key_iv)
      if RUBY_PLATFORM.include?("linux")
        if !File.exist?("#{Dir.pwd}/dynaruby.service")
          LOGGER.log(warn: "Service file not found. Downloading service script...")
          download_service
        end

        dynaruby_service = File.readlines("#{Dir.pwd}/dynaruby.service", chomp: true)
        dynaruby_service[5] = 'Environment="DYNARUBY_KEY=#{merged_key_iv}"'
        File.open("#{Dir.pwd}/dynaruby.service", "w") do |file|
          dynaruby_service.each { |line| file.puts(line) }
        end
      elsif RUBY_PLATFORM.include?("bsd")
        if !File.exist?("#{Dir.pwd}/dynaruby.rcd")
          LOGGER.log(warn: "rc.d script not found. Downloading rc.d script...")
          download_service
        end

        dynaruby_rcd = File.readlines("#{Dir.pwd}/dynaruby.rcd", chomp: true)
        dynaruby_rcd[8] = "export DYNARUBY_KEY=\"#{merged_key_iv}\""
        File.open("#{Dir.pwd}/dynaruby.rcd", "w") do |file|
          dynaruby_rcd.each { |line| file.puts(line) }
        end
      end
    end

    private

    def encrypt(password)
      cipher = OpenSSL::Cipher::AES.new(256, :CBC)
      cipher.encrypt
      key = OpenSSL::Random.random_bytes(32)
      iv = OpenSSL::Random.random_bytes(16)
      merged_key_iv = Base64.strict_encode64(key) + "," + Base64.strict_encode64(iv)
      write_env_to_service(merged_key_iv)
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
        LOGGER.log(fatal: "Error loading the DYNARUBY_KEY. It's probably not set. Ruby error: #{error}.."); abort "ERROR: NO DYNARUBY_KEY. CHECK THE README FOR MORE INFO"
      end
      decipher.key = Base64.strict_decode64(merged_key_iv_array[0])
      decipher.iv = Base64.strict_decode64(merged_key_iv_array[1])
      begin
        decrypted_pswd = decipher.update(Base64.decode64(password)) + decipher.final
      rescue StandardError => error
        LOGGER.log(fatal: "Error decrypting the password, DYNARUBY_KEY is set, but probably not valid"); abort "ERROR: INVALID DYNARUBY_KEY. CHECK THE README FOR MORE INFO"
      end
    end
  end

  # what will be running in the background most of the time. Send get request to ifconfig.me/ip, check if Ip changed,
  # if it did, notify NO-IP and update IP. @last_ip is nil at every restart of the script
  class Updater
    def initialize
      @last_ip = nil
    end

    #single method to fetch the body for the two get requests. * can be any argument
    def fetch_body(*)
      begin
        response = Net::HTTP.get_response(*)
      rescue StandardError => error
        LOGGER.log(error: "Error fetching the body: #{error}")
        sleep 5
        Logger.log(info: "trying again")
        fetch_body(*)
      end
      response.body
    end

    def check_ip_change(config)
      new_ip = fetch_body(URI("http://ifconfig.me/ip"))
      case @last_ip
      when nil
        @last_ip = new_ip
        LOGGER.log(info: "IP was nil. Changing to #{new_ip}"); @last_ip = new_ip; update_ip(config, new_ip)
      when new_ip
        LOGGER.log(info: "IP did not change, waiting for #{config.sleep_time_in_minutes / 60} minutes and checking again")
        sleep config.sleep_time_in_minutes; check_ip_change(config)
      else
        LOGGER.log(info: "IP changed, updating from #{@last_ip} to #{new_ip}"); @last_ip = new_ip; update_ip(config, new_ip)
      end
    end

    #NO-IP wants the request to look like this
    def update_ip(config, new_ip)
      # the hostname you want to update at the end of their api endpoint uri followed by the new ip you want to set
      url = URI("https://dynupdate.no-ip.com/nic/update?hostname=#{config.hostnames.join(" ")}&myip=#{new_ip}")

      #an authentication header with basic auth composed of the username and password in base64
      authentication = Net::HTTP::Get.new(url)
      authentication.basic_auth config.username, config.password
      authorization = Base64.strict_encode64("#{config.username}:#{config.password}")

      # an user agent which will be used to identify the client as per their requirements
      headers = { "Authorization" => "Basic #{authorization}", "User-Agent" => "Personal dynaruby/#{RUBY_PLATFORM}" }

      #What is the response from NO-IP?
      #good => IP updated
      #nochg => IP unchanged
      #nohost => Something wrong with the hostname // it can happen a few times at boot for no good reason, but then it works fine after 2 retries
      #bad auth => Something wrong with the authentication, username and/or password are wrong

      # response
      response = fetch_body(url, headers, authentication)
      if response.include?("nochg")
        LOGGER.log(info: "NO-IP parsed the request and found the IP is unchanged.")
      elsif response.include?("good")
        LOGGER.log(info: "NO-IP acknowledged the change. IP updated. Checking again in #{config.sleep_time_in_minutes / 60} minutes")
      else
        LOGGER.log(info: "Something went wrong updating the IP. The response from NO-IP was:  #{response.body}. Trying again in 15 seconds")
        sleep 15; update_ip(config, new_ip)
      end
      # call to check again
      LOGGER.log(info: "Checking again in #{config.sleep_time_in_minutes / 60} minutes")
      sleep config.sleep_time_in_minutes
      check_ip_change(config)
    end
  end

  dynaruby = Client.new
  config = Config.new
  updater = Updater.new

  LOGGER = Reporter.new

  if dynaruby.mode == "Install"
    config.start_installation
  elsif dynaruby.mode == "Update"
    updater.check_ip_change(config)
  end
end
