FROM alpine

RUN apk update && \
    apk upgrade && \
    apk add git rsync openssh

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
