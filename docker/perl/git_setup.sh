#!/bin/sh
hostip=$(ip route show | awk '/default/ {print $3}')
mkdir -m 700 /root/.ssh
cd /root/.ssh
mv /init/ssh-key nhs-git
cat >config <<__EOF__
Host docker-host
    HostName $hostip
    User nhs-git
    IdentityFile /root/.ssh/nhs-git
__EOF__
chmod 600 *
ssh-keyscan -H $hostip >> known_hosts
git config --global user.name root
git config --global user.email root@nhs_perl
