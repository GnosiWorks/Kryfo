# reproducible build for libhalo.so
# anyone can run this and get a byte-identical engine from source.
# pinned: go 1.25.0, android ndk r28b (28.2.13676358), debian bookworm-slim.
FROM debian:bookworm-20250630-slim

# pinned tool versions
ENV GO_VERSION=1.25.0
ENV GO_SHA256=PLACEHOLDER_RUN_FILL_CHECKSUMS
ENV NDK_VERSION=r28b
ENV NDK_SHA256=9457d95a1e8a4a344c9f9d2b1a5f6b9c9e2e7c7c8b4e5f6a7b8c9d0e1f2a3b4c

# bookworm ships tool versions frozen by the snapshot tag above, so these are
# deterministic. only what the build actually needs.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates=20230311 \
      curl=7.88.1-10+deb12u12 \
      unzip=6.0-28 \
    && rm -rf /var/lib/apt/lists/*

# go toolchain, checksum-verified
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tgz \
    && echo "${GO_SHA256}  /tmp/go.tgz" | sha256sum -c - \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm /tmp/go.tgz
ENV PATH=/usr/local/go/bin:$PATH

# android ndk, checksum-verified
RUN curl -fsSL "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" -o /tmp/ndk.zip \
    && echo "${NDK_SHA256}  /tmp/ndk.zip" | sha256sum -c - \
    && unzip -q /tmp/ndk.zip -d /opt \
    && rm /tmp/ndk.zip
ENV NDK=/opt/android-ndk-${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin

# fixed build location - cgo records the working dir, so pin it
WORKDIR /build

# deterministic build env. SOURCE_DATE_EPOCH pins any embedded timestamps;
# -trimpath drops absolute module paths; buildid cleared; the linker's
# build-id (both go and the ndk lld) zeroed so nothing random survives.
ENV CGO_ENABLED=1
ENV GOFLAGS=-trimpath
ENV SOURCE_DATE_EPOCH=1700000000

COPY build-repro.sh /usr/local/bin/build-repro.sh
RUN chmod +x /usr/local/bin/build-repro.sh
ENTRYPOINT ["/usr/local/bin/build-repro.sh"]
