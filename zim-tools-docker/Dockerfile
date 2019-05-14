FROM debian:stretch-slim  
MAINTAINER kiwix

ENV ZIM_TOOL_VERSION=1.0.1


RUN apt-get update && apt-get install -y --no-install-recommends wget && rm -r /var/lib/apt/lists/*

RUN wget -q http://download.openzim.org/release/zim-tools/zim-tools_linux-x86_64-$ZIM_TOOL_VERSION.tar.gz && \
  tar -xzf zim-tools_linux-x86_64-$ZIM_TOOL_VERSION.tar.gz && \
  cp zim-tools_linux-x86_64-$ZIM_TOOL_VERSION/* /usr/local/bin/ && \
  rm -rf zim-tools_linux-x86_64-$ZIM_TOOL_VERSION*

CMD bash
