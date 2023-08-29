Hello. I'm learning Ruby and my OpenBSD laptop was having problems with no-ip duc; so I decided to write my own, thus: <br> <strong> Dynaruby, a noip client written in Ruby <strong>

Note: I don't know exactly how "slower" it will be than a pure sh client, but it's good enough and mainly just for fun <br>

Instructions: <br>
1. Clone the repository
2. Enter the directory and set `dynaruby_aio.rb` as executable with `chmod +x ./dynaruby_aio.rb`
3. Run `dynaruby_aio.rb` as root and follow the on-screen instructions.
4. <strong> For systems with systemd, the script will automatically write the enviroment variable to the service script and will automatically copy it under `/etc/systemd/system/dynaruby`. Please make it executable and run: <br>`systemctl enable dynaruby` and `systemctl start dynaruby` <strong>
5. <strong> For systems without systemd, you can set a cron job to start dynaruby at boot: <br>
  For OpenBSD: <br>
  - Run `crontab -e` as root. This will let you modify the crontab with your default editor.<br>
  - append `@reboot DYNARUBY_KEY="YOUR=,KEY==" /path/to/ruby/ /usr/local/sbin/dynaruby`
  - you can know where Ruby is located with `which ruby`. It usually is `/usr/local/bin/ruby`
  - Substitute `"YOUR=,KEY=="` with the appropriate key given to you during the set-up. 
  - if you lose your key, you will need to run `dynaruby -i` as root to create a new config file and generate a new key. They key is not stored if not as an env variable for safety reasons
  - reboot your machine to start the script 
  <strong>
  6. You can check for logs in `/var/log/dynaruby.log`<br>
  <br>

## FAQ

**Q: Why do you need DYNARUBY_KEY?, What is it exactly?**<br>
**A:** DYNARUBY_KEY is a merged string separated by a comma. It's the base64 encoding of the key and iv generated when encrypting the password with OpenSSL. It will be used by Dynaruby to decript the password that lives your config file in `/etc/dynaruby.conf`. This way you won't have the password stored as cleartext.

**Q: Why don't you use rc.d instead of cron for OpenBSD?**<br>
**A:** I have a problem where the intended way to pass the variable to the rc.d just won't work for me. If you know how to programmatically set the env variable like I'm doing for systemd, please create a PR

**Q: Why do I need to run it as root?**<br>
**A:** I do for simplicity, but you don't. By setting the appropriate permissions for the config file and log file, you could run the program as a non-privileged user. Remember to modify the systemd service file to include the appropriate user for the daemon.


