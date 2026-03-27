FROM alpine:3.19

RUN apk add --no-cache bash nmap-ncat

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 25

CMD ["/entrypoint.sh"]
