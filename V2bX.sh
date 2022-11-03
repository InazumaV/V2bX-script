#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启V2bX" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontents.com/Yuzuki616/V2bX-script/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "输入指定版本(默认最新版): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontents.com/Yuzuki616/V2bX-script/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}更新完成，已自动重启 V2bX，请使用 V2bX log 查看运行日志${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "V2bX在修改配置后会自动尝试重启"
    vi /etc/V2bX/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "V2bX状态: ${green}已运行${plain}"
            ;;
        1)
            echo -e "检测到您未启动V2bX或V2bX自动重启失败，是否查看日志？[Y/n]" && echo
            read -e -rp "(默认: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "V2bX状态: ${red}未安装${plain}"
    esac
}

uninstall() {
    confirm "确定要卸载 V2bX 吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop V2bX
    systemctl disable V2bX
    rm /etc/systemd/system/V2bX.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/V2bX/ -rf
    rm /usr/local/V2bX/ -rf

    echo ""
    echo -e "卸载成功，如果你想删除此脚本，则退出脚本后运行 ${green}rm /usr/bin/V2bX -f${plain} 进行删除"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}V2bX已运行，无需再次启动，如需重启请选择重启${plain}"
    else
        systemctl start V2bX
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}V2bX 启动成功，请使用 V2bX log 查看运行日志${plain}"
        else
            echo -e "${red}V2bX可能启动失败，请稍后使用 V2bX log 查看日志信息${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop V2bX
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}V2bX 停止成功${plain}"
    else
        echo -e "${red}V2bX停止失败，可能是因为停止时间超过了两秒，请稍后查看日志信息${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart V2bX
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}V2bX 重启成功，请使用 V2bX log 查看运行日志${plain}"
    else
        echo -e "${red}V2bX可能启动失败，请稍后使用 V2bX log 查看日志信息${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status V2bX --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable V2bX
    if [[ $? == 0 ]]; then
        echo -e "${green}V2bX 设置开机自启成功${plain}"
    else
        echo -e "${red}V2bX 设置开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable V2bX
    if [[ $? == 0 ]]; then
        echo -e "${green}V2bX 取消开机自启成功${plain}"
    else
        echo -e "${red}V2bX 取消开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u V2bX.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontents.com/chiakge/Linux-NetSpeed/master/tcp.sh)
}

update_shell() {
    wget -O /usr/bin/V2bX -N --no-check-certificate https://raw.githubusercontents.com/Yuzuki616/V2bX-script/master/V2bX.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}下载脚本失败，请检查本机能否连接 Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/V2bX
        echo -e "${green}升级脚本成功，请重新运行脚本${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/V2bX.service ]]; then
        return 2
    fi
    temp=$(systemctl status V2bX | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled V2bX)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}V2bX已安装，请不要重复安装${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}请先安装V2bX${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "V2bX状态: ${green}已运行${plain}"
            show_enable_status
            ;;
        1)
            echo -e "V2bX状态: ${yellow}未运行${plain}"
            show_enable_status
            ;;
        2)
            echo -e "V2bX状态: ${red}未安装${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自启: ${green}是${plain}"
    else
        echo -e "是否开机自启: ${red}否${plain}"
    fi
}

show_V2bX_version() {
    echo -n "V2bX 版本："
    /usr/local/V2bX/V2bX -version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

generate_config_file() {
    echo -e "${yellow}V2bX 配置文件生成向导${plain}"
    echo -e "${red}请阅读以下注意事项：${plain}"
    echo -e "${red}1. 目前该功能正处测试阶段${plain}"
    echo -e "${red}2. 生成的配置文件会保存到 /etc/V2bX/config.yml${plain}"
    echo -e "${red}3. 原来的配置文件会保存到 /etc/V2bX/config.yml.bak${plain}"
    echo -e "${red}4. 目前不支持TLS${plain}"
    read -rp "是否继续生成配置文件？(y/n)" generate_config_file_continue
    if [[ $generate_config_file_continue =~ "y"|"Y" ]]; then
        read -rp "请输入机场网址：" ApiHost
        read -rp "请输入面板对接API Key：" ApiKey
        read -rp "请输入节点Node ID:" NodeID
        echo -e "${yellow}请选择节点传输协议，如未列出则不支持：${plain}"
        echo -e "${green}1. Shadowsocks ${plain}"
        echo -e "${green}2. V2ray ${plain}"
        echo -e "${green}3. Trojan ${plain}"
        read -rp "请输入机场传输协议 [1-4，默认1]：" NodeType
        case "$NodeType" in
            1 ) NodeType="Shadowsocks" ;;
            2 ) NodeType="V2ray" ;;
            3 ) NodeType="Trojan" ;;
            * ) NodeType="Shadowsocks" ;;
        esac
        cd /etc/V2bX
        mv config.yml config.yml.bak
        cat <<EOF > /etc/V2bX/config.yml
