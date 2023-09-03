#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"
require "logger"

module Dynaruby
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

  LOGGER = Reporter.new

  LOGGER.log(info: "Starting dynaruby")
  LOGGER.log(warn: "uh oh")
  LOGGER.log(error: "oh no")
  LOGGER.log(fatal: "oh noes")
end
