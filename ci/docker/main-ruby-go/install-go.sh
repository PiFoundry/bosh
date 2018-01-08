#!/usr/bin/env bash

set -eux
# TODO ADD THE ARM Go Binaries or build from source
GOPATH=/home/vagrant/go
#GO_ARCHIVE_URL=https://storage.googleapis.com/golang/go1.8.3.linux-amd64.tar.gz
#GO_ARCHIVE_SHA256=1862f4c3d3907e59b04a757cfda0ea7aa9ef39274af99a784f5be843c80c6772
GO_ARCHIVE_URL=https://storage.googleapis.com/golang/go1.8.2.linux-armv6l.tar.gz
GO_ARCHIVE_SHA256=a1942b2833e7d2685d7dbb7ac81c66125c351f24c7f006e8ae4a4283905257d1
GO_ARCHIVE=/tmp/$(basename $GO_ARCHIVE_URL)

echo "Downloading go..."
mkdir -p $(dirname $GOROOT)
wget -q $GO_ARCHIVE_URL -O $GO_ARCHIVE
echo "${GO_ARCHIVE_SHA256} ${GO_ARCHIVE}" | sha256sum -c -
tar xf $GO_ARCHIVE -C $(dirname $GOROOT)

rm -f $GO_ARCHIVE
