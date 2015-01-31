
FROM ubuntu:14.04

MAINTAINER Traun Leyden <tleyden@couchbase.com>

ENV GOPATH /opt/go
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$GOPATH/bin
ENV SGROOT /opt/sync_gateway

# Get dependencies
RUN apt-get update && apt-get install -y \
  git \
  bc \
  golang \
  wget \
  curl 


# Build Sync Gateway
RUN mkdir -p $GOPATH && \
    mkdir -p /opt && \
    cd /opt && \ 
    git clone https://github.com/couchbase/sync_gateway.git && \
    cd $SGROOT && \
    git submodule update --init --recursive && \
    ./build.sh && \
    cp bin/sync_gateway /usr/local/bin && \
    mkdir -p $SGROOT/data


# Install Godep + couchbase-cluster-go
RUN go get -u -v github.com/tools/godep && \
    godep get github.com/tleyden/couchbase-cluster-go/...

# Put start script
ADD scripts/couchbase-cluster-wrapper /usr/local/bin/

# Add Sync Gateway launch script
ADD scripts/sync-gw-start /usr/local/bin/

