#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)
primary_repo="CodeManXposed/XrayR-P"
backup_repos=("metamoss/XrayR" "XrayR-project/XrayR" "HungSoKie/XrayR")
raw_main="https://raw.githubusercontent.com/CodeManXposed/XrayR-P/main"
raw_backup="https://raw.githubusercontent.com/unicorncross/XrayR-onekey-install/main"

[[ $EUID -ne 0 ]] && echo -e "${red}错误:${plain} 必须使用 root 用户运行此脚本！" && exit 1

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_release() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif grep -Eqi "debian" /etc/issue 2>/dev/null || grep -Eqi "debian" /proc/version 2>/dev/null; then
        release="debian"
    elif grep -Eqi "ubuntu" /etc/issue 2>/dev/null || grep -Eqi "ubuntu" /proc/version 2>/dev/null; then
        release="ubuntu"
    elif grep -Eqi "centos|red hat|redhat|rocky|alma" /etc/issue 2>/dev/null || grep -Eqi "centos|red hat|redhat|rocky|alma" /proc/version 2>/dev/null; then
        release="centos"
    else
        echo -e "${red}未检测到系统版本，当前脚本支持 Debian/Ubuntu/CentOS/RHEL 系。${plain}"
        exit 1
    fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) arch="64" ;;
        i386|i686) arch="32" ;;
        aarch64|arm64) arch="arm64-v8a" ;;
        armv7l|armv7*) arch="arm32-v7a" ;;
        armv6l|armv6*) arch="arm32-v6" ;;
        armv5tel|armv5*) arch="arm32-v5" ;;
        mips64le) arch="mips64le" ;;
        mips64) arch="mips64" ;;
        mipsle) arch="mips32le" ;;
        mips) arch="mips32" ;;
        ppc64le) arch="ppc64le" ;;
        riscv64) arch="riscv64" ;;
        s390x) arch="s390x" ;;
        *)
            echo -e "${red}不支持的架构: $(uname -m)${plain}"
            exit 1
            ;;
    esac
    echo -e "系统架构: ${green}linux-${arch}${plain}"
}

install_base() {
    if [[ "${release}" == "centos" ]]; then
        if command_exists dnf; then
            dnf install -y wget curl unzip tar ca-certificates socat
        else
            yum install -y epel-release
            yum install -y wget curl unzip tar ca-certificates socat
        fi
    else
        apt-get update -y
        apt-get install -y wget curl unzip tar ca-certificates socat
    fi
}

normalize_version() {
    if [[ -z "$1" ]]; then
        echo ""
    elif [[ "$1" == v* ]]; then
        echo "$1"
    else
        echo "v$1"
    fi
}

download() {
    local url="$1"
    local out="$2"

    if command_exists curl; then
        curl -L --fail --connect-timeout 15 --retry 2 --retry-delay 2 -o "$out" "$url"
    else
        wget -q --timeout=20 --tries=2 --no-check-certificate -O "$out" "$url"
    fi
}

try_download_binary() {
    local repo="$1"
    local version="$2"
    local out="$3"
    local url=""

    if [[ -z "${version}" ]]; then
        url="https://github.com/${repo}/releases/latest/download/XrayR-linux-${arch}.zip"
    else
        url="https://github.com/${repo}/releases/download/${version}/XrayR-linux-${arch}.zip"
    fi

    echo -e "下载源: ${repo}"
    if download "${url}" "${out}"; then
        selected_repo="${repo}"
        return 0
    fi
    return 1
}

download_binary() {
    local version="$1"
    local out="/usr/local/XrayR/XrayR-linux.zip"
    selected_repo=""

    rm -f "${out}"
    if try_download_binary "${primary_repo}" "${version}" "${out}"; then
        return 0
    fi

    echo -e "${yellow}主源下载失败，开始尝试备用源。${plain}"
    for repo in "${backup_repos[@]}"; do
        rm -f "${out}"
        if try_download_binary "${repo}" "${version}" "${out}"; then
            return 0
        fi
    done

    echo -e "${red}下载 XrayR 失败，主源和备用源都不可用。${plain}"
    exit 1
}

install_service() {
    cat >/etc/systemd/system/XrayR.service <<'SERVICE'
[Unit]
Description=XrayR Service
After=network.target nss-lookup.target
Wants=network.target

[Service]
User=root
Group=root
Type=simple
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
LimitNOFILE=999999
WorkingDirectory=/usr/local/XrayR/
ExecStart=/usr/local/XrayR/XrayR --config /etc/XrayR/config.yml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload
    systemctl enable XrayR >/dev/null 2>&1
}

