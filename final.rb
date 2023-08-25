#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"

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

  def start_installation
    !File.exist?("/etc/dynaruby.conf") ? set_args : config_found
  end

  def config_found
    puts "Config file already exists. Do you want to overwrite it? [y(es)/n(o)]"
    if yes_or_no
      set_args
    else
      puts "Aborting..."; exit 130
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
    config[]
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
    #..

    puts "Please input the frequency of the check for an ip change in minutes:"
    config[0] = "time="
    config[1] = STDIN.gets.chomp.to_i
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
      p "Please input hostname number #{number_of_hostnames + 1}. Submit d to delete, or empty line to continue:"
      config << STDIN.gets.chomp
      if config.last == "d" && config.size > 5
        puts "hostname removed."
        config.pop
        config.pop
        number_of_hostnames -= 1
      end
    end
    config.pop

    config_file = File.open("/etc/dynaruby.conf", "w")
    config.each do |arg|
      config_file.write("#{arg}\n")
    end
    config_file.close
    puts "Config written to /etc/dynaruby.conf"
    copy_script
  end

  def copy_script
    puts "Copying script to /usr/local/bin"
    File.exist?("/usr/local/sbin/dynaruby") ? FileUtils.rm("/usr/local/sbin/dynaruby") : nil
    FileUtils.copy(__FILE__, "/usr/local/sbin/dynaruby")
    p "Successfully installed Dynaruby! The program will now install the appropriate service files"
    copy_service
  end

  def write_env_to_service(os)
    if os == "linux"
      p "merged_key_iv: #{merged_key_iv}"
      !File.exist?("#{Dir.pwd}/dynaruby.service") ? download_service_script : nil
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
    if os == "linux"
      if File.exist?("#{Dir.pwd}/dynaruby.service")
        FileUtils.copy("#{Dir.pwd}/dynaruby.service", "/etc/systemd/system/dynaruby.service")
      else
        p "dynaruby.service not found, want to download it? [y(es)/n(o)]"
        yes_or_no ? download_service(os) : (puts "Aborting..."; exit 130)
      end
    elsif os == "bsd"
      if File.exist?("#{Dir.pwd}/dynaruby.rcd")
        FileUtils.copy("#{Dir.pwd}/dynaruby.rcd", "/etc/rc.d/dynaruby")
      else
        p "dynaruby.rcd not found, want to download it? [y(es)/n(o)]"
        yes_or_no ? download_service(os) : (puts "Aborting..."; exit 130)
      end
    end
  end

  def download_service(os)
    if os == "linux"
      begin
        service_raw = Net::HTTP.get_response(URI("https://raw.githubusercontent.com/dillonwreek/dynaruby/main/dynaruby.service"))
      rescue StandardError => error
        puts "Error downloading the service script: #{error}, try again?"; yes_or_no ? download_service : (puts "Aborting..."; exit 130)
      end
      service_file = File.open("#{Dir.pwd}/dynaruby.service", "w")
    elsif os == "bsd"
      begin
        service_raw = Net::HTTP.get_response(URI("https://raw.githubusercontent.com/dillonwreek/dynaruby/main/dynaruby.rcd"))
      rescue StandardError => error
        puts "Error downloading the service script: #{error}, try again?"; yes_or_no ? download_service : (puts "Aborting..."; exit 130)
      end
      service_file = File.open("#{Dir.pwd}/dynaruby.rcd", "w")
    end
    service_lines = service_raw.response.body.split("\n")
    service_lines.each { |line| service_file.puts(line) }
    service_file.close
    puts "Successfully downloaded the service script!"
    copy_service
  end
end
