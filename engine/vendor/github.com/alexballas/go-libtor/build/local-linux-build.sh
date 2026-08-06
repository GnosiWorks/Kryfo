#!/bin/bash
# This script should be run from the root of the repo to locally update the
# linux/android golang wrappers for the libraries

docker build . -t go-libtor
rm -rf ./libtor/linux_*
docker run --rm -v "$PWD":/usr/src/go-libtor go-libtor cp -a /go/src/app/libtor/. /usr/src/go-libtor/libtor/
rm -rf ./linux
docker run --rm -v "$PWD":/usr/src/go-libtor go-libtor cp -r /go/src/app/linux/ /usr/src/go-libtor/
