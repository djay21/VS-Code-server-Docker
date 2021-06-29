
FROM ubuntu:latest

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    TZ=America/Los_Angeles \
# adding a sane default is needed since we're not erroring out via exec.
    CODER_PASSWORD="coder" \
    oc_version="v3.11.0" \
    oc_version_commit="0cbc58b" \
    PATH="${PATH}:/home/coder/.local/bin"

COPY exec /opt
RUN . /etc/lsb-release && \
    apt-get update && apt install software-properties-common -y &&\
    export DEBIAN_FRONTEND=noninteractive && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime && \
    apt-get install -y curl locales gnupg2 tzdata && locale-gen en_US.UTF-8 && \
    curl -sL https://deb.nodesource.com/setup_current.x | bash - && \
    apt-get upgrade -y && \
    apt-get install -y  \
      sudo \
      openssl \
      net-tools \
      openvpn \
      jq \
      git \
      tree \
      locales \ 
      curl \
      dumb-init \
      wget \
      httpie \
      nodejs \
      python \
      python3-pip \
      joe \
      certbot \
      ansible \
      nano \
      iputils-ping \
      dnsutils \
      unzip \
      bash-completion \
      openssh-client \
      maven && \
    npm install -g npm && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* 


RUN wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.6.2.2472-linux.zip
RUN unzip sonar* && rm -rf *.zip && mkdir -m 777 /opt/sonar-scanner
RUN mv sonar* /opt/sonar-scanner
RUN ln -s /opt/sonar-scanner/sonar-scanner-4.6.2.2472-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner
RUN sonar-scanner --version

RUN locale-gen en_US.UTF-8 && \
    cd /tmp && \
# install code-server
    ansible localhost -m apt -a "deb=$(curl -s https://api.github.com/repos/cdr/code-server/releases/latest |  jq -r '.assets[] | select(.browser_download_url | contains("amd64.deb")) | .browser_download_url')" && \
# install openshift/kubernetes client tools
    wget -O - https://github.com/openshift/origin/releases/download/${oc_version}/openshift-origin-client-tools-${oc_version}-${oc_version_commit}-linux-64bit.tar.gz | tar -xzv --strip 1 openshift-origin-client-tools-${oc_version}-${oc_version_commit}-linux-64bit/oc openshift-origin-client-tools-${oc_version}-${oc_version_commit}-linux-64bit/kubectl && \
    mv oc kubectl /usr/bin/ && \
    /usr/bin/oc completion bash >> /etc/bash_completion.d/oc_completion && \
    /usr/bin/kubectl completion bash >> /etc/bash_completion.d/kubectl_completion && \
# for openvpn
    mkdir -p /dev/net && \
    mknod /dev/net/tun c 10 200 && \
    chmod 600 /dev/net/tun && \
    echo "user ALL=(ALL) NOPASSWD: /usr/sbin/openvpn --config /home/coder/projects/.openvpn/openvpn-client-conf.ovpn" >> /etc/sudoers.d/openvpn-client && \
# add user coder
    adduser --disabled-password --gecos '' coder && \
    echo '%sudo ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd && \
    chmod g+rw /home/coder && \
    chmod a+x /opt/exec && \
    chgrp -R 0 /home/coder /etc/ansible && \
    chmod -R g=u /home/coder /etc/ansible /etc/resolv.conf && \
    chmod g=u /etc/passwd /etc/resolv.conf /etc/ssl/certs/ca-certificates.crt

ENV LC_ALL=en_US.UTF-8
WORKDIR /home/coder

USER coder
RUN ls -lart
RUN mkdir -p projects certs pip_install && \
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.35.3/install.sh | bash && \
    sudo chmod -R g+rw projects/ && \
    sudo chmod -R g+rw certs/ && \
    sudo chmod -R g+rw .nvm && \
    sudo chmod -R g+rwx .npm && \
    sudo chmod -R g+rwx pip_install && \
    sudo chmod -R g+rwx /usr/lib/node_modules && \
    sudo chmod -R g+rwx /usr/bin/  /usr/local/bin/sonar-scanner && \
    sudo rm -frv .config/ && \
    sudo chgrp -R 0 /home/coder

ENV PIP_TARGET=/home/coder/pip_install
COPY entrypoint /home/coder

VOLUME ["/home/coder/projects", "/home/coder/certs"];

USER 10001

ENTRYPOINT ["/home/coder/entrypoint"]

EXPOSE 9000 8080

CMD ["/opt/exec"]
