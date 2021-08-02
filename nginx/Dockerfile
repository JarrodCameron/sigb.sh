FROM alpine:latest

RUN apk update
RUN apk add hugo nginx

# Copied from:
#   https://wiki.alpinelinux.org/wiki/Nginx
RUN adduser -D -g 'www' www
RUN mkdir /www
RUN chown -R www:www /var/lib/nginx
RUN chown -R www:www /www

RUN mkdir /etc/nginx/ssl
COPY ssl /etc/nginx/ssl
RUN chmod 700 /etc/nginx/ssl

COPY www /www
RUN hugo --baseURL='https://www.sigb.sh/' --minify=true --source=/www --destination=/public

COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /run/nginx
EXPOSE 80
EXPOSE 443

CMD ["/usr/sbin/nginx", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]
