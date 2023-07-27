#!/usr/bin/env ruby
module InstallationManager
  def os
    case RUBY_PLATFORM
    when /darwin/
      "mac"
    when /linux/
      "linux"
    when /bsd/
      "bsd"
    end
  end
end
