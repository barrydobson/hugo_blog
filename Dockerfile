FROM alpine:latest

RUN apk --no-cache add ca-certificates curl bash vim git make

RUN curl -L https://github.com/gohugoio/hugo/releases/download/v0.54.0/hugo_0.54.0_Linux-64bit.tar.gz | tar -zOxf - hugo > /usr/bin/hugo && chmod +x /usr/bin/hugo

WORKDIR /app

ENTRYPOINT ["bash"]