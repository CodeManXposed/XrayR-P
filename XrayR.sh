#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

script_version="v0.9.6-p2"
install_url="https://raw.githubusercontent.com/CodeManXposed/XrayR-P/main/install.sh"
install_backup_url="https://raw.githubusercontent.com/unicorncross/XrayR-onekey-install/main/install.sh"
shell_url="https://raw.githubusercontent.com/CodeManXposed/XrayR-P/main/XrayR.sh"

[[ $EUID -ne 0 ]] && echo -e "${red}错误:${plain} 必须使用 root 用户运行此脚本！" && exit 1

download() {
    local url="$1"
    local out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -L --fail --connect-timeout 15 --retry 2 --retry-delay 2 -o "$out" "$url"
    else
        wget -q --timeout=20 --tries=2 --no-check-certificate -O "$out" "$url"
    fi
}

run_install_script() {
    local version="$1"
    local tmp="/tmp/XrayR-install.sh"

    if ! download "${install_url}" "${tmp}"; then
        echo -e "${yellow}主源安装脚本下载失败，尝试旧源备用脚本。${plain}"
        download "${install_backup_url}" "${tmp}" || {
            echo -e "${red}安装脚本下载失败。${plain}"
            return 1
        }
    fi
    chmod +x "${tmp}"
    bash "${tmp}" "${version}"
}

confirm() {
    local prompt="$1"
    local default="$2"
    local answer=""
    read -r -p "${prompt} [默认${default}]: " answer
    [[ -z "${answer}" ]] && answer="${default}"
    [[ "${answer}" == "y" || "${answer}" == "Y" ]]
}

pause_menu() {
    echo ""
    read -r -p "按回车返回主菜单: " _
    show_menu
}

check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    systemctl is-active --quiet XrayR && return 0
    return 1
}

check_installed() {
    check_status
    if [[ $? == 2 ]]; then
        echo -e "${red}请先安装 XrayR。${plain}"
        [[ "$1" == "menu" ]] && pause_menu
        return 1
    fi
    return 0
}

check_not_installed() {
    check_status
    if [[ $? != 2 ]]; then
        echo -e "${yellow}XrayR 已安装，请勿重复安装。${plain}"
        [[ "$1" == "menu" ]] && pause_menu
        return 1
    fi
    return 0
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "运行状态: ${green}正常${plain}"
            ;;
        1)
            echo -e "运行状态: ${red}异常${plain}"
            ;;
        2)
            echo -e "运行状态: ${yellow}未安装${plain}"
            ;;
    esac

    if [[ -f /etc/systemd/system/XrayR.service ]]; then
        if systemctl is-enabled --quiet XrayR; then
            echo -e "开机自启: ${green}正常${plain}"
        else
            echo -e "开机自启: ${red}异常${plain}"
        fi
    fi
}

install() {
    run_install_script "$1" || return 1
}

update() {
    local version="$1"
    if [[ -z "${version}" ]]; then
        read -r -p "输入指定版本，留空为最新版: " version
    fi
    run_install_script "${version}" || return 1
    echo -e "${green}更新完成。${plain}"
}

uninstall() {
    confirm "确定卸载 XrayR 吗" "n" || {
        echo -e "${yellow}已取消。${plain}"
        return 0
    }

    systemctl stop XrayR >/dev/null 2>&1 || true
    systemctl disable XrayR >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/XrayR.service
    systemctl daemon-reload
    systemctl reset-failed >/dev/null 2>&1 || true
    rm -rf /usr/local/XrayR /etc/XrayR
    echo -e "${green}卸载完成。${plain}"
}

start() {
    systemctl start XrayR
    sleep 1
    show_status
}

stop() {
    systemctl stop XrayR
    sleep 1
    show_status
}

restart() {
    systemctl restart XrayR
    sleep 1
    show_status
}

status() {
    show_status
    systemctl status XrayR --no-pager -l || true
}

enable() {
    systemctl enable XrayR
    show_status
}

