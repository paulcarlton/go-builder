#
# (c) Copyright 2017-2019 Hewlett Packard Enterprise Development LP
#
# Confidential computer software. Valid license from HP required for
# possession, use or copying. Consistent with FAR 12.211 and 12.212,
# Commercial Computer Software, Computer Software Documentation, and
# Technical Data for Commercial Items are licensed to the U.S. Government
# under vendor's standard commercial license.
#
ARG GOLANG_VERSION=1.12.5-stretch
ARG DOCKER_VERSION=18.09.6
ARG GLIDE_VERSION=v0.13.2
ARG DEP_VERSION=v0.5.3
ARG GOLANGCI_LINT=1.16.0
ARG SWAGGER_VERSION=v0.19.0
ARG GODOCDOWN_VERSION=0bfa0490548148882a54c15fbc52a621a9f50cbe
ARG GOTESTSUM_VERSION=0.3.4
ARG DEBIAN_VERSION=stretch-20190506-slim
ARG GRPC_VERSION=1.9.0
ARG PROTOC_GEN_GO_VERSION=v1.3.1
ARG PROTOLOCK_URL=https://github.com/nilslice/protolock/releases/download/v0.12.0/protolock.20190327T205335Z.linux-amd64.tgz
ARG PROTOTOOL_VERSION=v1.7.0
ARG PROTO_VERSION=3.7.0

