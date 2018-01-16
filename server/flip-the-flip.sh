#!/bin/bash

# Load in our info
APIKEY=`cat /root/.do_apikey`
DOID=`curl -s http://169.254.169.254/metadata/v1/id`
DOREGION=`curl -s http://169.254.169.254/metadata/v1/region`

# Get our current FLIP
FLIP=""
if [ "`curl -s http://169.254.169.254/metadata/v1/floating_ip/ipv4/active`" == "true" ]; then
	FLIP=`curl -s http://169.254.169.254/metadata/v1/floating_ip/ipv4/ip_address`
fi

# Reserve a new FLIP
NEWFLIP=`curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${APIKEY}" -d '{"region":"'${DOREGION}'"}' "https://api.digitalocean.com/v2/floating_ips" | jq -r '.floating_ip.ip'`

# If we have a flip, release it
if [ "${FLIP}" != "" ]; then
	# release
	curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${APIKEY}" -d '{"type":"unassign"}' "https://api.digitalocean.com/v2/floating_ips/${FLIP}/actions"
	sleep 3
	# delete
	curl -s -X DELETE -H "Content-Type: application/json" -H "Authorization: Bearer ${APIKEY}" "https://api.digitalocean.com/v2/floating_ips/${FLIP}"
fi

# Sleep a sec while we reserve
sleep 3

# Assign our new FLIP
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${APIKEY}" -d '{"type":"assign","droplet_id":'${DOID}'}' "https://api.digitalocean.com/v2/floating_ips/${NEWFLIP}/actions"

exit 0
