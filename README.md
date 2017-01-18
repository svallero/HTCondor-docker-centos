# HTCondor-docker-centos
Create a dockerized HTCondor cluster based on CentOS 7. 
For a Debian based version, see DS-CNAF/HTCondor-docker-debian.
 
(OneClient is not implemented).

# Usage
Options:
          -m                    configure container as HTCondor master
          -e master-address     configure container as HTCondor executor for the given master
          -s master-address     configure container as HTCondor submitter for the given master
          -c url-to-config      config file reference from http url
          -r url-to-public-key  url to public key for ssh access to root
          -k url-to-public-key  url to public key for ssh access to unprivileged user (see -u attribute)
          -p password           user password (see -u attribute)
          -u inject user        inject a user without root privileges for submitting jobs accessing via s
sh. -k public key required -p  password optional
          -S shared secret

The "shared secret" should be the same for all containers in the cluster... clearly.
