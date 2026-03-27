FROM alpine:3.19

RUN apk add --no-cache samba bash

COPY smb.conf /etc/samba/smb.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create the shared directory and flag file
RUN mkdir -p /srv/share/documents && \
    echo "FLAG{4_smb_share_accessed}" > /srv/share/documents/credentials-backup.txt && \
    echo "" >> /srv/share/documents/credentials-backup.txt && \
    echo "Internal Server Credentials (ROTATE THESE)" >> /srv/share/documents/credentials-backup.txt && \
    echo "dbhost MySQL root: N0v4T3ch_DB_2024" >> /srv/share/documents/credentials-backup.txt && \
    echo "webhost admin panel: admin / W3bAdm1n!" >> /srv/share/documents/credentials-backup.txt

# Create samba user
RUN adduser -D -H smbuser && \
    echo -e "topomap2024\ntopomap2024" | smbpasswd -a -s smbuser

EXPOSE 139 445

CMD ["/entrypoint.sh"]