#----------------
FROM debian:$DEBIAN_VERSION as curl
RUN apt-get update \
 && apt-get install -y \
    curl \
    unzip \
 && rm -rf /var/lib/apt/lists/*

#----------------
FROM curl as docker
ARG DOCKER_VERSION
RUN set -x \
  && curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
  && mkdir -p /docker \
  && tar -xzvf docker.tgz --directory /docker \
  && rm docker.tgz

#----------------
FROM curl as glide
ARG GLIDE_VERSION
RUN  curl -fsSL -o glide.tar.gz https://github.com/Masterminds/glide/releases/download/${GLIDE_VERSION}/glide-${GLIDE_VERSION}-linux-amd64.tar.gz \
 && mkdir -p /glide \
 && tar xvzf glide.tar.gz -C /glide \
 && cp /glide/linux-amd64/glide /usr/bin/glide \
 && rm -f glide.tar.gz \
 && rm -rf /glide

#----------------
FROM curl as dep
ARG DEP_VERSION
RUN curl -fsSL -o /usr/bin/dep https://github.com/golang/dep/releases/download/${DEP_VERSION}/dep-linux-amd64 \
 && chmod +x /usr/bin/dep

#----------------
FROM curl as golangci-lint
ARG GOLANGCI_LINT
RUN  curl -fsSL -o linter.tar.gz https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT}/golangci-lint-${GOLANGCI_LINT}-linux-amd64.tar.gz \
 && mkdir -p /linter \
 && tar xvzf linter.tar.gz --strip-components=1 -C /linter \
 && rm -f linter.tar.gz

#----------------
FROM curl as swagger
ARG SWAGGER_VERSION
RUN curl -fsSL -o /usr/local/bin/swagger https://github.com/go-swagger/go-swagger/releases/download/${SWAGGER_VERSION}/swagger_linux_amd64 \
 && chmod 755 /usr/local/bin/swagger

#----------------
FROM golang:$GOLANG_VERSION as gotype
# gotype
# Reference https://github.com/golang/go/issues/12703, from griesemer
#  x/tools/cmd/gotype was removed because we don't want to maintain two slightly different versions.
#  The latest and up-to-date version is in (std/lib) go/types. It's a stand-alone app gotype.go, and
#  must be built with go build gotype.go in that directory, for now. It supports a new flag -c which
#  permits the specification of the compiler that was used to create packages. Importing from source is
#  now possible with -c=source. Thanks.
RUN cd /usr/local/go/src/go/types \
 && go build gotype.go \
 && cp gotype /usr/bin

#----------------
FROM golang:$GOLANG_VERSION as godocdown
ARG GODOCDOWN_VERSION
RUN apt-get update \
 && apt-get install -y \
    git \
 && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /go/src/github.com/robertkrimen \
 && cd /go/src/github.com/robertkrimen \
 && git clone https://github.com/robertkrimen/godocdown.git \
 && git -C godocdown checkout ${GODOCDOWN_VERSION} \
 && cd godocdown/godocdown \
 && set -x \
 && go install

#----------------
FROM curl as gotestsum
ARG GOTESTSUM_VERSION
RUN curl -fsSL -o gotestsum.tar.gz https://github.com/gotestyourself/gotestsum/releases/download/v${GOTESTSUM_VERSION}/gotestsum_${GOTESTSUM_VERSION}_linux_amd64.tar.gz \
    && mkdir -p /gotestsum \
    && tar xvzf gotestsum.tar.gz -C /gotestsum \
    && cp /gotestsum/gotestsum /usr/bin/gotestsum \
    && rm -f gotestsum.tar.gz \
    && rm -rf /gotestsum

#----------------
FROM curl as grpc
ARG GRPC_VERSION
RUN curl -fsSL -o protoc-gen-grpc-gateway https://github.com/grpc-ecosystem/grpc-gateway/releases/download/v${GRPC_VERSION}/protoc-gen-grpc-gateway-v${GRPC_VERSION}-linux-x86_64 \
  && chmod +x protoc-gen-grpc-gateway \
  && mv protoc-gen-grpc-gateway /usr/bin

RUN curl -fsSL -o protoc-gen-swagger https://github.com/grpc-ecosystem/grpc-gateway/releases/download/v${GRPC_VERSION}/protoc-gen-swagger-v${GRPC_VERSION}-linux-x86_64 \
  && chmod +x protoc-gen-swagger \
  && mv protoc-gen-swagger /usr/bin

#----------------
FROM golang:$GOLANG_VERSION as protoc-gen-go
ARG PROTOC_GEN_GO_VERSION
RUN go get -d -u github.com/golang/protobuf/protoc-gen-go \
 && git -C "$(go env GOPATH)"/src/github.com/golang/protobuf checkout $PROTOC_GEN_GO_VERSION \
 && go install github.com/golang/protobuf/protoc-gen-go

#----------------
FROM curl as protolock
ARG PROTOLOCK_URL
RUN mkdir -p /tmp/protolock \
  && cd /tmp/protolock \
  && curl -fsSL -o protolock.tgz $PROTOLOCK_URL \
  && tar xvf protolock.tgz \
  && cp protolock /usr/bin \
  && cd / \
  && rm -rf /tmp/protolock

#----------------
FROM curl as prototool
ARG PROTOTOOL_VERSION
RUN curl -fsSL -o prototool.tar.gz \
      https://github.com/uber/prototool/releases/download/${PROTOTOOL_VERSION}/prototool-$(uname -s)-$(uname -m).tar.gz
RUN tar xvzf prototool.tar.gz

#----------------
FROM golang:$GOLANG_VERSION as release

RUN apt-get update \
 && apt-get install -y \
    ca-certificates=20161130+nmu1+deb9u1 \
    curl=7.52.1-5+deb9u9 \
    git=1:2.11.0-3+deb9u4 \
    gzip=1.6-5+b1 \
    openssh-server=1:7.4p1-10+deb9u6 \
    rsync=3.1.2-1+deb9u1 \
    tar=1.29b-1.1 \
    unzip=6.0-21+deb9u1 \
    automake=1:1.15-6 \
    autoconf=2.69-10 \
    libtool=2.4.6-2 \
    build-essential=12.3 \
 && rm -rf /var/lib/apt/lists/*

ARG PROTO_VERSION
RUN curl -fsSL -o protoc.zip https://github.com/google/protobuf/releases/download/v${PROTO_VERSION}/protoc-${PROTO_VERSION}-linux-x86_64.zip \
  && mkdir -p protoc \
  && unzip -a protoc.zip -d protoc \
  && cp protoc/bin/* /usr/bin/ \
  && rm -f protoc.zip \
  && rm -rf /go/protoc

RUN curl -fsSL -o protobuf.zip https://github.com/google/protobuf/releases/download/v${PROTO_VERSION}/protobuf-all-${PROTO_VERSION}.zip \
  && unzip -a protobuf.zip \
  && cd protobuf-${PROTO_VERSION} \
  && ./autogen.sh \
  && ./configure  \
  && make -j$(nproc || echo 1) install \
  && cd /go \
  && rm -f protobuf.zip \
  && rm -rf /go/protobuf-${PROTO_VERSION}

COPY --from=docker /docker/* /usr/local/bin/
COPY --from=glide /usr/bin/glide /usr/bin/glide
COPY --from=dep /usr/bin/dep /usr/bin/dep
COPY --from=golangci-lint /linter/golangci-lint /usr/bin/
COPY --from=swagger /usr/local/bin/swagger /usr/local/bin/swagger
COPY --from=gotype /usr/bin/gotype /usr/bin/gotype
COPY --from=godocdown /go/bin/* /usr/bin/
COPY --from=gotestsum /usr/bin/gotestsum /usr/bin/gotestsum

COPY --from=grpc /usr/bin/protoc-gen-grpc-gateway /usr/bin
COPY --from=grpc /usr/bin/protoc-gen-swagger /usr/bin
COPY --from=protoc-gen-go /go/bin/protoc-gen-go /usr/bin/
COPY --from=protolock /usr/bin/protolock /usr/bin
COPY --from=prototool /prototool/ /usr/local/

RUN ldconfig

ENTRYPOINT ["/bin/sh"]

#----------------
FROM release as test
RUN docker -v
RUN go version
RUN golangci-lint --version
RUN glide --version
RUN dep version
RUN swagger version

#----------------
FROM release
ARG TAG
ARG GIT_SHA
ARG BUILD_DATE
ARG SRC_REPO
ARG GIT_DESCRIBE
ENV TAG $TAG
ENV GIT_SHA $GIT_SHA
ENV BUILD_DATE $BUILD_DATE
ENV SRC_REPO $SRC_REPO
ENV GIT_DESCRIBE $GIT_DESCRIBE
LABEL TAG=$TAG \
  GIT_SHA=$GIT_SHA \
  GIT_DESCRIBE=$GIT_DESCRIBE \
  BUILD_DATE=$BUILD_DATE \
  SRC_REPO=$SRC_REPO
