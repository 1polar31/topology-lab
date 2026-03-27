FROM alpine:3.19

RUN apk add --no-cache \
    nmap nmap-scripts \
    bind-tools \
    busybox-extras \
    curl wget \
    samba-client \
    traceroute \
    nmap-ncat \
    bash \
    iputils \
    net-tools \
    iproute2

# Welcome message
COPY motd.sh /etc/profile.d/motd.sh
RUN chmod +x /etc/profile.d/motd.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /root

ENTRYPOINT ["/entrypoint.sh"]
