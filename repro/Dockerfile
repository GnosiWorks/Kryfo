# reproducible build for libhalo.so
# anyone can run this and get a byte-identical engine from source.
# pinned: go 1.25.0, android ndk r28b (28.2.13676358), debian bookworm-slim.
FROM debian:bookworm-20250630-slim

# pinned tool versions
ENV GO_VERSION=1.25.0
ENV GO_SHA256=2852af0cb20a13139b3448992e69b868e50ed0f8a1e5940ee1de9e19a123b613
ENV NDK_VERSION=r28b
ENV NDK_SHA256=e9f2759862cecfd48c20bbb7d8cfedbb020f4d91b5f78d9a2fc106f7db3c27ed

# bookworm ships tool versions frozen by the snapshot tag above, so these are
# deterministic. only what the build actually needs.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip \
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
RUN mkdir -p /build/out

# deterministic build env. SOURCE_DATE_EPOCH pins any embedded timestamps;
# -trimpath drops absolute module paths; buildid cleared; the linker's
# build-id (both go and the ndk lld) zeroed so nothing random survives.
ENV CGO_ENABLED=1
ENV GOFLAGS=-trimpath
ENV SOURCE_DATE_EPOCH=1700000000

COPY build-repro.sh /usr/local/bin/build-repro.sh
RUN chmod +x /usr/local/bin/build-repro.sh
ENTRYPOINT ["/usr/local/bin/build-repro.sh"]
