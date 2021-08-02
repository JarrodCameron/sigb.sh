# sigb.sh

## Tools

apt update
apt install -y docker-compose

## Getting Starting

Clone and startup:

```sh
git clone --recurse-submodules 'https://github.com/JarrodCameron/sigb.sh'
cd sigb.sh

# Generate the HTTPS keys for debugging
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/ssl/www.key -out nginx/ssl/www.crt
docker-compose up --build
```

## TODO

[x] Setup HTTPS
[x] Links should redirect to `sigb.sh`, not `localhost:8000`
[x] Port 80 should redirect to port 443
[ ] Finish https://httpsiseasy.com/ video #4
