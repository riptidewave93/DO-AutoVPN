# DO-AutoVPN

DO-AutoVPN is an automatic VPN instance creation tool utilizing Digital Ocean's services. 

About
-----
DO-AutoVPN uses a python script to create a Droplet on DigitalOceans infrastructure, sets up an OpenVPN server on said Droplet, and then securely returns the client configuration file to your local system.

The server post-install scripts can be found at https://github.com/riptidewave93/DO-AutoVPN-Server. It is also worth noting that a VPN instance that is left unused for 15 minutes will destroy itself.

Usage
-----
1. Clone repo
2. run deploy.py
3. Connect to the VPN using the downloaded client.ovpn file

Issues
-----
* You tell me!