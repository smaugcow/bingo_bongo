#!/bin/bash

sudo iptables -t nat -A OUTPUT -d 8.8.8.8 -p tcp --dport 80 -j DNAT --to-destination 77.88.8.8 
