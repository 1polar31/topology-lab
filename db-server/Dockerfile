FROM alpine:3.19

RUN apk add --no-cache bash nmap-ncat

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3306

CMD ["/entrypoint.sh"]
