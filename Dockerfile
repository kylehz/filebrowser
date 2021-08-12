FROM golang:1.16.6-alpine
ENV GOPROXY="https://goproxy.io" \
    GO111MODULE=on
WORKDIR /apps
COPY ./ .
RUN go build -o filebrowser main.go

FROM alpine:latest
WORKDIR /apps
RUN apk --update add ca-certificates \
                     mailcap \
                     curl
HEALTHCHECK --start-period=2s --interval=5s --timeout=3s \
  CMD curl -f http://localhost:8088/health || exit 1
VOLUME /srv
EXPOSE 8088
COPY --from=0  ./filebrowser .
COPY --from=0  ./.docker.json .filebrowser.json

ENTRYPOINT [ "/filebrowser" ]

