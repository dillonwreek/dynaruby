#!/usr/bin/env ruby

require "fileutils"
require "io/console"
require "base64"
require "openssl"
require "net/http"
require "uri"
require "logger"

module Dynaruby
  class Client
    def initialize(config)
      if ARGV[0] == "-install" || ARGV[0] == "-i" || config.nil?
        @mode = "Install"
      elsif ARGV[0] == "-report" || ARGV[0] == "-r"
        @mode = "Report"
      elsif ARGV.empty?
        @mode = "Update"
      end
    end

    def mode
      @mode
    end

    def grab_lines_from_log_lines(check_for, min_time, log_lines)
      lines_to_print = []
      if min_time.nil?
        until check_for.include?(log_lines.last[0])
          log_lines.pop
        end
        lines_to_print = log_lines.last
      elsif min_time == 0
        log_lines.each do |line|
          if check_for.include?(line[0])
            lines_to_print << line
          end
        end
      else
        square_brackets = []
        log_lines.each do |line|
          square_brackets == line.scan(/\[(.*?)\]/).first
          extracted_date = square_brackets.first.split("#").first.strip
          if extracted_date >= min_time
            if check_for.include?(line[0])
              lines_to_print << line
            end
          end
        end
      end
      lines_to_print
    end

    def define_level_to_search
      if ARGV[1] == "-info" || ARGV[1] == "-i"
        check_for = "I"
      elsif ARGV[1] == "-warnings" || ARGV[1] == "-w"
        check_for = "W"
      elsif ARGV[1] == "-errors" || ARGV[1] == "-e"
        check_for = ["E", "F"]
      elsif ARGV[1] == "-fatal" || ARGV[1] == "-f"
        check_for = "F"
      elsif ARGV[1] == "-errors--strict" || ARGV[1] == "-es"
        check_for = "E"
      elsif ARGV[1] == "-ip--update" || ARGV[1] == "-good"
        check_for = "IP updated"
      elsif ARGV[1] == "-ip--unchanged" || ARGV[1] == "-nochg"
        check_for = "IP is unchanged"
      elsif ARGV[1] == "-api--error" || ARGV[1] == "-api"
        check_for = "The response from NO-IP was:"
      end
    end

    def calculate_requested_timeline
      current_time = Time.now
      if ARGV[2].match?(/\A-?\d+\Z/)
        inputted_hours = ARGV[2].to_i
        min_time = current_time - (inputted_hours * 60 * 60)
      elsif ARGV[2] == "-day" || ARGV[2] == "-d"
        min_time = current_time - (24 * 60 * 60)
      elsif ARGV[2] == "-last" || ARGV[2] == "-l"
        min_time = nil
      elsif ARGV[2] == "-all" || ARGV[2] == "-a"
        min_time = 0
      end
    end

    def pretty_print(lines_to_print, min_time)
      if min_time.nil?
        p "last requested message: \n #{lines_to_print}"
      elsif min_time == 0
        p "all requested messages:"
        lines_to_print.each do |line|
          p line
        end
      else
        p "requested timeline: from #{min_time} to #{Time.now}"
        lines_to_print.each do |line|
          p line
        end
      end
    end

    def parse_log
      check_for = define_level_to_search
      log_lines = File.readlines("/var/log/dynaruby.log", chomp: true)
      min_time = calculate_requested_timeline
      lines_to_print = grab_lines_from_log_lines(check_for, min_time, log_lines)

      pretty_print(lines_to_print, min_time)
    end
  end

  config = "hello"
  dynaruby = Client.new(config)
  if dynaruby.mode == "Report"
    dynaruby.parse_log
  end
end
