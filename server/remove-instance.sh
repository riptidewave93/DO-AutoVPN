#!/bin/bash
#
# Digital Ocean instance remove script
# By Chris Blake (chrisrblake93@gmail.com)
#
mkdir -p /var/log/DO-AutoVPN
exec > >(tee /var/log/DO-AutoVPN/terminate.log)
exec 2>&1

DO_TOKEN=$(cat /root/.do_apikey)
INSTANCE_ID=$(curl -s http://169.254.169.254/metadata/v1/id)

REMOVE_TIMEOUT=$1

if [ $REMOVE_TIMEOUT -eq 0 ]
then
	echo "Timeout set to 0, killing script!"
	exit 0
fi

# Always run as we want to self-destroy when we are timed out
echo "Starting Termination Daemon"
connectcount=0
while true; do
	echo Connect count is $connectcount
	# Is anyone connected?
	if [ $(netstat -n | grep -e ESTABLISHED | grep 443 | wc -l) -lt 1 ]
	then
		echo 'No user connected! Ticking Counter'
		let "connectcount += 1"
		sleep 60
	else
		echo 'User is connected! Counter reset'
		connectcount=0
		sleep 60
	fi
	if [ $connectcount -gt $REMOVE_TIMEOUT ]
	then
		# Get our current FLIP
		FLIP=""
		if [ "`curl -s http://169.254.169.254/metadata/v1/floating_ip/ipv4/active`" == "true" ]; then
			FLIP=`curl -s http://169.254.169.254/metadata/v1/floating_ip/ipv4/ip_address`
		fi

		echo 'Threshold met, terminating self...'

		# If we had a FLIP, nuke it
		if [ "${FLIP}" != "" ]; then
			# release
			curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $DO_TOKEN" -d '{"type":"unassign"}' "https://api.digitalocean.com/v2/floating_ips/$FLIP/actions"
			sleep 3
			# delete
			curl -s -X DELETE -H "Content-Type: application/json" -H "Authorization: Bearer $DO_TOKEN" "https://api.digitalocean.com/v2/floating_ips/$FLIP"
			sleep 6
		fi

		curl -s -X DELETE -H 'Content-Type: application/json' -H "Authorization: Bearer $DO_TOKEN" "https://api.digitalocean.com/v2/droplets/$INSTANCE_ID"
		sleep 60 # We will die, otherwise we wait and loop back around
	fi
done
