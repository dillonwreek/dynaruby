#!/usr/bin/env ruby

RUBY_PLATFORM.include?("darwin") ? "mac" : RUBY_PLATFORM.include?("linux") ? "linux" : RUBY_PLATFORM.include?("bsd") ? "bsd" : nil
