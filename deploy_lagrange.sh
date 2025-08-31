#!/usr/bin/env bash
# 如果当前不是 bash 且系统里也没有 bash，就继续用当前壳；只会启用 -eu，不再动 pipefail
if [ -z "${BASH_VERSION:-}" ]; then
  if command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  fi
fi

# POSIX 安全严格模式
set -eu

# 仅在 bash/zsh 下尝试开启 pipefail；在其它壳上完全跳过
if [ -n "${BASH_VERSION:-}" ] || [ -n "${ZSH_VERSION:-}" ]; then
  set -o pipefail 2>/dev/null || true
fi

# ========== 颜色 ==========
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE_ON_RED='\033[41;37m'
NC='\033[0m' # 无色

# ========== 可维护的下载链接（放最顶上便于维护） ==========
# Lagrange 包基址
LAGRANGE_BASE_URL="https://misc.cn.xuetao.host/pd/AirisuTek/Sealdice%E7%9B%B8%E5%85%B3/Lagrange%E4%B8%80%E9%94%AE%E5%8C%85/Lagrange%E4%B8%8B%E8%BD%BD"
# .NET SDK 版本与基址（官方直链，系统级安装）
DOTNET_VERSION="9.0.304"
DOTNET_BASE_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk"
DOTNET_INSTALL_DIR="/usr/local/dotnet"      # 系统级安装路径
DOTNET_BIN_LINK="/usr/local/bin/dotnet"     # 系统级可执行链接

# ========== 入参 / 环境 ==========
SUBCMD="${1:-deploy}"
work_dir="${2:-${SEALDICE_WORK_DIR:-}}"
if [[ -z "${work_dir:-}" ]]; then
  echo -e "${RED}工作目录未指定。请以：${NC} ${YELLOW}bash deploy_lagrange.sh deploy \"\$SEALDICE_WORK_DIR\"${NC}"
  echo -e "${YELLOW}或先确保环境变量 SEALDICE_WORK_DIR 已正确设置。${NC}"
  exit 1
fi

# 路径布局
data_file="$work_dir/sealdice-sh/lagrange.csv"
download_dir="$work_dir/sealdice-sh/downloads/lagrange"
instances_dir="$work_dir/lagrange/Instances"
mkdir -p "$download_dir" "$instances_dir" "$work_dir/sealdice-sh"
touch "$data_file"

# ========== 基础工具 ==========
ensure_tools() {
  local need_update=0
  for bin in unzip lsof curl tar; do
    command -v "$bin" >/dev/null 2>&1 || need_update=1
  done
  if [[ $need_update -eq 1 ]]; then
    echo -e "${YELLOW}正在安装基础工具（unzip lsof curl tar）...${NC}"
    sudo apt-get update -y || true
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip lsof curl tar
  fi
}

# ========== 签名可达性测试 ==========

# 对单个签名 URL 连续发起 10 次请求；全部成功才算可达。
# 成功标准：HTTP 200、SSL 校验证书通过(ssl_verify_result=0 或为空/HTTP)、响应体非空。
probe_sign_url() {
  local name="$1" url="$2"
  local ok=1
  local times_ms=() sum=0 min=99999999 max=0

  for i in {1..10}; do
    local body metrics http time ssl ms
    body="$(mktemp)"
    # 为了兼容 Cloudflare/反代：加浏览器 UA，禁止缓存，随重定向，超时 15s
    metrics="$(curl -sS -L -m 15 \
      -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36' \
      -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' \
      -o "$body" \
      -w 'HTTP_CODE:%{http_code} TIME:%{time_total} SSL:%{ssl_verify_result}' \
      "$url/ping" 2>/dev/null || true)"

    http="$(printf '%s' "$metrics" | sed -n 's/.*HTTP_CODE:\([0-9][0-9][0-9]\).*/\1/p')"
    time="$(printf '%s' "$metrics" | sed -n 's/.*TIME:\([0-9.]*\).*/\1/p')"
    ssl="$(printf '%s' "$metrics" | sed -n 's/.*SSL:\([0-9]*\).*/\1/p')"

    # 转毫秒（四舍五入）
    ms="$(awk -v t="$time" 'BEGIN{printf("%.0f", t*1000)}')"
    [[ -z "$ms" ]] && ms=0
    times_ms+=("$ms")
    (( sum += ms ))
    (( ms > max )) && max="$ms"
    (( ms < min )) && min="$ms"

    # 判定：HTTP=200、SSL 正常（0 或空；空通常是 http 明文）、响应体非空
    if [[ "$http" != "200" || ! -s "$body" ]]; then
      ok=0
    else
      if [[ -n "$ssl" && "$ssl" != "0" ]]; then
        ok=0
      fi
    fi
    rm -f "$body"
  done

  echo -e "${BLUE}[$name]${NC}"
  if (( ok == 1 )); then
    local avg=$(( sum / 10 ))
    local detail=""
    for t in "${times_ms[@]}"; do
      if [[ -z "$detail" ]]; then detail="${t}ms"; else detail="${detail} / ${t}ms"; fi
    done
    echo -e "  ${GREEN}可达${NC}"
    echo -e "  最高：${YELLOW}${max}ms${NC}"
    echo -e "  最低：${YELLOW}${min}ms${NC}"
    echo -e "  平均：${YELLOW}${avg}ms${NC}"
    echo -e "  明细：${detail}"
  else
    echo -e "  ${RED}此签名可能访问性不佳，出现丢包/HTTP错误或证书问题${NC}"
  fi
  echo
}

