# Dockerizing HTCondor master, submitter, executor nodes

FROM 	   centos:7
MAINTAINER Sara Vallero <svallero@to.infn.it>

ENV 	   TINI_VERSION v0.9.0

EXPOSE  5000
EXPOSE  22

USER    root

ADD     https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /sbin/tini

COPY    htcondor-stable-rhel7.repo /etc/yum.repos.d/htcondor-stable-rhel7.repo
COPY    RPM-GPG-KEY-HTCondor /etc/pki/rpm-gpg/RPM-GPG-KEY-HTCondor

RUN	set -ex \
        && rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-HTCondor \ 
        #&& yum makecache fast \
	# CONDOR
	&& yum -y install wget procps curl epel-release openssh-clients\
 	&& chmod +x /sbin/tini \
        && yum -y install condor condor-python\ 
 	&& yum install -y python-pip && pip install supervisor supervisor-stdout \
	# ONECLIENT TODO 
	#&& apt-get install fuse -y \
	#&& wget --no-check-certificate -q https://get.onedata.org/oneclient.sh \
	#&& chmod 775 oneclient.sh \
	#&& ./oneclient.sh \
        #&& mkdir /var/log/oneclient \
	# HEALTHCHECKS (to be used with Marathon)
	&& mkdir -p /opt/health/master/ /opt/health/executor/ /opt/health/submitter/ \
	&& pip install Flask \
	# SSHD
	&& yum install -y openssh-server && mkdir -p /var/log/ssh/ && mkdir /var/run/sshd && mkdir /root/.ssh \
	# CLEAN
	&& yum -y remove python-pip \
        && yum clean all 

COPY 	supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY    condor_config /etc/condor/condor_config
COPY    master_healthcheck.py /opt/health/master/healthcheck.py
COPY    executor_healthcheck.py /opt/health/executor/healthcheck.py
COPY    submitter_healthcheck.py /opt/health/submitter/healthcheck.py
COPY 	sshd_config /etc/ssh/sshd_config
COPY    run.sh /usr/local/sbin/run.sh

# Afterwards one needs to add an HTCondor config file to limit the number of slots 

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/sbin/run.sh"]
