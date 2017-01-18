#!/bin/bash
# Configure HTCondor and fire up supervisord
# Daemons for each role
MASTER_DAEMONS="COLLECTOR, NEGOTIATOR"
EXECUTOR_DAEMONS="STARTD"
SUBMITTER_DAEMONS="SCHEDD"

usage() {
  cat <<-EOF
	usage: $0 -m|-e master-address|-s master-address [-c url-to-config] [-k url-to-public-key] [-u inject user -p password -S shared-secret]
	
	Configure HTCondor role and start supervisord for this container. 
	
	OPTIONS:
	  -m                	configure container as HTCondor master
	  -e master-address 	configure container as HTCondor executor for the given master
	  -s master-address 	configure container as HTCondor submitter for the given master
	  -c url-to-config  	config file reference from http url
	  -r url-to-public-key	url to public key for ssh access to root
	  -k url-to-public-key	url to public key for ssh access to unprivileged user (see -u attribute)
	  -p password		user password (see -u attribute)
	  -u inject user	inject a user without root privileges for submitting jobs accessing via ssh. -k public key required -p  password optional
          -S shared secret
	EOF
  exit 1
}

# Syntax checks
CONFIG_MODE=
SSH_ACCESS=

# Get our options
ROLE_DAEMONS=
CONDOR_HOST=
HEALTH_CHECKS=
CONFIG_URL=
KEY_URL=
USER_KEY_URL=
USER=
PASSWORD=
while getopts ':me:s:c:r:k:p:u:S:' OPTION; do
  case $OPTION in
    m)
      [ -n "$ROLE_DAEMONS" ] && usage
      ROLE_DAEMONS="$MASTER_DAEMONS"
      CONDOR_HOST='$(FULL_HOSTNAME)'
      HEALTH_CHECK='master'
    ;;
    e)
      [ -n "$ROLE_DAEMONS" -o -z "$OPTARG" ] && usage
      ROLE_DAEMONS="$EXECUTOR_DAEMONS"
      CONDOR_HOST="$OPTARG"
      HEALTH_CHECK='executor'
    ;;
    c)
      [ -n "$CONFIG_MODE" -o -z "$OPTARG" ] && usage
      CONFIG_MODE='http'
      CONFIG_URL="$OPTARG"
    ;;
    s)
      [ -n "$ROLE_DAEMONS" -o -z "$OPTARG" ] && usage
      ROLE_DAEMONS="$SUBMITTER_DAEMONS"
      CONDOR_HOST="$OPTARG"
      HEALTH_CHECK='submitter'
    ;;
    r)
      [ -n "$KEY_URL" -o -z "$OPTARG" ] && usage
      SSH_ACCESS='yes'
      KEY_URL="$OPTARG"
    ;;  
    k)
      [ -n "$USER_KEY_URL" -o -z "$OPTARG" ] && usage
      SSH_ACCESS='yes'
      USER_KEY_URL="$OPTARG"
    ;;  
    p)
      [ -n "$PASSWORD" -o -z "$OPTARG" ] && usage
      SSH_ACCESS='yes'
      PASSWORD="$OPTARG"
    ;;  
    u)
      [ -n "$USER" -o -z "$OPTARG" ] && usage
      SSH_ACCESS='yes'
      USER="$OPTARG"
    ;;  
    S)
      [ -n "$SHARED_SECRET" -o -z "$OPTARG" ] && usage
      SHARED_SECRET="$OPTARG"
    ;;  
    *)
      usage
    ;;
  esac
done

# Additional checks
# USER KEY IS REQUIRED
if [ \( -n "$USER_KEY_URL" -a -z "$USER" \) -a \( -z "$USER_KEY_URL" -a -n "$USER" \) ]; then
  usage
fi;

# Prepare SSH access
if [ -n "$KEY_URL" -a -n "$SSH_ACCESS" ]; then
  wget -O - "$KEY_URL" > /root/.ssh/authorized_keys
fi

if [ -n "$USER" -a -n "$USER_KEY_URL" -a -n "$SSH_ACCESS" ]; then
  mkdir -p /home/$USER && useradd $USER -d /home/$USER -s /bin/bash && chown -R $USER:$USER /home/$USER/
  mkdir -p /home/$USER/.ssh 
  wget -O - "$USER_KEY_URL" > /home/$USER/.ssh/authorized_keys 
  chown -R $USER:$USER /home/$USER/.ssh
  chmod 700 /home/$USER/.ssh
  chmod 600 /home/$USER/.ssh/authorized_keys
fi;

if [ -n "$USER" -a -n "$PASSWORD" -a -n "$SSH_ACCESS" ]; then
  echo "$USER:$PASSWORD" | chpasswd 
fi;

if [ -n "$SSH_ACCESS" ]; then

  ssh-keygen -b 1024 -t rsa -f /etc/ssh/ssh_host_key
  ssh-keygen -b 1024 -t rsa -f /etc/ssh/ssh_host_rsa_key
  ssh-keygen -b 1024 -t dsa -f /etc/ssh/ssh_host_dsa_key

  cat >> /etc/supervisor/conf.d/supervisord.conf << EOL
[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
stdout_logfile=/var/log/ssh/sshd.stdout.log
stdout_logfile_maxbytes=1MB
stdout_logfile_backups=10
stderr_logfile=/var/log/ssh/sshd.stderr.log
stderr_logfile_maxbytes=1MB
stderr_logfile_backups=10
EOL

fi;

# Prepare external config
if [ -n "$CONFIG_MODE" ]; then
  wget -O - "$CONFIG_URL" > /etc/condor/condor_config
fi

# Prepare HTCondor configuration
sed -i \
  -e 's/@CONDOR_HOST@/'"$CONDOR_HOST"'/' \
  -e 's/@ROLE_DAEMONS@/'"$ROLE_DAEMONS"'/' \
  /etc/condor/condor_config

# Add shared secret to HTCondor configuration
if [ -n "$SHARED_SECRET" ]; then
  
  cat >> /etc/condor/condor_config << _EOF_
SEC_PASSWORD_FILE= /etc/condor/condorSharedSecret
SEC_DAEMON_INTEGRITY= REQUIRED
SEC_DAEMON_AUTHENTICATION= REQUIRED
SEC_DAEMON_AUTHENTICATION_METHODS= PASSWORD
SEC_CLIENT_AUTHENTICATION_METHODS= FS, PASSWORD
_EOF_
 
  condor_store_cred -f /etc/condor/condorSharedSecret -p $SHARED_SECRET
fi

# Prepare right HTCondor healthchecks
sed -i \
  -e 's/@ROLE@/'"$HEALTH_CHECK"'/' \
  /etc/supervisor/conf.d/supervisord.conf



exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
