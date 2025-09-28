FROM codercom/code-server:4.104.1

USER root

# 创建coder用户并设置权限
RUN adduser --disabled-password --gecos '' coder && \
    adduser coder sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# 安装系统依赖
RUN apt-get update && \
    apt-get install -y \
        curl \
        wget \
        gnupg \
        software-properties-common \
        build-essential \
        gcc \
        g++ \
        python3 \
        python3-pip \
        git \
        vim \
        lsb-release \
        ca-certificates \
        sudo \
        && rm -rf /var/lib/apt/lists/*

# 安装 Python 3.13
RUN wget https://www.python.org/ftp/python/3.13.0/Python-3.13.0.tgz && \
    tar -xzf Python-3.13.0.tgz && \
    cd Python-3.13.0 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf Python-3.13.0* && \
    python3 --version

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

# 切换到coder用户安装nvm和Node.js
USER coder
WORKDIR /home/coder

# 设置环境变量
ENV NVM_DIR=/home/coder/.nvm
ENV NVM_VERSION=0.40.3
ENV NODE_VERSIONS="16 18 20 22"

# 安装nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh | bash

# 确保nvm脚本可执行
RUN chmod +x $NVM_DIR/nvm.sh

# 安装指定的Node.js版本并设置默认版本
RUN . $NVM_DIR/nvm.sh && \
    for version in $NODE_VERSIONS; do nvm install $version; done && \
    nvm install-latest-npm && \
    nvm use 18 && \
    nvm alias default 18

# 将nvm初始化添加到shell配置文件中
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> /home/coder/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> /home/coder/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> /home/coder/.bashrc

# 将nvm路径添加到PATH环境变量
ENV PATH=$NVM_DIR/versions/node/v18/bin:$PATH

# 切换回root用户进行权限设置和清理
USER root

# 确保coder用户对相关目录有适当权限
RUN chown -R coder:coder /home/coder && \
    chmod -R 755 /home/coder

# 清理缓存和临时文件
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 最终切换回coder用户
USER coder
WORKDIR /home/coder

# 设置环境变量
ENV SHELL=/bin/bash
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 验证安装
RUN echo "=== 验证安装结果 ===" && \
    python3 --version && \
    php --version && \
    . $NVM_DIR/nvm.sh && node --version && npm --version

# 创建启动脚本，确保nvm环境正确加载
RUN cat > /home/coder/start.sh << 'EOF'
#!/bin/bash
# 加载nvm环境
source $NVM_DIR/nvm.sh
# 设置默认Node.js版本
nvm use default
# 启动code-server
exec code-server --bind-addr=0.0.0.0:8080 .
EOF

RUN chmod +x /home/coder/start.sh

# 使用启动脚本作为入口点
CMD ["/home/coder/start.sh"]