FROM alpine:latest

RUN apk add --no-cache gcc libc-dev curl jq

COPY gmc320.c /usr/src/gmc320.c
RUN cd /usr/src && cc -std=gnu99 gmc320.c -o /usr/local/bin/gmc320 && rm -f gmc320.c

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
