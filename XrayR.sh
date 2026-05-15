#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

script_version="v0.9.6-p1"
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
 ${green}11.${plain} 查看版本
 ${green}12.${plain} 升级管理脚本
 ${green}13.${plain} 退出
"
    show_status
    echo ""
    read -r -p "请输入选择 [0-13]: " num

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
        11) check_installed menu && show_version; pause_menu ;;
        12) update_shell; pause_menu ;;
        13) exit 0 ;;
        *) echo -e "${red}请输入正确的数字 [0-13]。${plain}"; sleep 1; show_menu ;;
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
    help|-h|--help) show_usage ;;
    "") show_menu ;;
    *) show_usage ;;
esac
