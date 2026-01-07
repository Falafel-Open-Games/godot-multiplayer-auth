ARG GODOT_IMAGE=fczuardi/godot-ci:4.5.1
FROM ${GODOT_IMAGE}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends fontconfig \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY godot /app/godot

ENV WS_PORT=8081
EXPOSE 8081

ENTRYPOINT ["godot", "--headless", "--path", "/app/godot", "--scene", "res://ws_server.tscn"]