# 对一组签名执行测试（静默跑完再统一输出）
run_signature_probes() {
  # 名称与 URL 列表（与选择菜单保持一致顺序）
  local names=(
    "Lagrange 官方"
    "雪桃 の lgr源 反代 - 主线"
    "雪桃 の lgr源 反代 - 备用"
    "山本健一 - aaa1"
    "Hanbi Live - 阿里云CDN反代（Lagrange 官方源）"
    "雪桃 の 海豹源 反代 - 备用的备用"
  )
  local urls=(
    "https://sign.lagrangecore.org/api/sign/30366"
    "https://backbone.seal-sign.xuetao.host/api/sign/30366"
    "https://turbo.seal-sign.xuetao.host/api/sign/30366"
    "https://lagrmagic.cblkseal.tech/api/sign/30366"
    "https://sign.hanbi.live/api/sign/30366"
    "http://39.108.115.52:58080/api/sign/30366"
  )

  echo -e "${YELLOW}正在进行签名可访问性测试（每个 10 次），请稍候...${NC}"
  # 先静默执行全部测试，把输出暂存到变量中，结束后一次性打印
  local all_output=""
  for i in "${!urls[@]}"; do
    local tmp
    tmp="$(probe_sign_url "${names[$i]}" "${urls[$i]}")"
    all_output+="$tmp"$'\n'
  done
  echo -e "\n${CYAN}───────── 测试结果 ─────────${NC}"
  echo -e "$all_output"
}

# ========== UI 辅助 ==========
print_signature_menu() {
  echo -e "${CYAN}请选择签名方案：${NC}"
  echo -e "${YELLOW}注意：${NC}延迟低≠访问性好，请以实测稳定性为准。"
  echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
  echo -e " ${GREEN}1)${NC} ${BLUE}Lagrange 官方${NC}"
  echo -e "    · 这是 Lagrange 官方签名，位于美西，由 Cloudflare 代理，在中国大陆访问性较差；${YELLOW}推荐海外主机使用。${NC}"
  echo -e ""
  echo -e " ${GREEN}2)${NC} ${BLUE}雪桃 の lgr源 反代 - 主线${NC}"
  echo -e "    · 由雪桃提供，反代 Lagrange 官方签名的源。适合中国大陆主机，是雪桃特挑的体质较好的普线主机，${YELLOW}推荐中国大陆使用。${NC}"
  echo -e ""
  echo -e " ${GREEN}3)${NC} ${BLUE}雪桃 の lgr源 反代 - 备用${NC}"
  echo -e "    · 由雪桃提供，反代 Lagrange 官方签名的源。备用线路，大陆优化线路，中国大陆访问性好，但建议主线可用时${YELLOW}优先使用主线。${NC}"
  echo -e ""
  echo -e " ${GREEN}4)${NC} ${BLUE}山本健一 - aaa1${NC}"
  echo -e "    · 由山本健一提供，反代的海豹源签名。${YELLOW}主机在就在中国大陆，有备案，对高墙地带很友好。${NC}"
  echo -e ""
  echo -e " ${GREEN}5)${NC} ${BLUE}Hanbi Live - 阿里云CDN反代（Lagrange 官方源）${NC}"
  echo -e "    · 由 Hanbi Live 提供，使用阿里云 CDN 反代 Lagrange 官方签名源。"
  echo -e ""
  echo -e " ${GREEN}6)${NC} ${BLUE}雪桃 の 海豹源 反代 - 备用的备用${NC}"
  echo -e "    · 雪桃反代的海豹源签名，主机是国内阿里云。因为没有备案只能裸IP，${YELLOW}可能会有被攻击导致访问异常的风险。${NC}；但对于网络高墙地带（如福建、江苏部分地区、内蒙古部分地区、新疆部分地区），是极大概率可以直接访问的。"
  echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
}

