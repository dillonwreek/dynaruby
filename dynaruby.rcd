#!/bin/sh

daemon="/usr/local/sbin/dynaruby"
name="dynaruby"
rcvar=${name}_enable

load_rc_config $name

start_cmd="${name}_start"
stop_cmd=":"

dynaruby_start()
{
    echo "Starting ${name}."
    env DYNARUBY_KEY=1234 ${daemon}
}

run_rc_command "\$1"
