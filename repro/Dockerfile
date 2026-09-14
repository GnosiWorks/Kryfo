# reproducible build of the whole apk.
#
# the image is f-droid's build box, as near as pins allow: debian bookworm,
# the jdk debian ships, one exact flutter, one exact go, one exact ndk, the
# android sdk pieces the project names. the source is mounted at
# /home/vagrant/build/app.kryfo, the path f-droid builds in, because the
# dart aot snapshot (libapp.so) and the build-id of two plugin libraries
# carry the build path; anywhere else and those three entries differ.
#
# build-repro.sh runs the engine build, then flutter, and leaves the three
# apks in /out. verify.sh on the host drives it and diffs entries.
FROM debian:bookworm-20250630-slim

# ── pins ──
# jdk: bookworm ships 17, which is what f-droid's buildserver uses. a build
# made with another major can differ in classes.dex; that is a finding, not
# a bug in this file.
ARG JDK=17
ENV GO_VERSION=1.25.0
ENV GO_SHA256=2852af0cb20a13139b3448992e69b868e50ed0f8a1e5940ee1de9e19a123b613
ENV FLUTTER_VERSION=3.41.7
ENV FLUTTER_COMMIT=cc0734ac716fbb8b90f3f9db8020958b1553afa7
ENV CMDLINE_TOOLS=11076708
ENV CMDLINE_TOOLS_SHA256=2d2d50857e4eb553af5a6dc3ad507a17adf43d115264b1afc116f95c92e5e258
# mobile/android/app/build.gradle.kts names the ndk; flutter 3.41 compiles
# against 36; agp 8.11 pairs with build-tools 35
ENV NDK_VERSION=28.2.13676358
ENV ANDROID_PLATFORM=android-36
ENV BUILD_TOOLS=35.0.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip xz-utils git \
    openjdk-${JDK}-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# go, checksum-verified
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tgz \
    && echo "${GO_SHA256}  /tmp/go.tgz" | sha256sum -c - \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm /tmp/go.tgz
ENV PATH=/usr/local/go/bin:$PATH

# android sdk: command line tools, then exactly the components the build
# needs. the ndk comes from the same manager so it lands where the gradle
# plugin looks for it ($ANDROID_HOME/ndk/<version>).
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
RUN curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS}_latest.zip" -o /tmp/cmdline.zip \
    && echo "${CMDLINE_TOOLS_SHA256}  /tmp/cmdline.zip" | sha256sum -c - \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && unzip -q /tmp/cmdline.zip -d ${ANDROID_HOME}/cmdline-tools \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/cmdline.zip \
    && yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null \
    && ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --install \
        "platform-tools" \
        "platforms;${ANDROID_PLATFORM}" \
        "build-tools;${BUILD_TOOLS}" \
        "ndk;${NDK_VERSION}" >/dev/null
ENV ANDROID_NDK_HOME=${ANDROID_HOME}/ndk/${NDK_VERSION}

# flutter, one tag, and the commit behind the tag checked so a moved tag
# cannot pass. precache pulls the android engine artifacts now, so the
# build itself needs the network only for gradle and pub.
RUN git clone -q --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter \
    && test "$(git -C /opt/flutter rev-parse HEAD)" = "${FLUTTER_COMMIT}" \
    && /opt/flutter/bin/flutter config --no-analytics >/dev/null \
    && /opt/flutter/bin/flutter precache --android \
    && /opt/flutter/bin/flutter --version
ENV PATH=/opt/flutter/bin:$PATH

# f-droid builds as uid 1000 in /home/vagrant; the path is what matters,
# the uid is so the files verify.sh mounts come back owned by you. the
# flutter checkout was cloned by root above, and git refuses to touch a
# repository owned by someone else ("dubious ownership"), which flutter
# hits on its first version check. so it is handed to the build user, and
# marked safe system-wide as well, for a host uid that is not 1000.
RUN useradd -m -u 1000 -s /bin/bash vagrant \
    && mkdir -p /home/vagrant/build/app.kryfo /out \
    && chown -R vagrant:vagrant /opt/flutter /home/vagrant /out \
    && chmod -R a+rwX /home/vagrant /out /opt/flutter \
    && git config --system --add safe.directory /opt/flutter \
    && git config --system --add safe.directory '*'
ENV HOME=/home/vagrant
ENV PUB_CACHE=/home/vagrant/.pub-cache
ENV GRADLE_USER_HOME=/home/vagrant/.gradle

# what the engine build wants, the same values RELEASING.md gives
ENV CGO_ENABLED=1
ENV SOURCE_DATE_EPOCH=1700000000

WORKDIR /home/vagrant/build/app.kryfo
COPY build-repro.sh /usr/local/bin/build-repro.sh
RUN chmod +x /usr/local/bin/build-repro.sh
ENTRYPOINT ["/usr/local/bin/build-repro.sh"]
