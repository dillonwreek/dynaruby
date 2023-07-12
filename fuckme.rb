#!/usr/bin/env ruby
require "base64"
require "openssl"

def create_key
  key = OpenSSL::Random.random_bytes(32)
  iv = OpenSSL::Random.random_bytes(16)
  p "key: #{key}"
  cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
  cipher.encrypt
  cipher.key = key
  cipher.iv = iv
  data = gets.chomp

  encrypted = cipher.update(data) + cipher.final
  p "encrypted: #{encrypted}"

  encoded = Base64.encode64(encrypted)
  p "encoded: #{encoded}"

  encoded_key = Base64.encode64(key)
  p "encoded_key: #{encoded_key}"

  decoded_key = Base64.decode64(encoded_key)
  p "decoded_key: #{decoded_key}"

  encoded_iv = Base64.encode64(iv)
  p "encoded_iv: #{encoded_iv}"

  decoded_iv = Base64.decode64(encoded_iv)
  p "decoded_iv: #{decoded_iv}"

  merged_key = encoded_key + "," + encoded_iv
  merged_array = merged_key.split(",")
  p "merged_key: #{merged_key}"

  decoded = Base64.decode64(encoded)
  p "decoded: #{decoded}"

  decoded_from_merge_key = Base64.decode64(merged_array[0])
  p "decoded_from_merge_key: #{decoded_from_merge_key}"
  decoded_from_merge_iv = Base64.decode64(merged_array[1])
  p "decoded_from_merge_iv: #{decoded_from_merge_iv}"
end

def decrypt_password
  cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
  cipher.decrypt
  cipher.key = decoded_key
  cipher.iv = decoded_iv
  decrypted = cipher.update(decoded) + cipher.final
  p "decrypted: #{decrypted}"
end

create_key
