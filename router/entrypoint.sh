#!/bin/bash
set -e

# Enable IP forwarding
# sysctls in docker-compose.yml handles this on Docker Desktop (Windows/Mac),
# but we set it here too as a fallback for native Linux hosts
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "[*] ip_forward already set via sysctls"

# Allow forwarding between interfaces
iptables -P FORWARD ACCEPT 2>/dev/null || true
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE 2>/dev/null || true

echo "[*] Router is up — forwarding between DMZ and Internal"

# Keep container alive
tail -f /dev/null
