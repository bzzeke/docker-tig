FROM alpine:latest

ARG STORAGE_UID
ARG STORAGE_GID

ENV TELEGRAF_VERSION 1.11.0
ENV INFLUXDB_VERSION 1.7.6
ENV GRAFANA_VERSION 6.2.4

WORKDIR /app
VOLUME /app

RUN apk add --no-cache iputils py-pip tzdata
RUN pip install speedtest-cli

# Install telegraf and influxdb (# Install influxdb
# https://github.com/influxdata/influxdata-docker/blob/master/telegraf/1.7/alpine/Dockerfile
RUN set -ex && \
    apk add --no-cache --virtual .build-deps wget gnupg tar && \
    for key in \
        05CE15085FC09D18E99EFB22684A14CF2582E0C5 ; \
    do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
        gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
        gpg --keyserver keyserver.pgp.com --recv-keys "$key" ; \
    done && \
    wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz.asc && \
    wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz && \
    gpg --batch --verify telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz.asc telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz && \
    mkdir -p /usr/src /etc/telegraf && \
    tar -C /usr/src -xzf telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz && \
    mv /usr/src/telegraf*/telegraf.conf /etc/telegraf/ && \
    chmod +x /usr/src/telegraf*/* && \
    cp -a /usr/src/telegraf*/* /usr/bin/ && \
    rm -rf *.tar.gz* /usr/src /root/.gnupg && \
    apk del .build-deps

EXPOSE 8125/udp 8092/udp 8094


# Install influxdb
# https://github.com/influxdata/influxdata-docker/blob/master/influxdb/1.5/Dockerfile
RUN set -ex && \
    apk add --no-cache --virtual .build-deps wget gnupg tar ca-certificates && \
    update-ca-certificates && \
    for key in \
        05CE15085FC09D18E99EFB22684A14CF2582E0C5 ; \
    do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
        gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
        gpg --keyserver keyserver.pgp.com --recv-keys "$key" ; \
    done && \
    wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz.asc && \
    wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz && \
    gpg --batch --verify influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz.asc influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz && \
    mkdir -p /usr/src && \
    tar -C /usr/src -xzf influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz && \
    rm -f /usr/src/influxdb-*/influxdb.conf && \
    chmod +x /usr/src/influxdb-*/* && \
    cp -a /usr/src/influxdb-*/* /usr/bin/ && \
    rm -rf *.tar.gz* /usr/src /root/.gnupg && \
    apk del .build-deps
EXPOSE 8083 8086


# Install grafana
# https://github.com/orangesys/alpine-grafana/blob/master/4.2.0/Dockerfile
RUN set -ex \
 && addgroup -g ${STORAGE_GID} -S grafana \
 && adduser -u ${STORAGE_UID} -g ${STORAGE_GID} -S grafana \
 && apk add --no-cache libc6-compat ca-certificates su-exec \
 && mkdir /tmp/setup \
 && wget -P /tmp/setup http://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz \
 && tar -xzf /tmp/setup/grafana-$GRAFANA_VERSION.linux-amd64.tar.gz -C /tmp/setup --strip-components=1 \
 && install -m 755 /tmp/setup/bin/grafana-server /usr/local/bin/ \
 && install -m 755 /tmp/setup/bin/grafana-cli /usr/local/bin/ \
 && mkdir -p /grafana/datasources /grafana/dashboards /grafana/data /grafana/logs /grafana/plugins /var/lib/grafana \
 && cp -r /tmp/setup/public /grafana/public \
 && chown -R grafana:grafana /grafana \
 && ln -s /grafana/plugins /var/lib/grafana/plugins \
 && grafana-cli plugins update-all \
 && rm -rf /tmp/setup

EXPOSE 3000

VOLUME ["/var/lib/influxdb", "/grafana/data", "/grafana/logs"]

# Install supervisord
RUN apk --no-cache add supervisor
RUN mkdir -p /grafana/conf
COPY config/supervisord/supervisord.conf /etc/supervisord.conf

# Configuration
COPY config/telegraf/telegraf.conf /etc/telegraf/telegraf.conf
COPY config/influxdb/influxdb.conf /etc/influxdb/influxdb.conf
COPY config/grafana/defaults.ini /grafana/conf/defaults.ini

ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]

