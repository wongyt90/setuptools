#!/usr/bin/env bash
#

BASE_DIR=$(dirname "$0")
PROJECT_DIR=$(dirname $(cd $(dirname "$0");pwd))
source ${PROJECT_DIR}/config.conf

function prepare_set() {
    cp $BASE_DIR/nginx/nginx.repo /etc/yum.repos.d/nginx.repo
}

function install_nginx() {
    echo ">> Install Nginx"
    yum localinstall -y $BASE_DIR/nginx/nginx-1.18.0-1.el7.ngx.x86_64.rpm
}

function download_lina() {
    if [ ! -f "$PROJECT_DIR/$Version/lina.tar.gz" ]; then
        wget -qO $PROJECT_DIR/$Version/lina.tar.gz http://demo.jumpserver.org/download/lina/$Version/lina.tar.gz
    fi
    tar xf $PROJECT_DIR/$Version/lina.tar.gz -C $install_dir/ || {
        rm -rf $PROJECT_DIR/$Version/lina.tar.gz
        rm -rf $install_dir/lina
        echo "[ERROR] 下载 lina 失败"
    }
    if [ "$(getenforce)" != "Disabled" ]; then
        restorecon -R $install_dir/lina/
    fi
}

function download_luna() {
    if [ ! -f "$PROJECT_DIR/$Version/luna.tar.gz" ]; then
        wget -qO $PROJECT_DIR/$Version/luna.tar.gz http://demo.jumpserver.org/download/luna/$Version/luna.tar.gz
    fi
    tar xf $PROJECT_DIR/$Version/luna.tar.gz -C $install_dir/ || {
        rm -rf $PROJECT_DIR/$Version/luna.tar.gz
        rm -rf $install_dir/luna
        echo "[ERROR] 下载 luna 失败"
    }
    if [ "$(getenforce)" != "Disabled" ]; then
        restorecon -R $install_dir/luna/
        restorecon -R $install_dir/lina/
    fi
}

function start_nginx() {
    systemctl start nginx
    systemctl enable nginx
}

function config_nginx() {
    echo > /etc/nginx/conf.d/default.conf
    wget -O /etc/nginx/conf.d/jumpserver.conf http://demo.jumpserver.org/download/nginx/conf.d/$Version/jumpserver.conf || {
        rm -rf /etc/nginx/conf.d/jumpserver.conf
        cp $BASE_DIR/nginx/jumpserver.conf /etc/nginx/conf.d/jumpserver.conf
    }
    if [ "$http_port" != "80" ]; then
        sed -i "s@listen 80;@listen $http_port;@g" /etc/nginx/conf.d/jumpserver.conf
    fi
    if [ $install_dir != "/opt" ]; then
        sed -i "s@/opt@$install_dir@g" /etc/nginx/conf.d/jumpserver.conf
    fi
    sed -i "s@worker_processes  1;@worker_processes  auto;@g" /etc/nginx/nginx.conf
}

function main {
    if [ ! -f "/etc/yum.repos.d/nginx.repo" ]; then
        prepare_set
    fi
    which nginx >/dev/null 2>&1
    if [ $? -ne 0 ];then
        install_nginx
    fi
    if [ ! -f /etc/nginx/conf.d/jumpserver.conf ];then
        config_nginx
    fi
    if [ ! "$(systemctl status nginx | grep Active | grep running)" ]; then
        start_nginx
    fi
    if [ "${Version:0:1}" == "1" ]; then
        if [ ! -d "$install_dir/luna" ]; then
            download_luna
        fi
    elif [ "${Version:0:1}" == "2" ]; then
        if [ ! -d "$install_dir/lina" ]; then
            download_lina
        fi
        if [ ! -d "$install_dir/luna" ]; then
            download_luna
        fi
    fi
}

main
