FROM nginx:1.25-alpine

# Flag 1 is in the custom server header and on a hidden admin page
COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html
COPY admin.html /usr/share/nginx/html/s3cr3t-admin/index.html

RUN mkdir -p /usr/share/nginx/html/s3cr3t-admin

EXPOSE 80 8443
