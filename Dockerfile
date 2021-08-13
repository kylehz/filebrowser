FROM node:12 as builder-front
WORKDIR /apps
COPY ./ .
RUN cd frontend \
  && npm config set registry https://registry.npm.taobao.org \
  && npm install && npm run build \
  && rm -rf node_modules

FROM golang:1.16.6-alpine as builder-backend
ENV GOPROXY="https://goproxy.io" \
    GO111MODULE=on
WORKDIR /apps
COPY --from=builder-front /apps .
RUN go build -o filebrowser main.go

FROM alpine:latest
WORKDIR /apps
RUN apk --update add ca-certificates \
                     mailcap \
                     curl
HEALTHCHECK --start-period=2s --interval=5s --timeout=3s \
  CMD curl -f http://localhost:8088/health || exit 1
EXPOSE 80
COPY --from=builder-backend  /apps/filebrowser .
COPY --from=builder-backend  /apps/.docker.json .filebrowser.json

ENTRYPOINT [ "./filebrowser" ]
