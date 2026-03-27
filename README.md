# CAPEC-309: Network Topology Mapping Lab

**IT&C 266 — Attack Pattern Repository**
**Author:** Gabriel Ruegner

A hands-on Docker lab environment for learning network topology mapping techniques (CAPEC-309). You'll use tools like Nmap, dig, traceroute, curl, and smbclient to discover hosts, enumerate services, map out a multi-subnet corporate network, and capture 5 flags along the way.

---

## Lab Overview

You're a penetration tester who has just gained access to a machine on NovaCorp's DMZ network (10.10.10.0/24). Your objective is to map the full network topology — discover all hosts, identify running services, find any additional subnets, and prove you did it by collecting 5 flags hidden throughout the environment.

**Architecture:**
```
┌─────────────────────────────────────────────────────────┐
│                  DMZ (10.10.10.0/24)                    │
│                                                         │
│  [attacker]     [web-server]  [dns-server] [mail-server]│
│  10.10.10.50    10.10.10.10   10.10.10.20  10.10.10.30  │
│                                                         │
│                    [router]                              │
│                   10.10.10.1                             │
│                       │                                 │
└───────────────────────┼─────────────────────────────────┘
                        │
┌───────────────────────┼─────────────────────────────────┐
│                   10.10.20.1                            │
│                    [router]                             │
│                                                        │
│           [file-server]      [db-server]               │
│           10.10.20.10        10.10.20.20               │
│                                                        │
│                Internal (10.10.20.0/24)                 │
└────────────────────────────────────────────────────────┘
```

**Time to complete:** 30–45 minutes

**Difficulty:** Beginner–Intermediate

**Primary platform:** Windows with Docker Desktop

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running (Windows 10/11 with WSL2 backend)
- Basic familiarity with the Linux command line (you'll be working inside a Linux container)
- No prior Nmap experience required — the walkthrough covers everything

> **Note:** This lab also works on macOS with Docker Desktop and on native Linux with Docker Engine. The instructions below use PowerShell/CMD but all `docker` commands are the same across platforms.

---

## Setup

**1. Make sure Docker Desktop is running.** You should see the Docker whale icon in your system tray. If WSL2 integration is enabled (the default), you're good to go.

**2. Download and extract the `topology-lab` folder** into a directory on your machine (e.g., `C:\Users\YourName\topology-lab`).

**3. Open PowerShell or Command Prompt,** navigate to the folder, and build/start the lab:

```
cd topology-lab
docker compose up -d --build
```

This will build 7 containers across 2 subnets. The first build takes a couple minutes to download base images — subsequent starts are much faster.

**4. Verify everything is running:**

```
docker compose ps
```

You should see all 7 containers with a status of "Up."

**5. Shell into the attacker box:**

```
docker exec -it attacker bash
```

You'll see a welcome banner with your starting info. You're on 10.10.10.50 in the DMZ. From here on, every command runs inside this Linux container — so all the Linux commands in the walkthrough will work even though you're on Windows.

---

## Objectives

1. Discover all live hosts on the DMZ subnet
2. Enumerate services and open ports on each host
3. Find the hidden second subnet and discover hosts on it
4. Collect all 5 flags

---

## Flags

| Flag | Hint |
|------|------|
| Flag 1 | Check HTTP response headers on non-standard ports |
| Flag 2 | DNS servers sometimes give away more than they should |
| Flag 3 | Mail servers announce themselves when you connect |
| Flag 4 | Shared files might contain sensitive info |
| Flag 5 | Database servers leak info in their version strings |

---

## Walkthrough

See [WALKTHROUGH.md](WALKTHROUGH.md) for the full step-by-step guide with exact commands and expected output.

---

## Cleanup

When you're done, tear everything down:

```bash
docker compose down --rmi all
```

---

## Troubleshooting

**Containers won't start:**
Make sure Docker Desktop is running (check for the whale icon in your system tray). The lab uses internal Docker networks only — nothing binds to your host ports, so there shouldn't be port conflicts.

**"permission denied" or script errors on Windows:**
This is usually a line ending issue. Windows uses `\r\n` but Linux containers need `\n`. If you edited any `.sh` files on Windows, open them in VS Code, click "CRLF" in the bottom-right status bar, switch it to "LF", and save. Or just re-extract from the original zip. The `.gitattributes` file prevents this if you're using git.

**Router not forwarding traffic:**
The router container needs `NET_ADMIN` capabilities and `ip_forward` enabled. Both are configured in `docker-compose.yml`. If it's still not working, try restarting Docker Desktop — WSL2 occasionally needs a fresh start.

**`ip route add` fails in the attacker container:**
The attacker container also needs `NET_ADMIN` (already set in compose). If you see "Operation not permitted," make sure you're running the latest version of Docker Desktop with WSL2 backend — older versions of Hyper-V backend can restrict capabilities.

**Can't reach internal subnet from attacker:**
You need to add a route first. The walkthrough covers this — `ip route add 10.10.20.0/24 via 10.10.10.1`. If pings still fail after adding the route, restart the router container: `docker compose restart router`.

**DNS queries failing:**
Make sure you're pointing dig at the DNS server explicitly: `dig @10.10.10.20`. The container's default DNS won't know about `novatech.local`.

**SMB connection refused on Windows Docker Desktop:**
This can happen if the file-server container is still starting up. Wait 10–15 seconds after `docker compose up` and try again. You can check if it's ready with `docker compose logs file-server`.
