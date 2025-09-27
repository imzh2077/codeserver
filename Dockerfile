FROM codercom/code-server:4.104.1

USER root

# 使用构建参数来定义镜像源，默认使用官方源（适合GitHub Actions海外环境）
ARG DEBIAN_MIRROR=deb.debian.org
ARG PYTHON_MIRROR=www.python.org
ARG NODEJS_MIRROR=https://nodejs.org/dist/
ARG NVM_URL=https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh
ARG PHP_MIRROR=packages.sury.org

# 替换 Apt 源为构建参数指定的源
RUN sed -i "s/deb.debian.org/${DEBIAN_MIRROR}/g" /etc/apt/sources.list && \
    sed -i "s/security.debian.org/${DEBIAN_MIRROR}/g" /etc/apt/sources.list

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
        lsb-release \
        ca-certificates \
        && rm -rf /var/lib/apt/lists/*

# 安装 Python 3.13
RUN wget ${PYTHON_MIRROR}/ftp/python/3.13.0/Python-3.13.0.tgz && \
    tar -xzf Python-3.13.0.tgz && \
    cd Python-3.13.0 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf Python-3.13.0* && \
    ln -sf /usr/local/bin/python3.13 /usr/local/bin/python3

# 安装 NVM 和 Node.js 版本
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSIONS="16 18 20 22"

RUN mkdir -p $NVM_DIR && \
    curl -o- ${NVM_URL} | bash && \
    . $NVM_DIR/nvm.sh && \
    for version in $NODE_VERSIONS; do nvm install $version; done && \
    nvm alias default 22 && \
    nvm use default

# 将 NVM 添加到 PATH
ENV PATH $NVM_DIR/versions/node/v22/bin:$PATH

# 安装 PHP 7.4 和 8.4
RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://${PHP_MIRROR}/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
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

# 配置 pip 使用国内镜像（可选，如果DEBIAN_MIRROR是国外源则不需要）
# RUN pip3 config set global.index-url https://pypi.org/simple/

# 安装常用工具和清理
RUN apt-get update && \
    apt-get install -y \
        git \
        vim \
        htop \
        tree \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# 配置 npm 使用官方镜像
RUN . $NVM_DIR/nvm.sh && nvm use default && \
    npm config set registry https://registry.npmjs.org/

# 创建代码目录并设置权限
RUN mkdir -p /workspace && chown -R 1000:1000 /workspace

# 切换回 code-server 用户
USER 1000

# 设置工作目录
WORKDIR /workspace

# 设置环境变量
ENV SHELL /bin/bash

# 验证安装
CMD ["code-server", "--bind-addr=0.0.0.0:8080", "/workspace"]
