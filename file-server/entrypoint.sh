#!/bin/bash

echo "[*] File server starting..."
smbd --foreground --no-process-group &
nmbd --foreground --no-process-group &

wait
