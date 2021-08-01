FROM alpine:latest

# Copied from:
#   https://wiki.alpinelinux.org/wiki/Nginx
RUN apk update
RUN apk add nginx
RUN adduser -D -g 'www' www
RUN mkdir /www
RUN chown -R www:www /var/lib/nginx
RUN chown -R www:www /www

COPY www /www

COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /run/nginx
EXPOSE 80

CMD ["/usr/sbin/nginx", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]
