FROM alpine:3.19

RUN apk add --no-cache bind bash

COPY named.conf /etc/bind/named.conf
COPY novatech.local.zone /var/bind/novatech.local.zone

RUN mkdir -p /var/run/named && chown named:named /var/run/named

EXPOSE 53/tcp 53/udp

CMD ["named", "-g", "-c", "/etc/bind/named.conf"]
