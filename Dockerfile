ARG GRAFANA_VERSION="latest"

# Base image with Grafana
FROM grafana/grafana:${GRAFANA_VERSION}

# Copy custom configuration files
COPY ./grafana/grafana.ini /etc/grafana/grafana.ini
COPY ./grafana/ldap.toml /etc/grafana/ldap.toml
COPY ./grafana/provisioning /etc/grafana/provisioning


# Arguments and Environment variables
ARG GF_INSTALL_IMAGE_RENDERER_PLUGIN="false"
ARG GF_GID="0"
ARG GF_INSTALL_PLUGINS=""

ENV GF_PATHS_PLUGINS="/var/lib/grafana-plugins"
ENV GF_PLUGIN_RENDERING_CHROME_BIN="/usr/bin/chrome"
ENV GF_PATHS_CONFIG="/etc/grafana/grafana.ini"
ENV GF_PATHS_PROVISIONING="/etc/grafana/provisioning"

# Set up the file system and install necessary packages
USER root

RUN mkdir -p "$GF_PATHS_PLUGINS" && \
    chown -R grafana:${GF_GID} "$GF_PATHS_PLUGINS" && \
    mkdir -p /etc/grafana && \
    chown -R grafana:${GF_GID} /etc/grafana && \
    if [ $GF_INSTALL_IMAGE_RENDERER_PLUGIN = "true" ]; then \
      if grep -i -q alpine /etc/issue; then \
        apk add --no-cache udev ttf-opensans chromium && \
        ln -s /usr/bin/chromium-browser "$GF_PLUGIN_RENDERING_CHROME_BIN"; \
      else \
        cd /tmp && \
        curl -sLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
        DEBIAN_FRONTEND=noninteractive && \
        apt-get update -q && \
        apt-get install -q -y ./google-chrome-stable_current_amd64.deb && \
        rm -rf /var/lib/apt/lists/* && \
        rm ./google-chrome-stable_current_amd64.deb && \
        ln -s /usr/bin/google-chrome "$GF_PLUGIN_RENDERING_CHROME_BIN"; \
      fi \
    fi

# Switch to grafana user
USER grafana

# Install Image Renderer plugin if needed
RUN if [ $GF_INSTALL_IMAGE_RENDERER_PLUGIN = "true" ]; then \
      grafana-cli \
        --pluginsDir "$GF_PATHS_PLUGINS" \
        --pluginUrl https://github.com/grafana/grafana-image-renderer/releases/latest/download/plugin-linux-x64-glibc-no-chromium.zip \
        plugins install grafana-image-renderer; \
    fi

# Install other specified plugins
RUN if [ ! -z "${GF_INSTALL_PLUGINS}" ]; then \
      OLDIFS=$IFS; \
      IFS=','; \
      for plugin in ${GF_INSTALL_PLUGINS}; do \
        IFS=$OLDIFS; \
        if expr match "$plugin" '.*\;.*'; then \
          pluginUrl=$(echo "$plugin" | cut -d';' -f 1); \
          pluginInstallFolder=$(echo "$plugin" | cut -d';' -f 2); \
          grafana-cli --pluginUrl ${pluginUrl} --pluginsDir "${GF_PATHS_PLUGINS}" plugins install "${pluginInstallFolder}"; \
        else \
          grafana-cli --pluginsDir "${GF_PATHS_PLUGINS}" plugins install ${plugin}; \
        fi \
      done \
    fi

expose 3000
