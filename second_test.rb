#!/usr/bin/env ruby
require "uri"
require "base64"
require "openssl"
require "net/http"

def send_request
  hostname = "rails.ddns.net"
  myip = Net::HTTP.get_response(URI("http://ifconfig.me/ip")).body.chomp
  username = "dillonwreek@gmail.com"
  password = "password"

  authorization = Base64.encode64("#{username}:#{password}")
  agent = "Personal dynaruby/openbsd"

  headers = { "Authorization" => "Basic #{authorization}", "User-Agent" => "Personal dynaruby/openbsd" }
  url = URI("https://dynupdate.no-ip.com/nic/update?hostname=#{hostname}&myip=#{myip}")

  p url
  req = Net::HTTP::Get.new(url)
  req.basic_auth username, password
  response = Net::HTTP.get_response(url, headers, req)
  p response.body
end

send_request
