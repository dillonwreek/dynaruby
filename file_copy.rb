#!/usr/bin/env ruby
require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"

p __FILE__

FileUtils.copy(__FILE__, "file_copy_copy.rb")
