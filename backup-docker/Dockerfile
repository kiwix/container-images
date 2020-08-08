FROM debian:stretch-slim
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"


RUN apt-get update && \
    apt-get install -y --no-install-recommends curl jq borgbackup vim python3 python3-pip python3-setuptools openssh-client unzip && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN curl -Ls 'https://vault.bitwarden.com/download/?app=cli&platform=linux' -o bitwarden.zip && \
    unzip bitwarden.zip && rm -f bitwarden.zip && chmod +x bw && mv bw /usr/local/bin/

RUN pip3 install --user --upgrade borgmatic

# Install start script
COPY bin/ /usr/local/bin/
RUN chmod -R 0500 /usr/local/bin/*

ENTRYPOINT ["entrypoint.sh"]
