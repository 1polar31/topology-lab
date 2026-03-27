#!/bin/bash

echo "[*] Database server starting on port 3306..."

# Fake MySQL banner with Flag 5
# The greeting mimics MySQL protocol enough that nmap identifies it as mysql
while true; do
    printf '\x4a\x00\x00\x00\x0a5.7.42-NovaCorp-FLAG{5_db_service_enumeration}\x00' | \
        ncat -l -p 3306 -w 3 --max-conns 1 2>/dev/null
done
