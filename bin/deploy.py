#!/usr/bin/env python3.4
#
# DO-AutoVPN Deployment Script Example
# Created By: Chris Blake (riptidewave93)
# https://github.com/riptidewave93/DO-AutoVPN
#

import digitalocean, random, string, sys, time, pycurl

# Change this to modify the server timeout before destruction (in minutes), 0 = disabled
DESTROY_TIMEOUT = 15

# Change this to your API key to remove input prompt
DOKey = None

# Start main code
while DOKey is None:
	DOKey = input("Please enter a Ditial Ocean API key that has read and write access: ")
	if len(DOKey) < 60:
		print('Invalid entry, please try again.')
	else:
		DOKey = DOKey.replace(' ','').replace('\n','') # Remove any possible spaces or breaks from the token

# Generate random values used later
PullPort = random.randint(1000,9999) # Port we will use later to Download the client config
PullUser = ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(32)) # User used to auth for client config
PullPass = ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(64)) # Pass used to auth for client config
Hostname = 'DO-AutoVPN' + str(random.randint(0000,9999))

# Load Userdata
with open ("./userdata.template", "r") as myfile:
	UserScript = myfile.read()

# Replace placeholders with their actual value
UserScript = UserScript.replace('{PORT}', str(PullPort)).replace('{USER}', PullUser).replace('{PASS}', PullPass).replace('{DO_TOKEN}', DOKey).replace('{TIMEOUT}', DESTROY_TIMEOUT)

# Try to create VM
droplet = digitalocean.Droplet(token=DOKey,
	name=Hostname,
	region='nyc3',
	image='ubuntu-14-04-x64',
	size_slug='512mb',
	backups=False,
	ipv6=True,
	user_data=UserScript)

try:
	droplet.create()
except Exception as e:
	print('Deploy Error: ' + str(e))
	sys.exit()
else:
	print('VM Deployment Requested... waiting for build to finish.')
	# Wait for the instance to spinup
	done = 0
	while done == 0:
		actions = droplet.get_actions()
		for action in actions:
			action.load()
			# Once it shows complete, droplet is up and running
			if 'complete' in action.status:
				done = 1
				print('Build finished!');
				droplet.load() # Reload values
				InstanceIP = droplet.ip_address # parse out the IP
		time.sleep(2) # Let's not knock all day on the API
print('Sleeping to give cloudinit some time')
time.sleep(60)
print('Attempting to pull the client OpenVPN configuration file')
PullLoop = True
while PullLoop:
	try:
		with open('client.ovpn', 'wb') as f:
			c = pycurl.Curl()
			c.setopt(c.URL, 'https://' + InstanceIP + ':' + str(PullPort) + '/client.ovpn')
			c.setopt(c.WRITEDATA, f)
			c.setopt(pycurl.USERPWD, PullUser + ':' + PullPass)
			c.setopt(pycurl.CONNECTTIMEOUT, 60)
			c.setopt(c.SSL_VERIFYPEER, 0) # Allow self signed cert!
			c.perform()
			c.close()
	except Exception as e:
		print('.',end="",flush=True)
		time.sleep(10)
		continue
	else:
		PullLoop = False
print('File Downloaded! Script Complete. Use the downloaded client.ovpn to connect to your VPN. If you dont within ' + str(DESTROY_TIMEOUT) + ' minutes, the Droplet will destroy itself.')
