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

verify_checksum() {
    local file="$1"
    local dgst="$2"
    local expected=""
    local actual=""

    expected=$(awk -F'= ' '/^(SHA256|SHA2-256)=/{print $2}' "${dgst}" 2>/dev/null | tr -d ' \r' | head -n 1)
    if [[ -z "${expected}" ]]; then
        echo -e "${red}校验文件中没有可用的 SHA-256 值。${plain}"
        return 1
    fi

    if command_exists sha256sum; then
        actual=$(sha256sum "${file}" | awk '{print $1}')
    elif command_exists shasum; then
        actual=$(shasum -a 256 "${file}" | awk '{print $1}')
    else
        echo -e "${yellow}缺少 sha256sum/shasum，跳过校验。${plain}"
        return 0
    fi

    if [[ "${actual}" == "${expected}" ]]; then
        echo -e "SHA256 校验: ${green}正常${plain}"
        return 0
    fi

    echo -e "SHA256 校验: ${red}异常${plain}"
    echo -e "期望: ${expected}"
    echo -e "实际: ${actual}"
    return 1
}

try_download_binary() {
    local repo="$1"
    local version="$2"
    local out="$3"
    local url=""
    local dgst="${out}.dgst"

    if [[ -z "${version}" ]]; then
        url="https://github.com/${repo}/releases/latest/download/XrayR-linux-${arch}.zip"
    else
        url="https://github.com/${repo}/releases/download/${version}/XrayR-linux-${arch}.zip"
    fi

    echo -e "下载源: ${repo}"
    if download "${url}" "${out}"; then
        rm -f "${dgst}"
        if download "${url}.dgst" "${dgst}"; then
            verify_checksum "${out}" "${dgst}" || return 1
        else
            echo -e "${yellow}未获取到校验文件，跳过 SHA256 校验。${plain}"
        fi
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

cleanup_stage() {
    local stage_dir="$1"
    case "${stage_dir}" in
        /usr/local/XrayR/.install.*)
            rm -rf -- "${stage_dir}"
            ;;
    esac
}

stage_release() {
    local archive="$1"
    local stage_dir="$2"

    if ! unzip -tq "${archive}" >/dev/null; then
        echo -e "${red}下载的 XrayR 压缩包已损坏。${plain}"
        return 1
    fi
    if ! unzip -q "${archive}" -d "${stage_dir}"; then
        echo -e "${red}无法解压 XrayR 发行包。${plain}"
        return 1
    fi
    if [[ ! -f "${stage_dir}/XrayR" ]]; then
        echo -e "${red}发行包中缺少 XrayR 主程序。${plain}"
        return 1
    fi

    chmod +x "${stage_dir}/XrayR"
    if ! "${stage_dir}/XrayR" version >/dev/null 2>&1; then
        echo -e "${red}XrayR 主程序无法在当前系统运行。${plain}"
        return 1
    fi
}

install_XrayR() {
    local version
    local had_config=0
    local archive="/usr/local/XrayR/XrayR-linux.zip"
    local stage_dir=""
    local target_binary="/usr/local/XrayR/XrayR"
    local backup_binary="/usr/local/XrayR/XrayR.previous"
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

    stage_dir=$(mktemp -d /usr/local/XrayR/.install.XXXXXX) || {
        echo -e "${red}无法创建临时安装目录。${plain}"
        exit 1
    }
    if ! stage_release "${archive}" "${stage_dir}"; then
        cleanup_stage "${stage_dir}"
        exit 1
    fi

    # Download all network-controlled files before stopping a running service.
    install_manager

    rm -f "${backup_binary}"
    if [[ -f "${target_binary}" ]]; then
        cp -p "${target_binary}" "${backup_binary}" || {
            cleanup_stage "${stage_dir}"
            echo -e "${red}无法备份当前 XrayR 主程序。${plain}"
            exit 1
        }
    fi

    systemctl stop XrayR >/dev/null 2>&1 || true
    for release_file in README.md LICENSE config.yml dns.json route.json custom_outbound.json custom_inbound.json rulelist geoip.dat geosite.dat; do
        if [[ -f "${stage_dir}/${release_file}" ]]; then
            cp -f "${stage_dir}/${release_file}" "/usr/local/XrayR/${release_file}"
        fi
    done
    if ! install -m 0755 "${stage_dir}/XrayR" "${target_binary}.new" || ! mv -f "${target_binary}.new" "${target_binary}"; then
        cleanup_stage "${stage_dir}"
        rm -f "${target_binary}.new"
        echo -e "${red}无法安装 XrayR 主程序。${plain}"
        exit 1
    fi
    cleanup_stage "${stage_dir}"
    rm -f "${archive}" "${archive}.dgst"

    copy_config_if_missing
    install_service

    if [[ "${had_config}" == "1" ]]; then
        systemctl restart XrayR >/dev/null 2>&1 || true
        sleep 2
        if ! check_status; then
            echo -e "${red}新版 XrayR 启动失败。${plain}"
            if [[ -f "${backup_binary}" ]]; then
                echo -e "${yellow}正在回滚到上一个可用版本。${plain}"
                mv -f "${backup_binary}" "${target_binary}"
                systemctl restart XrayR >/dev/null 2>&1 || true
            fi
            cd "${cur_dir}" || true
            echo -e "${red}更新已回滚，请执行 XrayR log 查看新版启动失败原因。${plain}"
            exit 1
        fi
        rm -f "${backup_binary}"
    else
        echo -e "${yellow}首次安装已写入示例配置，请先编辑 /etc/XrayR/config.yml，然后执行 XrayR start。${plain}"
        rm -f "${backup_binary}"
    fi

    echo -e "${green}XrayR 安装完成。${plain}"
    echo -e "实际下载源: ${green}${selected_repo}${plain}"
    if [[ "${had_config}" == "0" ]]; then
        echo -e "运行状态: ${yellow}等待完成首次配置${plain}"
    else
        echo -e "运行状态: ${green}正常${plain}"
    fi

    cd "${cur_dir}" || exit 0
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

main() {
    [[ $EUID -ne 0 ]] && echo -e "${red}错误:${plain} 必须使用 root 用户运行此脚本！" && exit 1
    detect_release
    detect_arch
    install_base
    install_XrayR "$1"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
