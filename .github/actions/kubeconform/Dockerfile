FROM alpine:latest

RUN apk add --no-cache ca-certificates curl bash tar jq 

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER 1001
ENTRYPOINT ["/entrypoint.sh"]
