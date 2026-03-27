#!/bin/bash

echo "[*] Mail server starting on port 25..."

# Simple SMTP banner with Flag 3
while true; do
    echo -e "220 mail.novatech.local ESMTP NovaCorp Mail v2.1.4 — FLAG{3_smtp_banner_grab}\r\n" | \
        ncat -l -p 25 -w 5 --max-conns 1
done
