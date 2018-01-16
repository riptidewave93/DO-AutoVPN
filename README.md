# DO-AutoVPN

DO-AutoVPN is an automatic VPN instance creation tool utilizing Digital Ocean's services.

About
-----
DO-AutoVPN uses a python script to create a Debian Droplet on DigitalOcean's infrastructure, sets up an OpenVPN server on said Droplet, and then securely returns the client configuration file to your local system. This server will also rotate the IP address used for outbound VPN connections every 24 hours using DigitalOcean's Floating IP service.

The server post-install scripts can be found in `./server`. It is also worth noting that a VPN instance that is left unused for 15 minutes will destroy itself. Note this timeout can be changed in the `./deploy.py` file by changing the Timeout variable.

Usage
-----
1. Clone repo
2. pip3 install -r requires.txt
2. run ./deploy.py
3. Connect to the VPN using the downloaded client.ovpn file

Issues
-----
* You tell me!

Future Plans
-----
  1. Generate certificates client side for additional security
  2. Enhance the flip script with more checks & failsafes
