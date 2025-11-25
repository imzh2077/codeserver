FROM codercom/code-server:latest

USER root

# 合并系统依赖安装和环境安装
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        iputils-ping dnsutils net-tools iproute2 tcpdump netcat-openbsd traceroute mtr-tiny iperf3 nmap telnet openssh-client \ 
        htop iotop lsof procps sysstat file tree nano \
        curl wget gnupg software-properties-common build-essential gcc g++ python3 python3-pip git vim lsb-release ca-certificates sudo gdb && \
    # 创建python符号链接
    ln -sf /usr/bin/python3 /usr/bin/python && \
    # 安装 PHP 相关依赖和仓库
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    apt-get update && \
    apt-get install -y  \
        php8.4 php8.4-cli php8.4-common php8.4-curl php8.4-xml php8.4-mbstring php8.4-zip && \
    # 清理
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 切换到coder用户安装nvm和Node.js
USER coder
WORKDIR /home/coder

# 设置环境变量
ENV NVM_DIR=/home/coder/.nvm
ENV NVM_VERSION=0.40.3
ENV NODE_VERSIONS="22"

# 合并 nvm 安装和配置
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh | bash && \
    chmod +x $NVM_DIR/nvm.sh && \
    . $NVM_DIR/nvm.sh && \
    for version in $NODE_VERSIONS; do nvm install $version; done && \
    nvm install-latest-npm && \
    nvm use 22 && \
    nvm alias default 22 && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> /home/coder/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> /home/coder/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> /home/coder/.bashrc

# 将nvm路径添加到PATH环境变量
ENV PATH=$NVM_DIR/versions/node/v22/bin:$PATH

# 切换回root用户进行权限设置
USER root

# 设置权限并验证安装
RUN chown -R coder:coder /home/coder && \
    chmod -R 755 /home/coder && \
    echo "=== 验证安装结果 ===" && \
    python --version && \
    python3 --version && \
    php --version && \
    gdb --version  # 验证GDB安装

# 最终切换回coder用户
USER coder
WORKDIR /home/coder

# 设置环境变量
ENV SHELL=/bin/bash
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 创建启动脚本，确保nvm环境正确加载
RUN cat > /home/coder/start.sh << 'EOF'
#!/bin/bash
# 加载nvm环境
if [ -s "$NVM_DIR/nvm.sh" ]; then
    source $NVM_DIR/nvm.sh
    # 设置默认Node.js版本
    nvm use default
fi
# 启动code-server
exec code-server --bind-addr=0.0.0.0:8080 .
EOF

RUN chmod +x /home/coder/start.sh

# 使用启动脚本作为入口点
CMD ["/home/coder/start.sh"]
