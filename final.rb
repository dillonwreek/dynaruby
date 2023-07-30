#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"

def catch_ctrl_c
  Signal.trap("INT") { puts " Stopping..."; exit 130 } #gracefully exit
end

module Installer
  def start_installation
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
    puts "Please input password:"
    config[4] = "password="
    config[5] = STDIN.noecho(&:gets).chomp
    config[6] = "hostnames="
    puts "Please input hostname(s), tell me you're done with an empty line. Submit d to delete the last inputted hostname"
    until config.last == ""
      config << STDIN.gets.chomp
      config.last == "d" && config.size > 5 ? (puts "hostname removed."; config.pop; config.pop) : nil
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
    FileUtils.copy("./dynaruby_aio.rb", "/usr/local/sbin/dynaruby")
    #os == "linux" ? FileUtils.copy("./dynaruby.service", "/etc/systemd/system/dynaruby.service") : os == "bsd" ? FileUtils.copy("./dynaruby.rcd", "/etc/rc.d/dynaruby") : nil

    #puts "Successfully installed Dynaruby!" and exit
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

  def write_env_to_shell(merged_key_iv)
    bashrc = File.open("#{Dir.home}/.bashrc", "a")
    bashrc.write "export DYNARUBY_KEY='#{merged_key_iv}'\n"
    bashrc.close
  end

  def os
    case RUBY_PLATFORM
    when /darwin/
      "mac"
    when /linux/
      "linux"
    when /bsd/
      "bsd"
    end
  end
end

class Config
  include Installer

  def initialize
    File.exist?("/etc/dynaruby.conf") ? @config_file = File.readlines("/etc/dynaruby.conf").map(&:chomp) : @config_file = false
    @last_ip = nil
  end

  def sleep_time
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

  private

  def decrypt(encrypted_password)
    decipher = OpenSSL::Cipher::AES.new(256, :CBC)
    decipher.decrypt
    merged_key_iv_array = ENV["DYNARUBY_KEY"].split(",")
    decipher.key = Base64.decode64(merged_key_iv_array[0])
    decipher.iv = Base64.decode64(merged_key_iv_array[1])
    decrypted_pswd = decipher.update(Base64.decode64(encrypted_password)) + decipher.final
  end
end

class Updater < Config
  def check_ip
    catch_ctrl_c
    begin
      new_ip = Net::HTTP.get(URI("http://ifconfig.me/ip"))
    rescue StandardError => error
      puts "Error: #{error}.. Waiting for 1 minute and checking again"
      sleep 60
      check_ip
    end

    @last_ip == nil ? (puts "IP was nil. Changing to #{new_ip}"; @last_ip = new_ip; update_ip(new_ip)) : @last_ip != new_ip ? (puts "IP changed from #{@last_ip} to #{new_ip}"; update_ip(new_ip)) : @last_ip == new_ip ? (puts "IP unchanged, sleeping for #{sleep_time} minutes and checking again"; sleep(sleep_time * 60); check_ip) : nil
  end

  def update_ip(new_ip)
    # https request form stuff
    url = URI("https://dynupdate.no-ip.com/nic/update?hostname=#{hostnames.join(" ")}&myip=#{new_ip}")
    authentication = Net::HTTP::Get.new(url)
    authentication.basic_auth username, password
    authorization = Base64.encode64("#{username}:#{password}")
    headers = { "Authorization" => "Basic #{authorization}", "User-Agent" => "Personal dynaruby/openbsd-7.3" }

    # response
    begin
      response = Net::HTTP.get_response(url, headers, authentication)
    rescue StandardError => error
      puts "Error: #{error}... Waiting for 1 minute and trying again"
      sleep 60
      update_ip(new_ip)
    end
    #parse response
    response.body.include?("nochg") ? (puts "IP unchanged") : response.body.include?("good") ? (puts "IP updated") : (puts "Something went wrong updating IP"; puts response.body)

    # call to check again
    check_ip
  end
end

installation_keywords = ["-i", "--install"]
dynaruby = Updater.new
installation_keywords.include?(ARGV[0]) ? (puts "Starting installation..."; dynaruby.start_installation) : nil
File.exist?("/etc/dynaruby.conf") ? (puts "Starting updater..."; dynaruby.check_ip) : (puts "Config not found..   Starting installation..."; dynaruby.start_installation)
dyn_key = `echo $DYNARUBY_KEY`
`DYNARUBY_KEY=#{dyn_key} ./final.rb`
