# a stock arch for the linux smoke gate (smoke-arch.sh): the image by digest
# and its packages from the arch archive of the same day, so a rerun gets the
# same system. arch links gtk to the system sqlite, which the bundle's
# sqlcipher must not bind to
FROM archlinux@sha256:b1c2fe6e717bfd5673af8fc217e1e1c3ce0dcbb1d53c3414c8425e7ce79fc6d9
ARG DAY=2026/11/01
RUN echo "Server = https://archive.archlinux.org/repos/$DAY/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist \
    && pacman -Syu --noconfirm --needed gtk3 libsecret mesa xorg-server-xvfb xdotool \
       dbus xdg-desktop-portal xdg-desktop-portal-gtk gst-plugins-base gst-plugins-good \
       gdb python ttf-dejavu \
    && pacman -Scc --noconfirm \
    && useradd -m -u 1000 user
