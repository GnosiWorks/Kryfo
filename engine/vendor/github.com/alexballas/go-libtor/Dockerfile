FROM golang:1.25-bookworm

RUN apt update
RUN apt install -y autoconf automake make libssl-dev libevent-dev zlib1g-dev libtool

WORKDIR /go/src/app
COPY . .

RUN go run build/wrap.go --update --nobuild