Log:
  Level: warning # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/V2bX/access.Log
  ErrorPath: # /etc/V2bX/error.log
DnsConfigPath: # /etc/V2bX/dns.json # Path to dns config, check https://xtls.github.io/config/base/dns/ for help
InboundConfigPath: # /etc/V2bX/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
RouteConfigPath: # /etc/V2bX/route.json # Path to route config, check https://xtls.github.io/config/base/route/ for help
OutboundConfigPath: # /etc/V2bX/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/base/outbound/ for help
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 30 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB 
Nodes:
  -
    ApiConfig:
      ApiHost: "$ApiHost"
      ApiKey: "$ApiKey"
      NodeID: $NodeID
      NodeType: $NodeType # Node type: V2ray, Shadowsocks, Trojan, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/V2bX/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: dns # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "node1.test.com" # Domain to cert
        CertFile: /etc/V2bX/cert/node1.test.com.cert # Provided if the CertMode is file
        KeyFile: /etc/V2bX/cert/node1.test.com.key
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
EOF
        echo -e "${green}V2bX 配置文件生成完成，正在重新启动 V2bX 服务${plain}"
        restart 0
        before_show_menu
    else
        echo -e "${red}已取消 V2bX 配置文件生成${plain}"
        before_show_menu
    fi
}

# 放开防火墙端口
open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}放开防火墙端口成功！${plain}"
}

show_usage() {
    echo "V2bX 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "V2bX              - 显示管理菜单 (功能更多)"
    echo "V2bX start        - 启动 V2bX"
    echo "V2bX stop         - 停止 V2bX"
    echo "V2bX restart      - 重启 V2bX"
    echo "V2bX status       - 查看 V2bX 状态"
    echo "V2bX enable       - 设置 V2bX 开机自启"
    echo "V2bX disable      - 取消 V2bX 开机自启"
    echo "V2bX log          - 查看 V2bX 日志"
    echo "V2bX generate     - 生成 V2bX 配置文件"
    echo "V2bX update       - 更新 V2bX"
    echo "V2bX update x.x.x - 安装 V2bX 指定版本"
    echo "V2bX install      - 安装 V2bX"
    echo "V2bX uninstall    - 卸载 V2bX"
    echo "V2bX version      - 查看 V2bX 版本"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}V2bX 后端管理脚本，${plain}${red}不适用于docker${plain}
--- https://github.com/Yuzuki616/V2bX ---
  ${green}0.${plain} 修改配置
————————————————
  ${green}1.${plain} 安装 V2bX
  ${green}2.${plain} 更新 V2bX
  ${green}3.${plain} 卸载 V2bX
————————————————
  ${green}4.${plain} 启动 V2bX
  ${green}5.${plain} 停止 V2bX
  ${green}6.${plain} 重启 V2bX
  ${green}7.${plain} 查看 V2bX 状态
  ${green}8.${plain} 查看 V2bX 日志
————————————————
  ${green}9.${plain} 设置 V2bX 开机自启
 ${green}10.${plain} 取消 V2bX 开机自启
————————————————
 ${green}11.${plain} 一键安装 bbr (最新内核)
 ${green}12.${plain} 查看 V2bX 版本 
 ${green}13.${plain} 升级 V2bX 维护脚本
 ${green}14.${plain} 生成 V2bX 配置文件
 ${green}15.${plain} 放行 VPS 的所有网络端口
 "
 #后续更新可加入上方字符串中
    show_status
    echo && read -rp "请输入选择 [0-14]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_V2bX_version ;;
        13) update_shell ;;
        14) generate_config_file ;;
        15) open_ports ;;
        *) echo -e "${red}请输入正确的数字 [0-14]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "version") check_install 0 && show_V2bX_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi
