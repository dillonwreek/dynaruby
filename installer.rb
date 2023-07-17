#!/usr/bin/env ruby
require "fileutils"
require "io/console"
require "base64"
require "openssl"

def catch_ctrl_c
  Signal.trap("INT") { puts " Stopping..."; exit 130 } #gracefully exit
end

def start
  !File.exist?("/etc/dynaruby.conf") ? set_args : config_found
end

def config_found
  catch_ctrl_c
  puts "Config file already exists. Do you want to overwrite it? [y(es)/n(o)]"
  if yes_or_no
    set_args
  else
    puts "Aborting..."
    exit
  end
end

def yes_or_no
  catch_ctrl_c
  positive_answers = ["y", "yes"]
  negative_answers = ["n", "no"]
  result = nil
  until result == true || result == false
    @answer = gets.downcase.chomp

    #branchless way of checking for y or n + invalid input
    result = positive_answers.include?(@answer) ? true : negative_answers.include?(@answer) ? false : (puts "Please choose either y(es) or n(o) to confirm."; nil)
  end
  result
end

def set_args
  catch_ctrl_c
  puts "Let's get started"
  puts "Please input username:"
  username = gets.chomp
  puts "Please input password:"
  password = STDIN.noecho(&:gets).chomp
  puts "Please input hostname(s), tell me you're done with an empty line. Submit d to delete the last inputted hostname"
  hostnames = []
  number_of_hostnames = 1
  until hostnames.last == ""
    puts "Please input hostname number #{number_of_hostnames}:"
    hostnames << gets.chomp
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
  config = File.open("/etc/dynaruby.conf", "a")
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

def decrypt(password)
  decipher = OpenSSL::Cipher::AES.new(256, :CBC)
  decipher.decrypt
  merged_key_iv_array = ENV["DYNARUBY_KEY"].split(",")
  decipher.key = Base64.decode64(merged_key_iv_array[0])
  decipher.iv = Base64.decode64(merged_key_iv_array[1])
  decrypted_pswd = decipher.update(Base64.decode64(password)) + decipher.final
  p "decrypted_pswd = #{decrypted_pswd}"
end

def copy_script
  p "Copying Dynaruby script to /usr/local/sbin/"
  FileUtils.cp("./dynaruby.rb", "/usr/local/sbin/dynaruby")
  p "Copying Dynaruby rc.d service script to /etc/rc.d/"
  #FileUtils.cp("./rc.d", "/etc/rc.d/dynaruby")
end

def enable_service
end

copy_script
