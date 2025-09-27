FROM codercom/code-server:4.104.1

USER root

# 安装基础工具和依赖
RUN apt-get update && \
    apt-get install -y \
        curl \
        wget \
        gnupg \
        software-properties-common \
        build-essential \
        gcc \
        g++ \
        openjdk-11-jdk \
        python3 \
        python3-pip \
        && rm -rf /var/lib/apt/lists/*

# 安装 Python 3.13
RUN wget https://www.python.org/ftp/python/3.13.0/Python-3.13.0.tgz && \
    tar -xzf Python-3.13.0.tgz && \
    cd Python-3.13.0 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf Python-3.13.0*

# 安装 NVM 和 Node.js 版本
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSIONS="16 18 20 22"

RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    for version in $NODE_VERSIONS; do nvm install $version; done && \
    nvm alias default 22

# 将 NVM 添加到 PATH
ENV PATH $NVM_DIR/versions/node/v22/bin:$PATH

# 安装 PHP 7.4 和 8.4
RUN apt-get update && \
    apt-get install -y lsb-release ca-certificates && \
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    apt-get update && \
    apt-get install -y \
        php7.4 \
        php7.4-cli \
        php7.4-common \
        php7.4-curl \
        php7.4-xml \
        php7.4-mbstring \
        php7.4-zip \
        php8.4 \
        php8.4-cli \
        php8.4-common \
        php8.4-curl \
        php8.4-xml \
        php8.4-mbstring \
        php8.4-zip \
        && rm -rf /var/lib/apt/lists/*

# 设置 PHP 替代版本（默认使用 PHP 8.4）
RUN update-alternatives --set php /usr/bin/php8.4

# 安装常用工具和清理
RUN apt-get update && \
    apt-get install -y \
        git \
        vim \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# 切换回 code-server 用户
USER 1000

# 设置工作目录
WORKDIR /home/coder

# 设置环境变量
ENV SHELL /bin/bash

# 验证安装
CMD ["code-server", "--bind-addr=0.0.0.0:8080", "."]
