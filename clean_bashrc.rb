#!/usr/bin/env ruby
require "fileutils"
# Read all lines from the file into an array
bashrc = File.readlines("#{Dir.home}/.bashrc")

# Remove the lines that start with the key
bashrc.reject! { |line| line.start_with?("export DYNARUBY_KEY=") }

# Write the remaining lines back to the file
File.open("#{Dir.home}/.bashrc", "w") do |file|
  bashrc.each { |line| file.puts(line) }
end
