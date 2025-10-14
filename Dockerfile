# syntax=docker/dockerfile:1

########################################
# ====== Builder stage ======
########################################
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG VERSION=dev
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder

ENV CGO_ENABLED=0
WORKDIR /src

# Install CA certificates (used at build time for module downloads over HTTPS)
RUN apk add --no-cache ca-certificates git

# Pre-cache modules for faster multi-arch builds
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod,sharing=locked \
    go mod download

# Copy the rest of the source
COPY . .

# Build the binary (static). Set GOARM from TARGETVARIANT for linux/arm (e.g. v7 -> GOARM=7)
RUN --mount=type=cache,target=/go/pkg/mod,sharing=locked \
    --mount=type=cache,target=/root/.cache/go-build,sharing=locked \
    if [ "$TARGETARCH" = "arm" ] && [ -n "$TARGETVARIANT" ]; then export GOARM="${TARGETVARIANT#v}"; fi; \
    echo "Building for $TARGETOS/$TARGETARCH${TARGETVARIANT:+/$TARGETVARIANT} (GOARM=${GOARM:-})"; \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/cloud-torrent


########################################
# ====== Runtime stage ======
########################################
FROM alpine:3.20 AS runtime

# Install CA certs for HTTPS (scraper fetches over TLS)
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /

# Copy binary
COPY --from=builder /out/cloud-torrent /usr/local/bin/cloud-torrent

# Network ports
EXPOSE 3000/tcp 50007/tcp 50007/udp


USER root

# Default command: use defaults (PORT via env; config at /data/cloud-torrent.json)
ENTRYPOINT ["/usr/local/bin/cloud-torrent"]

########################################
# docker run --restart=always -d --name=downloads -p 3000:3000 -v /data/downloads:/downloads cppla/cloud-torrent --auth user:password
########################################
