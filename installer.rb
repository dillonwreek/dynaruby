#THIS FILE IS NOT OK. IT SHOULD BE UPDATED TO USE THE SAME CLASSES AS DYNARUBY. I WANT THE INSTALLER TO SET THE CONFIG,
##BUT I ALSO WANT DYNARUBY TO BE ABLE TO INDEPENDANTLY UPDATE THE CONFIG FILE IN CASE IT IS DELETED OR LOST

#!/usr/bin/env ruby
require "fileutils"
require "io/console"

def start
  message = !File.exist?("/etc/dynaruby.conf") ? "Hello! We're going to set up your dynaruby installation." : "You already have a dynaruby configuration file."
end