disable() {
    systemctl disable XrayR
    show_status
}

show_log() {
    journalctl -u XrayR.service -e --no-pager -f
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh)
}

config() {
    ${EDITOR:-vi} /etc/XrayR/config.yml
    restart
}

show_version() {
    if [[ -x /usr/local/XrayR/XrayR ]]; then
        /usr/local/XrayR/XrayR -version
    else
        echo -e "${yellow}未找到 XrayR 可执行文件。${plain}"
    fi
}

update_shell() {
    if download "${shell_url}" /usr/bin/XrayR; then
        chmod +x /usr/bin/XrayR
        ln -sf /usr/bin/XrayR /usr/bin/xrayr
        echo -e "${green}管理脚本升级完成。${plain}"
    else
        echo -e "${red}管理脚本升级失败。${plain}"
    fi
}

extract_dns_servers() {
    local file="${1:-/etc/XrayR/dns.json}"

    if [[ ! -s "${file}" ]]; then
        echo "1.1.1.1"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$file" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    sys.exit(1)

servers = data.get("servers", [])
for item in servers:
    if isinstance(item, str):
        print(item)
    elif isinstance(item, dict):
        value = item.get("address") or item.get("server")
        if value:
            print(value)
PY
        return $?
    fi

    grep -Eo '"(address|server)"[[:space:]]*:[[:space:]]*"[^"]+"|"[^"]+"' "${file}" \
        | sed -E 's/^"(address|server)"[[:space:]]*:[[:space:]]*"([^"]+)".*/\2/; s/^"([^"]+)".*/\1/' \
        | grep -Ev '^(servers|hosts|queryStrategy|tag|domains|expectIPs)$'
}

normalize_dns_server() {
    local server="$1"
    server="${server%%#*}"
    server="${server//\"/}"
    server="${server#"${server%%[![:space:]]*}"}"
    server="${server%"${server##*[![:space:]]}"}"

    [[ -z "${server}" ]] && return 1
    case "${server}" in
        https://*|http://*)
            echo "doh:${server}"
            ;;
        tcp://*|udp://*)
            server="${server#*://}"
            server="${server%%/*}"
            [[ "${server}" == *:* && "${server}" != *:*:* ]] && server="${server%:*}"
            echo "dns:${server}"
            ;;
        *://*)
            return 1
            ;;
        *)
            server="${server%%/*}"
            [[ "${server}" == *:* && "${server}" != *:*:* ]] && server="${server%:*}"
            echo "dns:${server}"
            ;;
    esac
}

resolve_with_doh() {
    local url="$1"
    local domain="$2"
    local sep="?"
    local response

    [[ "${url}" == *\?* ]] && sep="&"
    response=$(curl -fsSL -m 8 -H "accept: application/dns-json" "${url}${sep}name=${domain}&type=A" 2>/dev/null) || return 1

    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json
import re
import sys

try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(1)

for answer in data.get("Answer", []):
    value = str(answer.get("data", ""))
    if answer.get("type") == 1 and re.match(r"^\d{1,3}(\.\d{1,3}){3}$", value):
        print(value)
        break
' <<<"${response}"
    else
        printf "%s" "${response}" | grep -Eo '"data"[[:space:]]*:[[:space:]]*"([0-9]{1,3}\.){3}[0-9]{1,3}"' \
            | sed -E 's/.*"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/' \
            | head -n 1
    fi
}

resolve_domain() {
    local server="$1"
    local domain="$2"
    local resolver="${server#dns:}"
    local ip=""

    if [[ "${server}" == doh:* ]]; then
        resolve_with_doh "${server#doh:}" "${domain}" | head -n 1
        return 0
    fi

    if command -v dig >/dev/null 2>&1; then
        ip=$(dig @"${resolver}" "${domain}" A +short 2>/dev/null | grep -E '^[0-9.]+$' | head -n 1)
    elif command -v nslookup >/dev/null 2>&1; then
        ip=$(nslookup "${domain}" "${resolver}" 2>/dev/null | awk '/^Address: /{print $2}' | grep -E '^[0-9.]+$' | tail -n 1)
    else
        ip=$(getent ahostsv4 "${domain}" 2>/dev/null | awk '{print $1; exit}')
    fi

    printf "%s\n" "${ip}"
}

