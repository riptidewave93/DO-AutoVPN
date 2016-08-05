#!/bin/bash
#
# Digital Ocean instance remove script
# By Chris Blake (chrisrblake93@gmail.com)
#
exec > >(tee tee /var/log/DO-AutoVPN/terminate.log)
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
		echo 'Threshold met, terminating self...'
		curl -X DELETE -H 'Content-Type: application/json' -H "Authorization: Bearer $DO_TOKEN" "https://api.digitalocean.com/v2/droplets/$INSTANCE_ID"
		sleep 60 # We will die, otherwise we wait and loop back around
	fi
done
