FROM alpine:latest

RUN apk add --update \
    samba-common-tools \
    samba-client \
    samba-server \
    && rm -rf /var/cache/apk/*

ADD samba4/scripts/k8s.sh /scripts/k8s.sh

EXPOSE 445/tcp

ENTRYPOINT [ "/scripts/k8s.sh" ]
CMD []
