ARG UPSTREAM_IMAGE
ARG UPSTREAM_TAG_SHA

# https://github.com/rakshasa/rtorrent/issues/1479#issuecomment-2888925659
FROM ${UPSTREAM_IMAGE}:${UPSTREAM_TAG_SHA} AS builder
RUN apk add --no-cache build-base linux-headers curl-dev ncurses-dev tinyxml2-dev git autoconf automake libtool cppunit-dev
ARG VERSION
RUN git clone https://github.com/rakshasa/libtorrent.git /tmp/libtorrent && \
    cd "/tmp/libtorrent" && \
    autoreconf -fi && \
    ./configure --disable-debug --disable-shared --enable-static --enable-aligned && \
    make -j$(nproc) CXXFLAGS="-w -O3 -flto -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing" && \
    make install
RUN git clone https://github.com/PiloUnk/rtorrent.git /tmp/rtorrent && \
    cd "/tmp/rtorrent" && \
    autoreconf -fi && \
    ./configure --disable-debug --disable-shared --enable-static --enable-aligned --with-xmlrpc-tinyxml2 && \
    make -j$(nproc) CXXFLAGS="-w -O3 -flto -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing" && \
    make install

FROM ${UPSTREAM_IMAGE}:${UPSTREAM_TAG_SHA}
EXPOSE 3000
ARG IMAGE_STATS
ENV IMAGE_STATS=${IMAGE_STATS} FLOOD_AUTH="false" WEBUI_PORTS="3000/tcp"

RUN apk add --no-cache xmlrpc-c-tools nginx openssl mediainfo && \
    ln -s "${CONFIG_DIR}/rpc2/basic_auth_credentials" "${APP_DIR}/basic_auth_credentials"

COPY --from=builder /usr/local/bin/rtorrent "${APP_DIR}/rtorrent"

ARG FLOOD_VERSION
RUN curl -fsSL "https://github.com/jesec/flood/releases/download/v${FLOOD_VERSION}/flood-linux-arm64" > "${APP_DIR}/flood" && \
    chmod 755 "${APP_DIR}/flood"

COPY root/ /
RUN find /etc/s6-overlay/s6-rc.d -name "run*" -execdir chmod +x {} +
