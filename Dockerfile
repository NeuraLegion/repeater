#
# Builder
#

FROM ubuntu:19.10 AS builder

LABEL org.opencontainers.image.vendor="NeuraLegion"
LABEL org.opencontainers.image.title="Repeater"
LABEL org.opencontainers.image.source="https://github.com/NeuraLegion/repeater"
LABEL org.opencontainers.image.authors="Bar Hofesh <bar.hofesh@neuralegion.com>, \
  Anatol Karalkou <anatol.karalkou@neuralegion.com>, \
  Sijawusz Pur Rahnama <sija@sija.pl>"

ARG DEBIAN_FRONTEND=noninteractive

ARG CRYSTAL_WORKERS=8
ENV CRYSTAL_WORKERS=$CRYSTAL_WORKERS

RUN apt-get update -qq --fix-missing
RUN apt-get install -y --no-install-recommends apt-utils ca-certificates curl gnupg libdbus-1-dev \
  build-essential libevent-dev libssl-dev libyaml-dev libgmp-dev git \
  libxml2 libxml2-dev libxslt1-dev build-essential patch zlib1g-dev liblzma-dev libevent-pthreads-2.1-6
RUN apt-key adv --fetch-keys "https://keybase.io/crystal/pgp_keys.asc"
RUN echo "deb https://dist.crystal-lang.org/apt crystal main" | tee /etc/apt/sources.list.d/crystal.list
RUN apt-get update -qq
RUN apt-get install -y --no-install-recommends crystal


# Create relevant directories
RUN mkdir -p /opt/repeater

WORKDIR /opt/repeater

COPY src ./src
COPY spec ./spec
# COPY spec_integration ./spec_integration
COPY shard.yml ./

# Install dependencies
RUN shards install

# Build Repeater
RUN shards build -p --error-trace --warnings=all --error-on-warnings -Dpreview_mt

#
# NexPloit
#

FROM ubuntu:19.10

ARG CRYSTAL_WORKERS=8
ENV CRYSTAL_WORKERS=$CRYSTAL_WORKERS


RUN apt-get update -qq --fix-missing && apt-get install -y --no-install-recommends openssl \
  libssl1.1 libdbus-1-3 libxml2 libxml2-dev libevent-2.1 apt-utils git ca-certificates \
  curl libyaml-0-2 libxslt1-dev build-essential patch zlib1g-dev liblzma-dev \
  libevent-pthreads-2.1-6

WORKDIR /opt/repeater

COPY --from=builder /opt/repeater/bin/repeater /usr/bin/


ENTRYPOINT ["/usr/bin/repeater"]