# ========== 架构判定 ==========
detect_lagrange_pkg() {
  case "$(uname -m)" in
    x86_64|amd64) echo "Linux_x64_Lagrange.zip" ;;
    aarch64)      echo "Linux_arm64_Lagrange.zip" ;;
    armv7l|armv6l|armhf|arm) echo "Linux_arm_Lagrange.zip" ;;
    *) echo "UNKNOWN" ;;
  esac
}
detect_dotnet_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x64" ;;
    aarch64)      echo "arm64" ;;
    armv7l|armv6l|armhf|arm) echo "arm" ;;
    *) echo "unknown" ;;
  esac
}
dotnet_tar_url() {
  local arch="$1"
  echo "${DOTNET_BASE_URL}/${DOTNET_VERSION}/dotnet-sdk-${DOTNET_VERSION}-linux-${arch}.tar.gz"
}

# ========== 系统级 .NET 9 SDK ==========
has_system_dotnet9() {
  if [[ -x "$DOTNET_INSTALL_DIR/dotnet" ]]; then
    if "$DOTNET_INSTALL_DIR/dotnet" --list-runtimes 2>/dev/null | grep -qE '^Microsoft\.NETCore\.App 9\.0\.'; then
      return 0
    fi
  fi
  return 1
}
install_system_dotnet9() {
  ensure_tools
  local arch="$(detect_dotnet_arch)"
  if [[ "$arch" == "unknown" ]]; then
    echo -e "${WHITE_ON_RED}未识别的架构：$(uname -m)${NC}"
    exit 1
  fi
  local url tarball
  url="$(dotnet_tar_url "$arch")"
  tarball="/tmp/dotnet-sdk-${DOTNET_VERSION}-linux-${arch}.tar.gz"

  echo -e "${YELLOW}准备系统级安装 .NET SDK ${DOTNET_VERSION}（arch=${arch}）...${NC}"
  echo -e "${GREEN}将下载：${NC} $url"
  curl -L --fail -o "$tarball" "$url" --progress-bar

  sudo mkdir -p "$DOTNET_INSTALL_DIR"
  sudo tar -xzf "$tarball" -C "$DOTNET_INSTALL_DIR"
  rm -f "$tarball"

  # 设系统 PATH & DOTNET_ROOT（供登录 shell 使用）
  sudo tee /etc/profile.d/dotnet.sh >/dev/null <<EOF
export DOTNET_ROOT="$DOTNET_INSTALL_DIR"
export PATH="\$PATH:$DOTNET_INSTALL_DIR"
EOF

  # 建系统级可执行链接（供非交互环境 / systemd 使用）
  sudo ln -sf "$DOTNET_INSTALL_DIR/dotnet" "$DOTNET_BIN_LINK"

  # 当前会话立即可用自检
  export DOTNET_ROOT="$DOTNET_INSTALL_DIR"
  if ! "$DOTNET_INSTALL_DIR/dotnet" --list-runtimes 2>/dev/null | grep -qE '^Microsoft\.NETCore\.App 9\.0\.'; then
    echo -e "${WHITE_ON_RED}安装 .NET 9 失败，请检查网络或磁盘空间。${NC}"
    exit 1
  fi
  echo -e "${GREEN}系统级 .NET 9 已就绪（DOTNET_ROOT=$DOTNET_INSTALL_DIR）。${NC}"
}
ensure_system_dotnet9() {
  if has_system_dotnet9; then
    echo -e "${GREEN}检测到系统级 .NET 9。${NC}"
  else
    install_system_dotnet9
  fi
}

