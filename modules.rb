#!/usr/bin/env ruby

class Updater
  extend Config

  def some_method
    p "hello"
    @config.some_other_method
  end
end

class Config
  def initialize
    p "Initializing"
    @config = [1, 2, 3]
  end

  def some_other_method
    p "config #{@config[0]}"
  end
end

@config = Config.new

@config.some_method