copy_config_if_missing() {
    mkdir -p /etc/XrayR

    [[ ! -f /etc/XrayR/config.yml && -f /usr/local/XrayR/config.yml ]] && cp /usr/local/XrayR/config.yml /etc/XrayR/config.yml
    [[ ! -f /etc/XrayR/dns.json && -f /usr/local/XrayR/dns.json ]] && cp /usr/local/XrayR/dns.json /etc/XrayR/dns.json
    [[ ! -f /etc/XrayR/route.json && -f /usr/local/XrayR/route.json ]] && cp /usr/local/XrayR/route.json /etc/XrayR/route.json
    [[ ! -f /etc/XrayR/custom_outbound.json && -f /usr/local/XrayR/custom_outbound.json ]] && cp /usr/local/XrayR/custom_outbound.json /etc/XrayR/custom_outbound.json
    [[ ! -f /etc/XrayR/custom_inbound.json && -f /usr/local/XrayR/custom_inbound.json ]] && cp /usr/local/XrayR/custom_inbound.json /etc/XrayR/custom_inbound.json
    [[ ! -f /etc/XrayR/rulelist && -f /usr/local/XrayR/rulelist ]] && cp /usr/local/XrayR/rulelist /etc/XrayR/rulelist
    [[ ! -f /etc/XrayR/geoip.dat && -f /usr/local/XrayR/geoip.dat ]] && cp /usr/local/XrayR/geoip.dat /etc/XrayR/geoip.dat
    [[ ! -f /etc/XrayR/geosite.dat && -f /usr/local/XrayR/geosite.dat ]] && cp /usr/local/XrayR/geosite.dat /etc/XrayR/geosite.dat
}

install_manager() {
    local manager="/usr/bin/XrayR"
    if ! download "${raw_main}/XrayR.sh" "${manager}"; then
        echo -e "${yellow}主源管理脚本下载失败，尝试备用管理脚本。${plain}"
        download "${raw_backup}/XrayR.sh" "${manager}" || {
            echo -e "${red}管理脚本下载失败。${plain}"
            exit 1
        }
    fi
    chmod +x "${manager}"
    ln -sf "${manager}" /usr/bin/xrayr
}

check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    systemctl is-active --quiet XrayR && return 0
    return 1
}

install_XrayR() {
    local version
    local had_config=0
    version=$(normalize_version "$1")
    [[ -f /etc/XrayR/config.yml ]] && had_config=1

    mkdir -p /usr/local/XrayR
    cd /usr/local/XrayR || exit 1

    echo -e "${green}开始下载 XrayR${plain}"
    if [[ -n "${version}" ]]; then
        echo -e "指定版本: ${version}"
    else
        echo -e "指定版本: 最新版"
    fi
    download_binary "${version}"

    systemctl stop XrayR >/dev/null 2>&1 || true
    unzip -o XrayR-linux.zip >/dev/null
    rm -f XrayR-linux.zip
    chmod +x /usr/local/XrayR/XrayR

    copy_config_if_missing
    install_service
    install_manager

    if [[ "${had_config}" == "1" ]]; then
        systemctl restart XrayR >/dev/null 2>&1 || true
    else
        echo -e "${yellow}首次安装已写入示例配置，请先编辑 /etc/XrayR/config.yml，然后执行 XrayR start。${plain}"
    fi

    echo -e "${green}XrayR 安装完成。${plain}"
    echo -e "实际下载源: ${green}${selected_repo}${plain}"
    check_status
    case $? in
        0) echo -e "运行状态: ${green}正常${plain}" ;;
        1) echo -e "运行状态: ${red}异常${plain}，请执行 ${yellow}XrayR log${plain} 查看日志。" ;;
        2) echo -e "运行状态: ${yellow}未安装${plain}" ;;
    esac

    cd "${cur_dir}" || exit 0
    rm -f install.sh
    echo ""
    echo "XrayR 管理脚本:"
    echo "------------------------------------------"
    echo "XrayR              - 数字交互菜单"
    echo "XrayR start        - 启动 XrayR"
    echo "XrayR stop         - 停止 XrayR"
    echo "XrayR restart      - 重启 XrayR"
    echo "XrayR status       - 查看运行状态"
    echo "XrayR log          - 查看日志"
    echo "XrayR update       - 更新 XrayR"
    echo "XrayR update x.x.x - 更新指定版本"
    echo "XrayR config       - 修改配置"
    echo "XrayR uninstall    - 卸载 XrayR"
    echo "------------------------------------------"
}

detect_release
detect_arch
install_base
install_XrayR "$1"