ensure_icu() {
  if ldconfig -p 2>/dev/null | grep -q 'libicuuc\.so'; then
    echo -e "${GREEN}ICU 运行库已存在。${NC}"
    return 0
  fi

  echo -e "${YELLOW}正在安装 ICU 运行库...${NC}"
  sudo apt-get update -y || true
  # 自动找最新的 libicuXX 包
  local pkg
  pkg="$(apt-cache search -n '^libicu[0-9]+$' | awk '{print $1}' | sort -V | tail -n1)"
  if [[ -n "$pkg" ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  else
    # 极端情况下找不到版本包，就兜底装 libicu-dev
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y libicu-dev
  fi
}

# ========== 表格输出 ==========
list_instances() {
  local col1=20 col2=28 col3=8 col4=10
  echo -e "${CYAN}+$(printf '%-*s' $col1 '' | tr ' ' '-')+$(printf '%-*s' $col2 '' | tr ' ' '-')+$(printf '%-*s' $col3 '' | tr ' ' '-')+$(printf '%-*s' $col4 '' | tr ' ' '-')+${NC}"
  echo -e "${CYAN}|$(printf '%-*s' $col1 ' 注册名')|$(printf '%-*s' $col2 ' 显示名')|$(printf '%-*s' $col3 ' 端口')|$(printf '%-*s' $col4 ' 状态')|${NC}"
  echo -e "${CYAN}+$(printf '%-*s' $col1 '' | tr ' ' '-')+$(printf '%-*s' $col2 '' | tr ' ' '-')+$(printf '%-*s' $col3 '' | tr ' ' '-')+$(printf '%-*s' $col4 '' | tr ' ' '-')+${NC}"
  while IFS=',' read -r reg_name display_name port; do
    [[ -z "${reg_name:-}" ]] && continue
    local svc="sdsh_lagrange_${reg_name}"
    local status="$(systemctl is-active "$svc" 2>/dev/null || true)"
    [[ "$status" == "active" ]] && status="${GREEN}运行中${NC}" || status="${RED}未运行${NC}"
    echo -e "|$(printf '%-*s' $col1 "${CYAN}${reg_name}${NC}")|$(printf '%-*s' $col2 "${BLUE}${display_name}${NC}")|$(printf '%-*s' $col3 "${YELLOW}${port}${NC}")|$(printf '%-*s' $col4 "$status")|"
  done < "$data_file"
  echo -e "${CYAN}+$(printf '%-*s' $col1 '' | tr ' ' '-')+$(printf '%-*s' $col2 '' | tr ' ' '-')+$(printf '%-*s' $col3 '' | tr ' ' '-')+$(printf '%-*s' $col4 '' | tr ' ' '-')+${NC}"
}

# ========== 主逻辑 ==========
if [[ "$SUBCMD" != "deploy" ]]; then
  echo -e "${RED}未指定有效的操作参数（仅支持：deploy）。${NC}"
  exit 1
fi

# 1) 列出现有实例
if [[ -s "$data_file" ]]; then
  echo -e "${CYAN}当前已注册的 Lagrange 实例：${NC}"
  list_instances
else
  echo -e "${YELLOW}当前没有任何已注册的 Lagrange 实例。${NC}"
fi

# 2) 签名简述 + 是否继续
echo -e ""
echo -e "\nSealdice 的内置客户端本质上是自动配置 Lagrange，而 Lagrange 运行需要签名服务。"
echo -e ""
echo -e "不同签名服务的访问速度、稳定性因网络环境而异。${YELLOW}请选择可访问、丢包少的签名。"
echo -e ""
echo -e "注意：延迟低≠访问性好${NC}，请结合实际连接稳定性选择。"
echo -e ""
echo -e ""
echo -e "${YELLOW}是否继续部署？（y/n）${NC}"
read -r know_sig
if [[ ! "$know_sig" =~ ^[yY]$ ]]; then
  echo -e "${RED}已退出。${NC}"
  exit 0
fi

# 3) 选择签名
# 先询问是否进行可访问性测试
read -p "$(echo -e ${YELLOW}是否要执行签名可访问性测试？（y/n）：${NC})" do_probe
if [[ "$do_probe" =~ ^[yY]$ ]]; then
  run_signature_probes
fi

# 打印菜单并读取选择
print_signature_menu
read -p "$(echo -e ${YELLOW}输入编号（1/2/3/4/5/6）：${NC} )" sign_choice

# 与菜单一一对应的 URL 常量
lgr_official="https://sign.lagrangecore.org/api/sign/30366"
lorana_proxy_backbone="https://backbone.seal-sign.xuetao.host/api/sign/30366"
lorana_proxy_turbo="https://turbo.seal-sign.xuetao.host/api/sign/30366"
cblkseal="https://lagrmagic.cblkseal.tech/api/sign/30366"
lorana_proxy_backup="http://39.108.115.52:58080/api/sign/30366"
hanbi_live="https://sign.hanbi.live/api/sign/30366"

case "${sign_choice:-}" in
  1) sign_server_url="$lgr_official" ;;
  2) sign_server_url="$lorana_proxy_backbone" ;;
  3) sign_server_url="$lorana_proxy_turbo" ;;
  4) sign_server_url="$cblkseal" ;;
  5) sign_server_url="$hanbi_live" ;;
  6) sign_server_url="$lorana_proxy_backup" ;;
  *) echo -e "${YELLOW}未选择有效编号，默认使用：${BLUE}Lagrange 官方${NC}"; sign_server_url="$lgr_official" ;;
