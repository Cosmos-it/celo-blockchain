# How to test changes to this file
# docker build -f Dockerfile -t gcr.io/celo-testnet/geth:$USER .
# To locally run that image
# docker rm geth_container ; docker run --name geth_container gcr.io/celo-testnet/geth:$USER
# and connect to it with
# docker exec -t -i geth_container /bin/sh
#
# Once you are satisfied, build the image using
# TAG is the git commit hash of the geth repo.
# docker build -f Dockerfile -t gcr.io/celo-testnet/geth:$TAG .
# push the image to the cloud
# docker push gcr.io/celo-testnet/geth:$TAG
# To use this image for testing, modify GETH_NODE_DOCKER_IMAGE_TAG in celo-monorepo/.env file

FROM ubuntu:16.04 as rustbuilder
ADD . /go-ethereum
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH=$PATH:$HOME/.cargo/bin
RUN rustup install nightly && rustup default nightly && rustup target add x86_64-unknown-linux-musl && cargo build --target x86_64-unknown-linux-musl --release
RUN cd /go-ethereum && make bls-zexe

# Build Geth in a stock Go builder container
FROM golang:1.11-alpine as builder

RUN apk add --no-cache make gcc musl-dev linux-headers
ADD . /go-ethereum
RUN mkdir -p /go-ethereum/vendor/github.com/celo-org/bls-zexe/target/release
COPY --from=rustbuilder /go-ethereum/vendor/github.com/celo-org/bls-zexe/bls/target/x86_64-unknown-linux-musl/release/libbls_zexe.a vendor/github.com/celo-org/bls-zexe/target/release
RUN cd /go-ethereum && make geth

# Pull Geth into a second stage deploy alpine container
FROM alpine:latest

RUN apk add --no-cache ca-certificates
COPY --from=builder /go-ethereum/build/bin/geth /usr/local/bin/

EXPOSE 8545 8546 30303 30303/udp
ENTRYPOINT ["geth"]
