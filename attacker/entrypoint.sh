#!/bin/bash

# Route internal subnet through the router
ip route add 10.10.20.0/24 via 10.10.10.1 2>/dev/null || true

echo "[*] Attacker ready — route to 10.10.20.0/24 via router (10.10.10.1)"

exec /bin/bash -l