esac

# 4) 采集实例名称/别名
while true; do
  echo -e "${YELLOW}请输入注册名 (小写字母/数字/下划线，<=25)：${NC}"
  read -r reg_name
  [[ "$reg_name" =~ ^[a-z0-9_]+$ ]] && [[ ${#reg_name} -le 25 ]] || { echo -e "${RED}格式不合法。${NC}"; continue; }
  grep -q "^$reg_name," "$data_file" && { echo -e "${RED}注册名已存在！请换一个。${NC}"; continue; }
  break
done
while true; do
  echo -e "${YELLOW}请输入别名/显示名：${NC}"
  read -r display_name
  [[ -n "${display_name:-}" ]] && break || echo -e "${RED}别名不能为空。${NC}"
done

# 5) 端口（仅本机监听，默认 18080）
while true; do
  read -p "$(echo -e ${YELLOW}请输入对外 WS 端口（默认 18080，仅本机）：${NC})" port
  port="${port:-18080}"
  lsof -i:"$port" &>/dev/null && { echo -e "${RED}端口 $port 已被占用，请换一个。${NC}"; continue; }
  break
done

# 6) 系统级 .NET 9 SDK
ensure_system_dotnet9
ensure_icu

# 7) 准备目录
inst_dir="$instances_dir/$reg_name"
mkdir -p "$inst_dir"

# 8) 下载并解压 Lagrange
pkg="$(detect_lagrange_pkg)"
[[ "$pkg" == "UNKNOWN" ]] && { echo -e "${WHITE_ON_RED}未识别的架构：$(uname -m)。${NC}"; exit 1; }
url="$LAGRANGE_BASE_URL/$pkg"
zip_path="$download_dir/$pkg"
echo -e "${GREEN}将下载：${NC} $url"
curl -L --fail -o "$zip_path" "$url" --progress-bar

echo -e "${YELLOW}解压到：${NC} $inst_dir"
rm -rf "$inst_dir"/*
unzip -o "$zip_path" -d "$inst_dir" | sed -u 's/^/【解压】 /'
rm -f "$zip_path"

# 9) 生成 appsettings.json（仅 SignServerUrl 和 Port 变量，其余写死）
app_json="$inst_dir/appsettings.json"
cat > "$app_json" <<JSON
{
  "\$schema": "https://raw.githubusercontent.com/LagrangeDev/Lagrange.Core/master/Lagrange.OneBot/Resources/appsettings_schema.json",
  "Logging": { "LogLevel": { "Default": "Information" } },
  "SignServerUrl": "${sign_server_url}",
  "SignProxyUrl": "",
  "MusicSignServerUrl": "https://ss.xingzhige.com/music_card/card",
  "Account": { "Uin": 0, "Password": "", "Protocol": "Linux", "AutoReconnect": true, "GetOptimumServer": true },
  "Message": { "IgnoreSelf": true, "StringPost": false },
  "QrCode": { "ConsoleCompatibilityMode": false },
  "Implementations": [
    { "Type": "ForwardWebSocket", "Host": "127.0.0.1", "Port": ${port}, "HeartBeatInterval": 5000, "HeartBeatEnable": true, "AccessToken": "" }
  ]
}
JSON

# 确保可执行权限
chmod -R 755 "$inst_dir"
if ls "$inst_dir"/Lagrange* >/dev/null 2>&1; then
  chmod +x "$inst_dir"/Lagrange*
fi

# 10) 输出对接信息与步骤，询问是否已记录
connection_url="ws://127.0.0.1:${port}"

echo -e "${CYAN}============================================${NC}"
echo -e "               ${GREEN}Lagrange 部署成功！${NC}"
echo -e "  注册名：${CYAN}$reg_name${NC}    显示名：${CYAN}$display_name${NC}"
echo -e "  本机 WS 端口：${CYAN}$port${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e ""
echo -e "${YELLOW}重要：请将以下信息记录下来：${NC}"
echo -e "${CYAN}────────────────────────────────────────────${NC}"
echo -e "  连接方式：${GREEN}QQ（OneBot11 正向 WebSocket）${NC}"
echo -e "  连接地址：${BLUE}${connection_url}${NC}"
echo -e "${CYAN}────────────────────────────────────────────${NC}"
echo -e "后续操作指南："
echo -e "  1) 稍后使用【日志命令】进入日志跟随页面，按提示扫码登录。"
echo -e "  2) 登录成功后给账号发消息，观察日志是否能收到。"
echo -e "  3) 若正常，${YELLOW}Ctrl+C${NC} 退出日志，再在 Sealdice 中按以上地址对接。"
echo -e "${CYAN}============================================${NC}"
echo -ne "${YELLOW}你是否确认已记录并保存这些信息？（y/n）${NC} "
read -r saved_ok
if [[ ! "$saved_ok" =~ ^[yY]$ ]]; then
  echo -e "${RED}已取消：未创建系统服务。稍后可再次运行本脚本继续。${NC}"
  exit 0
fi

# 11) 显示高亮日志命令（先显示，后创建服务，避免输出被冲淡）
service_name="sdsh_lagrange_${reg_name}"
service_path="/etc/systemd/system/${service_name}.service"
journal_cmd="journalctl -u ${service_name} -n 500 -f"

echo -e ""
echo -e "${YELLOW}┌─────────────────────── 日志命令 ───────────────────────┐${NC}"
echo -e "  ${BLUE}${journal_cmd}${NC}"
echo -e "${YELLOW}└────────────────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}提示：这是持续监听最新 500 行日志，扫码登录后可观察收发情况；按 Ctrl+C 退出。${NC}"
echo -e ""
echo -e "${YELLOW}如果你的 SSH 无法正确显示二维码：${NC}"
echo -e "  到目录 ${BLUE}${work_dir}/lagrange/Instances/${reg_name}${NC}（例如：${BLUE}${inst_dir}${NC}）"
echo -e "  找到图片 ${CYAN}qr-0.png${NC}，直接使用该图片进行扫码登录。"
echo -e ""
echo -e "${CYAN}提示：这是持续监听最新 500 行日志，扫码登录后可观察收发情况；按 Ctrl+C 退出。${NC}"
echo -e ""

# 12) 生成并注册 systemd 服务（抑制“Created symlink …”等噪声）
exe_name="$(basename "$(ls -1 "$inst_dir"/Lagrange* 2>/dev/null | head -n1 || true)")"
if [[ -z "$exe_name" ]]; then
  echo -e "${WHITE_ON_RED}未在 $inst_dir 找到 Lagrange 可执行文件。${NC}"
  exit 1
fi

sudo tee "$service_path" >/dev/null <<EOL
[Unit]
Description=Lagrange OneBot Service ($reg_name)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$inst_dir
Environment=DOTNET_ROOT=$DOTNET_INSTALL_DIR
ExecStart=$inst_dir/$exe_name
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload >/dev/null 2>&1
sudo systemctl enable "$service_name" >/dev/null 2>&1
sudo systemctl start "$service_name"  >/dev/null 2>&1

# 13) 记录 CSV 并结束（仅在服务已成功启动时记录）
if systemctl is-active --quiet "$service_name"; then
  echo "$reg_name,$display_name,$port" >> "$data_file"
  echo -e "${GREEN}系统服务已启动。${NC}现在就执行上面的 ${YELLOW}${journal_cmd}${NC} 进行扫码登录吧。"
  exit 0
else
  echo -e "${WHITE_ON_RED}服务启动失败：$service_name${NC}"
  echo -e "${YELLOW}状态：${NC} sudo systemctl status $service_name"
  echo -e "${YELLOW}日志：${NC} sudo journalctl -u $service_name -n 200 --no-pager"
  sudo systemctl disable "$service_name" >/dev/null 2>&1 || true
  sudo rm -f "$service_path"
  sudo systemctl daemon-reload >/dev/null 2>&1
  exit 1
fi
