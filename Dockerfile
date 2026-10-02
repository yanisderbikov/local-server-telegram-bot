FROM debian:bookworm-slim AS build
ARG TELEGRAM_BOT_API_REF=e3e9dd8e5b3d7ab8537cd5a10dc31d5ffa8f82d1
ARG BUILD_JOBS=2
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git cmake g++ make gperf libssl-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git init && git remote add origin https://github.com/tdlib/telegram-bot-api.git \
    && git fetch --depth 1 origin "$TELEGRAM_BOT_API_REF" \
    && git checkout --detach FETCH_HEAD && git submodule update --init --recursive --depth 1
RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/telegram \
    && cmake --build build --target install --parallel "$BUILD_JOBS"

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libssl3 zlib1g libstdc++6 curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 bot && useradd --uid 10001 --gid bot --create-home bot \
    && mkdir -p /var/lib/telegram-bot-api/temp && chown -R bot:bot /var/lib/telegram-bot-api
COPY --from=build /opt/telegram/bin/telegram-bot-api /usr/local/bin/telegram-bot-api
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
USER 10001:10001
ENV TELEGRAM_HTTP_PORT=8081 TELEGRAM_DATA_DIR=/var/lib/telegram-bot-api TELEGRAM_TEMP_DIR=/var/lib/telegram-bot-api/temp TELEGRAM_VERBOSITY=1
EXPOSE 8081
STOPSIGNAL SIGTERM
ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]
