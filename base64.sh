#!/usr/bin/bash

set -e
set -x

export PATH=/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin

## set hostname. It is no need to reboot.
if mdata-get zcloud_hostname
then
  LNAME=`mdata-get zcloud_hostname`
  if [ ! "`hostname`" == "$LNAME" ] ; then sm-set-hostname ${LNAME} ; fi
fi

## Set localzone and force reboot
if mdata-get timezone
then
  LZONE=`mdata-get timezone`
else
  LZONE=Japan
fi
if [ ! "$TZ" == "$LZONE" ] ; then sm-set-timezone ${LZONE} && reboot ; fi


MDATA_WRAPPER=001
MDATA_USERSCRIPT=/var/svc/mdata-user-script
MDATA_USERDATA=/var/svc/mdata-user-data
CHEF_REPOS=/usr/local/zcloud-application

## add mdata-wapper script to cron
## Notice: this block must keep on top to retry fetch cyclically.

if ! exists /opt/local/sbin/mdata_wrapper_${MDATA_WRAPPER}.sh ; then
  cat <<"EOL" > /opt/local/sbin/mdata_wrapper_${MDATA_WRAPPER}.sh
#!/usr/bin/bash
export PATH=/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin
sleep `expr $$ % 60`
svcadm restart mdata:fetch
if svcs mdata:fetch | grep -q maintenance  ; then svcadm clear mdata:fetch ;fi
sleep 2
svcadm restart mdata:execute
if svcs mdata:execute | grep -q maintenance  ; then svcadm clear mdata:execute ;fi
EOL

  chmod u+x /opt/local/sbin/mdata_wrapper_${MDATA_WRAPPER}.sh
  ln -fs /opt/local/sbin/mdata_wrapper_${MDATA_WRAPPER}.sh /opt/local/sbin/mdata_wrapper.sh
fi

if ! grep -q -x "## ZCloud-Application" /var/spool/cron/crontabs/root
then
  cat << "EOL" >> /var/spool/cron/crontabs/root
## ZCloud-Application
0,10,20,30,40,50 * * * * /opt/local/sbin/mdata_wrapper.sh
EOL
svcadm restart cron
svcadm enable postfix

cat /var/svc/log/smartdc-mdata\:execute.log | mailx uchiyamano@firstserver.co.jp
fi


# install joyent_attr_plugin
if [ ! -f /opt/local/etc/ohai/plugins/joyent.rb ] ; then
  install -d /opt/local/etc/ohai/plugins -m 0755
  curl -skf -o /opt/local/etc/ohai/plugins/joyent.rb https://raw.github.com/ZCloud-Firstserver/ohai_plugin_joyent/master/plugins/joyent.rb
fi

## install chef-solo
if [ ! -f /opt/local/bin/chef-solo ] ; then

  pkgin -y install gcc47 scmgit-base gmake ruby193-base ruby193-yajl ruby193-nokogiri ruby193-readline pkg-config

## for smf cookbook
  pkgin -y install libxslt

## install chef
  gem update --system
  gem install --no-ri --no-rdoc bundler
  gem install --no-ri --no-rdoc ohai
  gem install --no-ri --no-rdoc json
  gem install --no-ri --no-rdoc chef
  gem install --no-ri --no-rdoc rb-readline

  cat /var/svc/log/smartdc-mdata\:execute.log | mailx uchiyamano@firstserver.co.jp
fi



## get attribute from metadata-api

_mdata_check(){
  if ! mdata-get $1 ; then echo "ERROR_EXIT: missing metadata $1" ; exit 1 ; fi
  export $2="`mdata-get $1`"
}

_mdata_check zcloud_app Z_APP
_mdata_check zcloud_app_repo Z_APP_REPO


## clone or pull application repositoly to local

if [ ! -d ${CHEF_REPOS} ] ; then
  git clone ${Z_APP_REPO} ${CHEF_REPOS}
  cat /var/svc/log/smartdc-mdata\:execute.log | mailx uchiyamano@firstserver.co.jp
else
  cd ${CHEF_REPOS}
  git pull
fi

## execute chef-solo

chef-solo -j ${MDATA_USERDATA} -c ${CHEF_REPOS}/solo.rb -o "role[${Z_APP}]"
cat /var/svc/log/smartdc-mdata\:execute.log | mailx uchiyamano@firstserver.co.jp
