FROM codercom/code-server:latest

USER root

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

# 安装 OpenJDK 17 和 21
RUN apt-get update && \
    # 安装软件属性通用包（用于add-apt-repository）
    apt-get install -y software-properties-common && \
    # 添加OpenJDK官方仓库
    add-apt-repository -y ppa:openjdk-r/ppa && \
    apt-get update && \
    # 安装OpenJDK 17和21
    apt-get install -y \
        openjdk-17-jdk \
        openjdk-21-jdk \
        && \
    # 设置默认JDK为21
    update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java && \
    update-alternatives --set javac /usr/lib/jvm/java-21-openjdk-amd64/bin/javac && \
    rm -rf /var/lib/apt/lists/*

# 设置 JAVA_HOME 环境变量（默认使用JDK 21）
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# 配置JDK版本切换（可选配置）
RUN update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-17-openjdk-amd64/bin/java 1171 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac 1171 && \
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-21-openjdk-amd64/bin/java 1211 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-21-openjdk-amd64/bin/javac 1211

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
    . $NVM_DIR/nvm.sh && node --version && npm --version && \
    java -version && \
    javac -version && \
    echo "JAVA_HOME: $JAVA_HOME"

# 创建JDK版本切换脚本
RUN cat > /home/coder/switch-jdk.sh << 'EOF'
#!/bin/bash
echo "可用的JDK版本:"
echo "1) OpenJDK 17"
echo "2) OpenJDK 21"
echo -n "请选择JDK版本 (1 或 2): "
read choice

case $choice in
    1)
        sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
        sudo update-alternatives --set javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac
        export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
        echo "已切换到 OpenJDK 17"
        ;;
    2)
        sudo update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java
        sudo update-alternatives --set javac /usr/lib/jvm/java-21-openjdk-amd64/bin/javac
        export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
        echo "已切换到 OpenJDK 21"
        ;;
    *)
        echo "无效选择，保持当前版本"
        ;;
esac

echo "当前Java版本:"
java -version
echo "JAVA_HOME: $JAVA_HOME"
EOF

RUN chmod +x /home/coder/switch-jdk.sh

# 创建启动脚本，确保nvm环境正确加载
RUN cat > /home/coder/start.sh << 'EOF'
#!/bin/bash
# 加载nvm环境
if [ -s "$NVM_DIR/nvm.sh" ]; then
    source $NVM_DIR/nvm.sh
    # 设置默认Node.js版本
    nvm use default
fi

# 显示当前环境信息
echo "=== 开发环境信息 ==="
echo "Node.js版本: $(node --version)"
echo "npm版本: $(npm --version)"
echo "Python版本: $(python3 --version)"
echo "PHP版本: $(php --version | head -n1)"
echo "Java版本: $(java -version 2>&1 | head -n1)"
echo "JAVA_HOME: $JAVA_HOME"
echo "=================="

# 启动code-server
exec code-server --bind-addr=0.0.0.0:8080 .
EOF

RUN chmod +x /home/coder/start.sh

# 使用启动脚本作为入口点
CMD ["/home/coder/start.sh"]
