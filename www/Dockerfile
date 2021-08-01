FROM alpine:latest

RUN apk update
RUN apk add hugo

#RUN adduser -D -g 'www' www
#RUN mkdir /www
#RUN chown -R www:www /www

EXPOSE 8000
CMD ["sh", "-c", "cd /www && hugo server --bind '0.0.0.0' --port 8000"]
