# Test image matching the target desktop: Ubuntu 26.04, GTK 4 + libadwaita, headless Broadway backend.
# Build with --build-arg BASE=ubuntu:24.04 to check the oldest supported libadwaita (1.5).
ARG BASE=ubuntu:26.04
FROM ${BASE}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      python3 python3-gi gir1.2-gtk-4.0 gir1.2-adw-1 libgtk-4-bin \
      fonts-cantarell fonts-dejavu-core adwaita-icon-theme hicolor-icon-theme librsvg2-common \
      bash coreutils hyperfine \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /repo
