#!/usr/bin/env ruby

bashrc = File.open("#{Dir.home}/.bashrc", "a")
gen_key = rand(0..16).to_s
bashrc.write "export SOME_KEY='#{gen_key}'\n"
bashrc.close
`/usr/bin/bash -c "source /root/.bashrc"`

key = `echo $SOME_KEY`

p "key = #{key}"
