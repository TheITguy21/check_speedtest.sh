# check_speedtest.sh
A plugin to check available bandwidth from a Nagios server using new speedtest cli package by Ookla.

Based on old check_speedtest-cli.sh by John Witts : https://github.com/jonwitts/nagios-speedtest

Please report any issue here : https://github.com/TheITguy21/check_speedtest.sh/issues

# Prerequisites
The following packages must be present on your system for the script to work:
- bc
- speedtest cli by Ookla https://www.speedtest.net/apps/cli

  ⚠ Before installing "speedtest", you should first read Ookla's "EULA", "Terms of Use" and "Privacy Policy", and make sure you're ok with it
  - Ookla EULA: https://www.speedtest.net/about/eula
  - Ookla Terms of Use: https://www.speedtest.net/about/terms
  - Ookla Privacy Policy: https://www.speedtest.net/about/privacy
  
  Also, you should be aware the installation of speedtest by Ookla through their script "script.deb.sh" does the following (amongst others):
  - runs the "apt-get update" command
  - installs the gnupg package
  - installs the debian-archive-keyring package
  - installs the apt-trasport-https
  - creates a debian repository configuration file in /etc/apt/sources.list.d/ookla_speedtest-cli
  - creates a GPG keyring and imports keys from https://packagecloud.io/ookla/speedtest-cli/gpgkey
  
  🙏🏻 Many thanks to RocketSloooth aka Diegone for raising this in the Issues section (more details here: https://github.com/TheITguy21/check_speedtest.sh/issues/2) 

# Disclaimer
I am not affiliated with Ookla nor my work is sponsored by Ookla in ANY ways.

Also, I assume you take your own responsability with the dependencies installation on your system. 
I won't provide any support for this dependencies or any side effect their installation may have on your system.
You're supposed to know what you're doing ! 🙂
