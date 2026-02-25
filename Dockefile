FROM alpine:3.20

RUN apk add --no-cache bash curl jq ca-certificates

WORKDIR /opt/geoip-tool
COPY . .

RUN ln -s /opt/geoip-tool/bin/geoip /usr/local/bin/geoip

ENTRYPOINT ["geoip"]
CMD ["--help"]