#!/usr/bin/env ruby
require "openssl"
require "openssl"
require "uri"
require "base64"
require "json"

def encrypt
  cipher = OpenSSL::Cipher::AES.new(256, :CBC)
  cipher.encrypt
  key = OpenSSL::Random.random_bytes(32)
  iv = OpenSSL::Random.random_bytes(16)
  merged_key_iv = Base64.encode64(key) + "," + Base64.encode64(iv)
  keys_file = File.open("/etc/keys", "w")
  keys_file.write(merged_key_iv)
  keys_file.close
  pswd = gets.chomp
  p "merged key iv = #{merged_key_iv}"
  cipher.key = key
  cipher.iv = iv
  encrypted_pswd = cipher.update(pswd) + cipher.final
  encoded_pswd = Base64.encode64(encrypted_pswd)
  pswd_file = File.open("/etc/pswd", "w")
  pswd_file.write(encoded_pswd)
  pswd_file.close
end

def decrypt
  decipher = OpenSSL::Cipher::AES.new(256, :CBC)
  decipher.decrypt
  merged_key_iv = File.open("/etc/keys", "r").read
  merged_key_iv_array = merged_key_iv.split(",")
  key = Base64.decode64(merged_key_iv_array[0])
  p "key = #{key}"
  iv = Base64.decode64(merged_key_iv_array[1])
  p "iv = #{iv}"
  decipher.key = key
  decipher.iv = iv
  encrypted_pswd = Base64.decode64(File.readlines("/etc/pswd").first)
  decrypted_pswd = decipher.update(encrypted_pswd) + decipher.final
  puts decrypted_pswd
end

encrypt
decrypt
