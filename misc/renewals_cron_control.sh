#!/bin/bash

# This script is used by Keepalived to notify all Load Balancer nodes
# in the cluster of their current STATE, i.e. whether current host is
# a "MASTER" or a "BACKUP". When the STATE file changes to "BACKUP" in
# a given host all renewals commands are interrupted, thus preventing
# multiple hosts from running renewals (via the CRON)
#
# This script should be located at `/usr/local/bin/` in each of the
# Load Balancer hosts.
#
# Example Keepalived config in the Load Balancers would look like this:
#
#  vrrp_instance CRON {
#    state MASTER
#    interface ens10
#    virtual_router_id <ID>
#    priority 100
#    advert_int 1
#    notify /usr/local/bin/renewals_cron_control.sh
#    unicast_peer {
#      <IP_ADDRESS>
#    }
#  }

# The path to the lock file
LOCK_FILE="/var/run/renewals_cron.lock"
STATE=""

if [[ "$1" == "MASTER" ]]; then
    STATE="MASTER"
elif [[ "$1" == "BACKUP" ]]; then
    STATE="BACKUP"
elif [[ "$1" == "FAULT" ]]; then
    STATE="FAULT"
fi

echo "$STATE" > "$LOCK_FILE"

# Change the owner of the lock file to 'haproxy' and make it readable
chown haproxy "$LOCK_FILE"
chmod 644 "$LOCK_FILE"
