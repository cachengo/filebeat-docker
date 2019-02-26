FROM golang:1.11 as builder

RUN apt-get update \
    && apt-get -y install python python-pip libsystemd-dev libpcap-dev librpm-dev \
    && pip install jinja2-cli[yaml]==0.6.0 jinja2==2.9.5

COPY VERSION /VERSION

RUN mkdir /build \
    && VERSION=$(cat /VERSION) \
    && go get github.com/elastic/beats/... \
    && cd $(go env GOPATH)/src/github.com/elastic/beats/filebeat/ \
    && ls \
    && git checkout "v${VERSION}" \
    && go build \
    && cp filebeat /build/filebeat \
    && cp -r module /build/module \
    && cp -r modules.d /build/modules.d \
    && cp filebeat.reference.yml /build/filebeat.reference.yml \
    && rm -rf $(go env GOPATH)/src/github.com/elastic/beats

RUN VERSION=$(cat /VERSION) \
    && git clone https://github.com/elastic/beats-docker.git \
    && cd beats-docker \
    && git checkout $VERSION \
    && cp -r build/filebeat/config/* /build \
    && jinja2 \
	     -D beat=filebeat \
	      templates/docker-entrypoint.j2 > /build/docker-entrypoint \
	  && chmod +x /build/docker-entrypoint \
    && rm -rf beats-docker

FROM centos:7

ENV BEAT_HOME=/usr/share/filebeat
ENV ELASTIC_CONTAINER true
ENV PATH=/usr/share/filebeat:$PATH
COPY --from=builder /build /usr/share/filebeat
COPY --from=builder /build/docker-entrypoint /usr/local/bin

# Provide a non-root user.
RUN groupadd --gid 1000 filebeat && \
    useradd -M --uid 1000 --gid 1000 --home $BEAT_HOME filebeat

WORKDIR /usr/share/filebeat
RUN mkdir data logs && \
    chown -R root:filebeat . && \
    find $BEAT_HOME -type d -exec chmod 0750 {} \; && \
    find $BEAT_HOME -type f -exec chmod 0640 {} \; && \
    chmod 0750 $BEAT_HOME/filebeat && \
    chmod 0770 modules.d && \
    chmod 0770 data logs

USER 1000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
CMD ["-e"]
