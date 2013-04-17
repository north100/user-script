#!/usr/bin/bash

set -e
set -x

## set specific PATH
if [ -f /etc/product ]
then
  SM_VERS=`grep "^Image" /etc/product | awk '{print $3}'`
  case "$SM_VERS" in
    1.8.?)
      export PATH=/opt/local/gnu/bin:/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin
      ;;
    *)
      export PATH=/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin
      ;;
  esac
fi

## Current state of povisioning
CURRENTSTATE=initalize
COMPLATEFILE=/var/svc/zcloud_success
MAILFLAG=true
T_MAILBODY="/tmp/$(basename $0).$$.tmp"
touch $T_MAILBODY


_finalize() {
  EXITCODE=$?
  cat <<EOL >> $T_MAILBODY
Hi,

This is zcloud application automator.

My ipaddress is $IPADDRESS.
Last state is $CURRENTSTATE and exit status is $EXITCODE.

EOL
  echo >> $T_MAILBODY
  echo "========== tail of metadata-execute log" >> $T_MAILBODY
  tail /var/svc/log/smartdc-mdata\:execute.log >> $T_MAILBODY
  if $MAILFLAG
  then
    cat $T_MAILBODY | mailx -s "Zcloud Norify from `hostname`" $MAILTO
  fi
  rm $T_MAILBODY
  exit 0
}

trap _finalize 0

## shared functions
_smf_enabler() {
  if svcs "$1" | grep -q disabled  ; then svcadm enable "$1" ;fi
  if svcs "$1" | grep -q maintenance  ; then svcadm clear "$1" ;fi
}

_get_addr_by_if() {
  ipadm show-addr "$1" -p -o ADDR
}

_mdata_check(){
  if ! mdata-get $1 ; then echo "ERROR_EXIT: missing metadata $1" ; exit 1 ; fi
  export $2="`mdata-get $1`"
}

# postfix must be running.
_smf_enabler postfix

MAILTO=""
## Set localzone and force reboot
if mdata-get zcloud_notify_to
then
  MAILTO=`mdata-get zcloud_notify_to`
else
  MAILFLAG=false
fi

###
### prepare section
###

CURRENTSTATE=setup_host

IPADDRESS=`_get_addr_by_if net0/_a`

## set hostname. It is no need to reboot.
if mdata-get zcloud_hostname
then
  LNAME=`mdata-get zcloud_hostname`
  if [ ! "`hostname`" == "$LNAME" ] ; then sm-set-hostname ${LNAME} ; fi
fi

## Set localzone and force reboot
if mdata-get zcloud_timezone
then
  LZONE=`mdata-get zcloud_timezone`
else
  LZONE=Japan
fi
if [ ! "$TZ" == "$LZONE" ] ; then MAILFLAG=false ; sm-set-timezone ${LZONE} && reboot ; fi

###
### main section
###

MDATA_WRAPPER=001
MDATA_USERSCRIPT=/var/svc/mdata-user-script
MDATA_USERDATA=/var/svc/mdata-user-data
CHEF_REPOS=/usr/local/zcloud-application

## add mdata-wapper script to cron
## Notice: this block must keep on top to retry fetch cyclically.


if ! exists /opt/local/sbin/mdata_wrapper_${MDATA_WRAPPER}.sh ; then
  CURRENTSTATE=setup_wrapper
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
  CURRENTSTATE=setup_cronjob
  cat << "EOL" >> /var/spool/cron/crontabs/root
## ZCloud-Application
0,10,20,30,40,50 * * * * /opt/local/sbin/mdata_wrapper.sh
EOL
svcadm restart cron
fi


# install joyent_attr_plugin
if [ ! -f /opt/local/etc/ohai/plugins/joyent.rb ] ; then
  CURRENTSTATE=setup_ohai_plugin
  install -d /opt/local/etc/ohai/plugins -m 0755
  curl -skf -o /opt/local/etc/ohai/plugins/joyent.rb https://raw.github.com/ZCloud-Firstserver/ohai_plugin_joyent/master/plugins/joyent.rb
fi

## install chef-solo
if [ ! -f /opt/local/bin/chef-solo ] ; then
  CURRENTSTATE=setup_chef-solo

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
fi

## install cucumber
if [ ! -f /opt/local/bin/cucumber ] ;then
  gem install --no-ri --no-rdoc rspec
  gem install --no-ri --no-rdoc cucumber
  gem install --no-ri --no-rdoc pg
fi

## get attribute from metadata-api

_mdata_check zcloud_app Z_APP
_mdata_check zcloud_app_repo Z_APP_REPO


## clone or pull application repositoly to local

if [ ! -d ${CHEF_REPOS} ] ; then
  CURRENTSTATE=initalize_git_repository
  git clone ${Z_APP_REPO} ${CHEF_REPOS}
else
  CURRENTSTATE=update_git_repository
  cd ${CHEF_REPOS}
  git pull
fi


## switch branch of application_desknets repository
cd ${CHEF_REPOS};
if mdata-get zcloud_dneo_branch
then
  DNEO_BRANCH=`mdata-get zcloud_dneo_branch`
  CURRENT_BRANCH=`git branch | egrep ${DNEO_BRANCH}`
  echo "${CURRENT_BRANCH}"
  if ${CURRENT_BRANCH}
  then
    git checkout origin/${DNEO_BRANCH} -b ${DNEO_BRANCH}
  else
    git checkout ${DNEO_BRANCH}
  fi
else
  git checkout master
fi


## execute chef-solo
CURRENTSTATE=execute_chef-solo

if chef-solo -j ${MDATA_USERDATA} -c ${CHEF_REPOS}/solo.rb -o "role[${Z_APP}]"
then
  CURRENTSTATE=running
  if [ -f $COMPLATEFILE ]
  then
    MAILFLAG=false
  else
    touch $COMPLATEFILE
  fi
else
  CURRENTSTATE=failure_chef-solo
fi


exit 0