probe_http_with_ip() {
    local domain="$1"
    local url="$2"
    local ip="$3"
    local bad_pattern="$4"
    local tmp
    local code

    tmp=$(mktemp /tmp/xrayr-unlock.XXXXXX) || return 1
    code=$(curl -k -L -sS -m 15 \
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36" \
        -o "${tmp}" -w "%{http_code}" \
        --resolve "${domain}:443:${ip}" "${url}" 2>/dev/null || echo "000")

    PROBE_DETAIL="HTTP ${code}"
    if [[ "${code}" =~ ^(20|30)[0-9]$ ]]; then
        if [[ -n "${bad_pattern}" ]] && grep -Eiq "${bad_pattern}" "${tmp}"; then
            PROBE_DETAIL="命中国家/地区限制"
            rm -f "${tmp}"
            return 1
        fi
        rm -f "${tmp}"
        return 0
    fi

    rm -f "${tmp}"
    return 1
}

print_check_line() {
    local category="$1"
    local name="$2"
    local status="$3"
    local dns="$4"
    local ip="$5"
    local detail="$6"
    local color="${red}"

    [[ "${status}" == "正常" ]] && color="${green}"
    printf "%-8s %-10s ${color}%-6s${plain} DNS:%-24s IP:%-16s %s\n" "${category}" "${name}" "${status}" "${dns}" "${ip}" "${detail}"
}

unlock_test() {
    local dns_file="/etc/XrayR/dns.json"
    local raw
    local normalized
    local servers=()
    local target
    local category name domain url bad_pattern
    local server label ip status detail ok

    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${red}异常${plain}: 缺少 curl"
        return 1
    fi

    while IFS= read -r raw; do
        normalized=$(normalize_dns_server "${raw}") || continue
        servers+=("${normalized}")
    done < <(extract_dns_servers "${dns_file}")

    [[ ${#servers[@]} -eq 0 ]] && servers=("dns:1.1.1.1")

    echo "------------------------------------------------------------"
    echo "DNS / 流媒体 / AI 解锁测试"
    echo "说明: 读取 ${dns_file} 的 servers；先用该 DNS 解析，再用 curl --resolve 访问服务。"
    echo "结果: 正常 / 异常"
    echo "------------------------------------------------------------"

    local targets=(
        "流媒体|Netflix|www.netflix.com|https://www.netflix.com/title/81280792|not available in your country|unavailable in your country|blocked"
        "流媒体|Disney+|www.disneyplus.com|https://www.disneyplus.com/|not available in your region|not available in your country|unavailable in your location"
        "流媒体|YouTube|www.youtube.com|https://www.youtube.com/premium|Premium is not available in your country|not available in your country"
        "AI|OpenAI|chat.openai.com|https://chat.openai.com/cdn-cgi/trace|unsupported_country|not available in your country|Sorry, you have been blocked|Access denied"
        "AI|Gemini|gemini.google.com|https://gemini.google.com/|Gemini isn't currently supported|not available in your country|not yet available|unsupported country|无法在你所在|国家/地区"
        "AI|Claude|claude.ai|https://claude.ai/|unavailable in your region|not available in your country|unsupported country|Access denied"
    )

    for target in "${targets[@]}"; do
        IFS='|' read -r category name domain url bad_pattern <<<"${target}"
        status="异常"
        detail="DNS解析失败"
        ip="-"
        label="-"
        ok=1

        for server in "${servers[@]}"; do
            label="${server#dns:}"
            label="${label#doh:}"
            ip=$(resolve_domain "${server}" "${domain}" | head -n 1)
            [[ -z "${ip}" ]] && {
                detail="DNS解析失败"
                continue
            }
            if probe_http_with_ip "${domain}" "${url}" "${ip}" "${bad_pattern}"; then
                status="正常"
                detail="${PROBE_DETAIL}"
                ok=0
                break
            fi
            detail="${PROBE_DETAIL}"
        done

        print_check_line "${category}" "${name}" "${status}" "${label}" "${ip:-"-"}" "${detail}"
        [[ ${ok} -eq 0 ]] || true
    done
}

check_conf_item() {
    local title="$1"
    local pattern="$2"
    local file="$3"
    local detail="$4"

    if grep -Eiq "${pattern}" "${file}" 2>/dev/null; then
        printf "%-18s ${green}正常${plain}\n" "${title}"
    else
        printf "%-18s ${red}异常${plain} %s\n" "${title}" "${detail}"
    fi
}

check_yaml_value_item() {
    local title="$1"
    local key="$2"
    local file="$3"
    local detail="$4"

    if grep -Eiq "^[[:space:]]*${key}:[[:space:]]*[^[:space:]#]+" "${file}" 2>/dev/null; then
        printf "%-18s ${green}正常${plain}\n" "${title}"
    else
        printf "%-18s ${red}异常${plain} %s\n" "${title}" "${detail}"
    fi
}

check_yaml_list_item() {
    local title="$1"
    local key="$2"
    local file="$3"
    local detail="$4"

    if awk -v key="${key}" '
        $0 ~ "^[[:space:]]*" key ":[[:space:]]*$" { in_list=1; next }
        in_list && $0 ~ "^[[:space:]]*[A-Za-z0-9_]+:" { exit }
        in_list && $0 ~ "^[[:space:]]*-[[:space:]]*\"?[A-Za-z0-9.*_-]*\"?[[:space:]]*($|#)" { found=1 }
        END { exit found ? 0 : 1 }
    ' "${file}" 2>/dev/null; then
        printf "%-18s ${green}正常${plain}\n" "${title}"
    else
        printf "%-18s ${red}异常${plain} %s\n" "${title}" "${detail}"
    fi
}

reality_check() {
    local config="/etc/XrayR/config.yml"

    echo "------------------------------------------------------------"
    echo "VLESS / REALITY 本地配置自检"
    echo "说明: 只读取本机配置，不修改任何文件。面板下发的 TCP 传输仍需以面板节点配置为准。"
    echo "------------------------------------------------------------"

    if [[ ! -f "${config}" ]]; then
        echo -e "配置文件          ${red}异常${plain} 未找到 ${config}"
        return 1
    fi

    check_conf_item "VLESS开关" 'EnableVless:[[:space:]]*true|NodeType:[[:space:]]*"?Vless"?' "${config}" "未发现 EnableVless:true 或 NodeType:Vless"
    check_conf_item "Vision算法" 'VlessFlow:[[:space:]]*"?xtls-rprx-vision"?' "${config}" "建议使用 VlessFlow: xtls-rprx-vision"
    check_conf_item "REALITY开关" 'EnableREALITY:[[:space:]]*true' "${config}" "未启用 EnableREALITY:true"
    check_yaml_value_item "REALITY Dest" "Dest" "${config}" "REALITYConfigs.Dest 为空"
    check_yaml_list_item "ServerNames" "ServerNames" "${config}" "ServerNames 为空"
    check_yaml_value_item "PrivateKey" "PrivateKey" "${config}" "PrivateKey 为空"
    check_yaml_list_item "ShortIds" "ShortIds" "${config}" "ShortIds 为空"

    if grep -Eiq 'network[":[:space:]]+tcp|Network:[[:space:]]*tcp' /etc/XrayR/custom_inbound.json "${config}" 2>/dev/null; then
        printf "%-18s ${green}正常${plain}\n" "TCP传输"
    else
        printf "%-18s ${yellow}异常${plain} 本地静态配置未确认 TCP，请确认面板节点传输为 TCP\n" "TCP传输"
    fi
}

show_usage() {
    echo "XrayR 管理脚本使用方法:"
    echo "------------------------------------------"
    echo "XrayR              - 数字交互菜单"
    echo "XrayR start        - 启动 XrayR"
    echo "XrayR stop         - 停止 XrayR"
    echo "XrayR restart      - 重启 XrayR"
    echo "XrayR status       - 查看运行状态"
    echo "XrayR enable       - 设置开机自启"
    echo "XrayR disable      - 取消开机自启"
    echo "XrayR log          - 查看日志"
    echo "XrayR update       - 更新 XrayR"
    echo "XrayR update x.x.x - 更新指定版本"
    echo "XrayR config       - 修改配置"
    echo "XrayR uninstall    - 卸载 XrayR"
    echo "XrayR version      - 查看版本"
    echo "XrayR unlock       - DNS/流媒体/AI 解锁测试"
    echo "XrayR reality      - VLESS/REALITY 本地配置自检"
    echo "------------------------------------------"
}

show_menu() {
    clear
    echo -e "
  ${green}XrayR-P 后端管理脚本${plain}
  https://github.com/CodeManXposed/XrayR-P

  ${green}0.${plain} 修改配置
  ${green}1.${plain} 安装 XrayR
  ${green}2.${plain} 更新 XrayR
  ${green}3.${plain} 卸载 XrayR
  ${green}4.${plain} 启动 XrayR
  ${green}5.${plain} 停止 XrayR
  ${green}6.${plain} 重启 XrayR
  ${green}7.${plain} 查看运行状态
  ${green}8.${plain} 查看日志
 ${green}9.${plain} 设置开机自启
 ${green}10.${plain} 取消开机自启
 ${green}11.${plain} 一键安装 bbr (最新内核)
 ${green}12.${plain} 查看版本
 ${green}13.${plain} 升级管理脚本
 ${green}14.${plain} DNS / 流媒体 / AI 解锁测试
 ${green}15.${plain} VLESS / REALITY 本地配置自检
 ${green}16.${plain} 退出
"
    show_status
    echo ""
    read -r -p "请输入选择 [0-16]: " num

    case "${num}" in
        0) check_installed menu && config; pause_menu ;;
        1) check_not_installed menu && install; pause_menu ;;
        2) check_installed menu && update; pause_menu ;;
        3) check_installed menu && uninstall; pause_menu ;;
        4) check_installed menu && start; pause_menu ;;
        5) check_installed menu && stop; pause_menu ;;
        6) check_installed menu && restart; pause_menu ;;
        7) check_installed menu && status; pause_menu ;;
        8) check_installed menu && show_log ;;
        9) check_installed menu && enable; pause_menu ;;
        10) check_installed menu && disable; pause_menu ;;
        11) install_bbr; pause_menu ;;
        12) check_installed menu && show_version; pause_menu ;;
        13) update_shell; pause_menu ;;
        14) unlock_test; pause_menu ;;
        15) check_installed menu && reality_check; pause_menu ;;
        16) exit 0 ;;
        *) echo -e "${red}请输入正确的数字 [0-16]。${plain}"; sleep 1; show_menu ;;
    esac
}

case "$1" in
    start) check_installed && start ;;
    stop) check_installed && stop ;;
    restart) check_installed && restart ;;
    status) check_installed && status ;;
    enable) check_installed && enable ;;
    disable) check_installed && disable ;;
    log) check_installed && show_log ;;
    update) check_installed && update "$2" ;;
    config) check_installed && config ;;
    install) check_not_installed && install "$2" ;;
    uninstall) check_installed && uninstall ;;
    version) check_installed && show_version ;;
    update_shell) update_shell ;;
    unlock|check|dnscheck) unlock_test ;;
    reality|realitycheck) check_installed && reality_check ;;
    help|-h|--help) show_usage ;;
    "") show_menu ;;
    *) show_usage ;;
esac
