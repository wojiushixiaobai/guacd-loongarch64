FROM cr.loongnix.cn/loongson/loongnix:20 as builder

ARG GUACD_VERSION=1.4.0
ENV GUACD_VERSION=${GUACD_VERSION} \
    LC_ALL=C.UTF-8

ARG PREFIX_DIR=/usr/local/guacamole

ARG BUILD_DIR=/tmp/guacd-docker-BUILD
ARG BUILD_DEPENDENCIES="          \
        autoconf                  \
        automake                  \
        freerdp2-dev              \
        gcc                       \
        libcairo2-dev             \
        libgcrypt-dev             \
        libjpeg62-turbo-dev       \
        libossp-uuid-dev          \
        libpango1.0-dev           \
        libpulse-dev              \
        libssh2-1-dev             \
        libssl-dev                \
        libtelnet-dev             \
        libtool                   \
        libvncserver-dev          \
        libwebsockets-dev         \
        libwebp-dev               \
        make"

ARG TOOLS="                       \
        ca-certificates           \
        curl                      \
        git                       \
        wget"

ARG DEBIAN_FRONTEND=noninteractive

RUN set -ex \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && apt-get update \
    && apt-get install -y --no-install-recommends $BUILD_DEPENDENCIES \
    && apt-get install -y --no-install-recommends $TOOLS \
    && echo "no" | dpkg-reconfigure dash \
    && rm -rf /var/lib/apt/lists/*

RUN set -ex \
    && git clone -b ${GUACD_VERSION} https://github.com/apache/guacamole-server ${BUILD_DIR} \
    && mkdir -p ${PREFIX_DIR} \
    && cp -rf ${BUILD_DIR}/src/guacd-docker/bin "${PREFIX_DIR}/bin"

COPY list-dependencies.sh "${PREFIX_DIR}/bin"

RUN set -ex \
    && chmod 755 "${PREFIX_DIR}/bin/list-dependencies.sh" \
    && cd ${BUILD_DIR} \
    && autoreconf -fi \
    && rm -f build-aux/config.guess build-aux/config.sub \
    && wget -O build-aux/config.sub "git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD" \
    && wget -O build-aux/config.guess "git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD" \
    && ./configure --prefix="$PREFIX_DIR" --with-init-dir=/etc/init.d --disable-guaclog --with-freerdp-plugin-dir="$PREFIX_DIR/lib/freerdp2" --enable-allow-freerdp-snapshots \
    && make \
    && make install

RUN ${PREFIX_DIR}/bin/list-dependencies.sh     \
        ${PREFIX_DIR}/sbin/guacd               \
        ${PREFIX_DIR}/lib/libguac-client-*.so  \
        ${PREFIX_DIR}/lib/freerdp2/*guac*.so   \
        > ${PREFIX_DIR}/DEPENDENCIES

FROM cr.loongnix.cn/loongson/loongnix:20

ARG GUACD_VERSION=v2.22.1
ENV GUACD_VERSION=${VERSION} \
    LANG="en_US.UTF-8"

ARG PREFIX_DIR=/usr/local/guacamole
ENV LD_LIBRARY_PATH=${PREFIX_DIR}/lib

ARG RUNTIME_DEPENDENCIES="            \
        netcat-openbsd                \
        ca-certificates               \
        ghostscript                   \
        fonts-liberation              \
        fonts-dejavu                  \
        xfonts-terminus"

ARG DEPENDENCIES="                    \
        curl                          \
        wget"

ARG DEBIAN_FRONTEND=noninteractive
COPY --from=builder ${PREFIX_DIR} ${PREFIX_DIR}
COPY --from=builder /etc/init.d/guacd /etc/init.d/guacd

RUN set -ex \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && apt-get update \
    && apt-get install -y --no-install-recommends $RUNTIME_DEPENDENCIES \
    && apt-get install -y --no-install-recommends $(cat "${PREFIX_DIR}"/DEPENDENCIES) \
    && echo "no" | dpkg-reconfigure dash \
    && rm -rf /var/lib/apt/lists/*

RUN ${PREFIX_DIR}/bin/link-freerdp-plugins.sh \
        ${PREFIX_DIR}/lib/freerdp2/libguac*.so

COPY entrypoint.sh .
RUN chmod 755 ./entrypoint.sh

HEALTHCHECK --interval=5m --timeout=5s CMD nc -z 127.0.0.1 4822 || exit 1

EXPOSE 4822

ENTRYPOINT ["./entrypoint.sh"]
