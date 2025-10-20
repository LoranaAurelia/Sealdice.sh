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
WHITE='\033[1;37m'
WHITE_ON_RED='\033[41;37m'
NC='\033[0m'

# ========== 路径与文件 ==========
work_dir="${SEALDICE_WORK_DIR:-}"
if [[ -z "${work_dir}" ]]; then
  echo -e "${WHITE_ON_RED}未检测到 SEALDICE_WORK_DIR 环境变量！${NC}"
  exit 1
fi

lagrange_csv="$work_dir/sealdice-sh/lagrange.csv"
instances_dir="$work_dir/lagrange/Instances"
[[ -f "$lagrange_csv" ]] || { echo -e "${WHITE_ON_RED}未找到 ${lagrange_csv}，请先部署 Lagrange！${NC}"; exit 1; }

# ========== 依赖 ==========
ensure_tools() {
  local need=()
  for b in jq curl sed awk grep systemctl journalctl lsof; do
    command -v "$b" >/dev/null 2>&1 || need+=("$b")
  done
  if [[ ${#need[@]} -gt 0 ]]; then
    echo -e "${YELLOW}正在安装依赖：${NC} ${need[*]}"
    sudo apt-get update -y || true
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jq curl sed gawk grep systemd lsof || true
  fi
}
ensure_tools

# ========== 签名菜单/测试（与部署脚本保持一致） ==========
print_signature_menu() {
  echo -e "${CYAN}请选择签名方案：${NC}"
  echo -e "${YELLOW}注意：${NC}延迟低≠访问性好，请以实测稳定性为准。"
  echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
  echo -e " ${GREEN}1)${NC} ${BLUE}雪桃家自签 - Cloudflare${NC}"
  echo -e "    · 雪桃自签，机房位于雪桃家（澳大利亚-黄金海岸），由 Cloudflare 代理，在中国大陆访问性较差；${YELLOW}推荐海外主机使用。${NC}"
  echo -e ""
  echo -e " ${GREEN}2)${NC} ${BLUE}雪桃自签 - 主线${NC}"
  echo -e "    · 雪桃自签，主机位于美国洛杉矶，是雪桃特挑的体质较好的普线主机，${YELLOW}推荐中国大陆使用。${NC}"
  echo -e ""
  echo -e " ${GREEN}3)${NC} ${BLUE}雪桃自签 - 边缘${NC}"
  echo -e "    · 雪桃自签，主机位于中国香港，BGP线路，中国访问性良好且延迟低，${YELLOW}推荐中国大陆使用。${NC}"
  echo -e ""
  echo -e " ${GREEN}4)${NC} ${BLUE}雪桃自签 - 备用${NC}"
  echo -e "    · 雪桃自签，主机位于美国洛杉矶，备用线路，大陆优化线路，中国大陆访问性好，但建议其余线路可用时${YELLOW}优先使用其余线路。${NC}"
  echo -e ""
  echo -e " ${GREEN}5)${NC} ${BLUE}雪桃 の 海豹源 反代 - 备用的备用${NC}"
  echo -e "    · 雪桃反代的海豹源签名，主机是国内阿里云。因为没有备案只能裸IP，${YELLOW}可能会有被攻击导致访问异常的风险。${NC}；但对于网络高墙地带（如福建、江苏部分地区、内蒙古部分地区、新疆部分地区），是极大概率可以直接访问的。"
  echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
}

# 单个 URL 连续 10 次探测：HTTP 200 + 证书正常(或 http 明文) + 响应体非空 => 可达
probe_sign_url() {
  local name="$1" url="$2"
  local ok=1
  local times_ms=() sum=0 min=99999999 max=0

  for i in {1..10}; do
    local body metrics http time ssl ms
    body="$(mktemp)"
    metrics="$(curl -sS -L -m 15 \
      -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36' \
      -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' \
      -o "$body" \
      -w 'HTTP_CODE:%{http_code} TIME:%{time_total} SSL:%{ssl_verify_result}' \
      "$url/ping" 2>/dev/null || true)"
    http="$(printf '%s' "$metrics" | sed -n 's/.*HTTP_CODE:\([0-9][0-9][0-9]\).*/\1/p')"
    time="$(printf '%s' "$metrics" | sed -n 's/.*TIME:\([0-9.]*\).*/\1/p')"
    ssl="$(printf '%s' "$metrics" | sed -n 's/.*SSL:\([0-9]*\).*/\1/p')"
    ms="$(awk -v t="$time" 'BEGIN{printf("%.0f", t*1000)}')"
    [[ -z "$ms" ]] && ms=0
    times_ms+=("$ms")
    (( sum += ms ))
    (( ms > max )) && max="$ms"
    (( ms < min )) && min="$ms"
    if [[ "$http" != "200" || ! -s "$body" ]]; then
      ok=0
    else
      if [[ -n "$ssl" && "$ssl" != "0" ]]; then ok=0; fi
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

run_signature_probes() {
  local names=(
    "雪桃家自签 - Cloudflare"
    "雪桃自签 - 主线"
    "雪桃自签 - 边缘"
    "雪桃自签 - 备用"
    "雪桃 の 海豹源 反代 - 备用的备用"
  )
  local urls=(
    "https://cf-sign.xuetao.host/40768"
    "https://backbone.seal-sign.xuetao.host/sign/40768"
    "https://edge.seal-sign.xuetao.host/sign/40768"
    "https://turbo.seal-sign.xuetao.host/sign/40768"
    "http://39.108.115.52:58080/api/sign/39038"
  )
  echo -e "${YELLOW}正在进行签名可访问性测试（每个 10 次），请稍候...${NC}"
  local all_output=""
  for i in "${!urls[@]}"; do
    local tmp; tmp="$(probe_sign_url "${names[$i]}" "${urls[$i]}")"
    all_output+="$tmp"$'\n'
  done
  echo -e "\n${CYAN}───────── 测试结果 ─────────${NC}"
  echo -e "$all_output"
}

# ========== 工具函数 ==========
service_name_of() { echo "sdsh_lagrange_$1"; }
instance_dir_of() { echo "$instances_dir/$1"; }
config_path_of()  { echo "$instances_dir/$1/appsettings.json"; }

ensure_config() {
  local reg="$1" cfg; cfg="$(config_path_of "$reg")"
  [[ -f "$cfg" ]] || { echo -e "${WHITE_ON_RED}未找到配置：$cfg${NC}"; return 1; }
  return 0
}

get_forward_port_from_cfg() {
  local cfg="$1"
  jq -r '.Implementations[]?|select(.Type=="ForwardWebSocket")|.Port' "$cfg" 2>/dev/null | head -n1
}

# 读取并校验端口：去空白、默认值、范围校验（1~65535），结果放到全局变量 REPLY_PORT
read_port() {
  local prompt="$1" cur="$2"
  local p
  while true; do
    read -p "$(echo -e ${YELLOW}${prompt}${NC}) " p
    # 空输入 => 用当前值；去掉所有空白
    p="${p:-$cur}"
    p="$(echo -n "$p" | tr -d '[:space:]')"
    # 必须是纯数字且 1~65535
    if [[ "$p" =~ ^[0-9]+$ ]] && (( p>=1 && p<=65535 )); then
      REPLY_PORT="$p"
      return 0
    fi
    echo -e "${RED}端口必须是 1~65535 的数字，请重新输入。${NC}"
  done
}

# 通用：读取某实现端口（不存在返回空）
get_impl_port() {
  local cfg="$1" type="$2"
  jq -r --arg t "$type" '.Implementations[]?|select(.Type==$t)|.Port' "$cfg" 2>/dev/null | head -n1
}

# 提议一个可用端口：从 base 开始，避开占用（lsof）与已配置端口
suggest_free_port() {
  local cfg="$1" base="$2"
  local used_ports
  used_ports="$(jq -r '.Implementations[]?.Port|select(type=="number")' "$cfg" 2>/dev/null || true)"
  local p="$base"
  while true; do
    # 是否与现有实现冲突
    if echo "$used_ports" | grep -qx "$p"; then
      ((p++)); continue
    fi
    # 是否被系统占用
    if lsof -i:"$p" &>/dev/null; then
      ((p++)); continue
    fi
    echo "$p"
    return 0
  done
}

# 读取端口（带默认），仅允许 1~65535 的数字；结果写入全局 REPLY_PORT
read_port_prompt() {
  local prompt="$1" defv="$2"
  local p
  while true; do
    read -p "$(echo -e ${YELLOW}${prompt}${NC}) " p
    p="${p:-$defv}"
    p="$(echo -n "$p" | tr -d '[:space:]')"
    if [[ "$p" =~ ^[0-9]+$ ]] && (( p>=1 && p<=65535 )); then
      REPLY_PORT="$p"
      return 0
    fi
    echo -e "${RED}端口必须是 1~65535 的数字，请重新输入。${NC}"
  done
}

# ========== 列表 ==========
list_instances() {
  local col1=20 col2=30 col3=12 col4=10
  echo -e "${CYAN}+$(printf '%-*s' $col1 '' | tr ' ' '-')+$(printf '%-*s' $col2 '' | tr ' ' '-')+$(printf '%-*s' $col3 '' | tr ' ' '-')+$(printf '%-*s' $col4 '' | tr ' ' '-')+${NC}"
  echo -e "${CYAN}|$(printf '%-*s' $col1 ' 注册名')|$(printf '%-*s' $col2 ' 显示名')|$(printf '%-*s' $col3 ' 运行状态')|$(printf '%-*s' $col4 ' Fwd端口')|${NC}"
  echo -e "${CYAN}+$(printf '%-*s' $col1 '' | tr ' ' '-')+$(printf '%-*s' $col2 '' | tr ' ' '-')+$(printf '%-*s' $col3 '' | tr ' ' '-')+$(printf '%-*s' $col4 '' | tr ' ' '-')+${NC}"

  while IFS=',' read -r reg display port_csv; do
    [[ -z "${reg:-}" ]] && continue
    local svc status cfg_port
    svc="$(service_name_of "$reg")"
    status="$(systemctl is-active "$svc" 2>/dev/null || true)"
    [[ "$status" == "active" ]] && status_str="${GREEN}运行中${NC}" || status_str="${RED}未运行${NC}"
    cfg_port="$(get_forward_port_from_cfg "$(config_path_of "$reg")" || true)"
    [[ -z "$cfg_port" || "$cfg_port" == "null" ]] && cfg_port="$port_csv"
    echo -e "|$(printf '%-*s' $col1 "${CYAN}${reg}${NC}")|$(printf '%-*s' $col2 "${BLUE}${display}${NC}")|$(printf '%-*s' $col3 "$status_str")|$(printf '%-*s' $col4 "${YELLOW}${cfg_port}${NC}")|"
  done < "$lagrange_csv"

  echo -e "${CYAN}+$(printf '%-*s' $col1 '' | tr ' ' '-')+$(printf '%-*s' $col2 '' | tr ' ' '-')+$(printf '%-*s' $col3 '' | tr ' ' '-')+$(printf '%-*s' $col4 '' | tr ' ' '-')+${NC}"
}

list_instances_with_index() {
  local col1=5 col2=20 col3=30 col4=12 col5=10
  echo -e "${CYAN}+$(printf '%-*s' $col1 '' | tr ' ' '-')+$(printf '%-*s' $col2 '' | tr ' ' '-')+$(printf '%-*s' $col3 '' | tr ' ' '-')+$(printf '%-*s' $col4 '' | tr ' ' '-')+$(printf '%-*s' $col5 '' | tr ' ' '-')+${NC}"
  echo -e "${CYAN}|$(printf '%-*s' $col1 ' 序号')|$(printf '%-*s' $col2 ' 注册名')|$(printf '%-*s' $col3 ' 显示名')|$(printf '%-*s' $col4 ' 运行状态')|$(printf '%-*s' $col5 ' Fwd端口')|${NC}"
  echo -e "${CYAN}+$(printf '%-*s' $col1 '' | tr ' ' '-')+$(printf '%-*s' $col2 '' | tr ' ' '-')+$(printf '%-*s' $col3 '' | tr ' ' '-')+$(printf '%-*s' $col4 '' | tr ' ' '-')+$(printf '%-*s' $col5 '' | tr ' ' '-')+${NC}"

  local i=1
  while IFS=',' read -r reg display port_csv; do
    [[ -z "${reg:-}" ]] && continue
    local svc status cfg_port
    svc="$(service_name_of "$reg")"
    status="$(systemctl is-active "$svc" 2>/dev/null || true)"
    [[ "$status" == "active" ]] && status_str="${GREEN}运行中${NC}" || status_str="${RED}未运行${NC}"
    cfg_port="$(get_forward_port_from_cfg "$(config_path_of "$reg")" || true)"
    [[ -z "$cfg_port" || "$cfg_port" == "null" ]] && cfg_port="$port_csv"
    echo -e "|$(printf '%-*s' $col1 "${WHITE}$i${NC}")|$(printf '%-*s' $col2 "${CYAN}${reg}${NC}")|$(printf '%-*s' $col3 "${BLUE}${display}${NC}")|$(printf '%-*s' $col4 "$status_str")|$(printf '%-*s' $col5 "${YELLOW}${cfg_port}${NC}")|"
    i=$((i+1))
  done < "$lagrange_csv"

  echo -e "${CYAN}+$(printf '%-*s' $col1 '' | tr ' ' '-')+$(printf '%-*s' $col2 '' | tr ' ' '-')+$(printf '%-*s' $col3 '' | tr ' ' '-')+$(printf '%-*s' $col4 '' | tr ' ' '-')+$(printf '%-*s' $col5 '' | tr ' ' '-')+${NC}"
}

pick_reg_by_index() {
  local idx="$1"
  sed -n "${idx}p" "$lagrange_csv" | cut -d',' -f1
}

# ========== 启停/日志 ==========
manage_service() {
  echo -e "\n${CYAN}选择服务：${NC}"
  list_instances_with_index
  read -p "请输入服务序号: " idx
  local reg="$(pick_reg_by_index "$idx")"
  [[ -z "$reg" ]] && { echo -e "${RED}无效选择！${NC}"; return; }
  local svc="$(service_name_of "$reg")"

  echo -e "\n${YELLOW}您选择了 ${svc}${NC}"
  echo -e "1 启动\n2 停止\n3 重启"
  read -p "请输入操作编号: " action
  case "$action" in
    1) systemctl start "$svc" && echo -e "${GREEN}已启动。${NC}" || echo -e "${RED}启动失败。${NC}" ;;
    2) systemctl stop "$svc"  && echo -e "${GREEN}已停止。${NC}" || echo -e "${RED}停止失败。${NC}" ;;
    3) systemctl restart "$svc" && echo -e "${GREEN}已重启。${NC}" || echo -e "${RED}重启失败。${NC}" ;;
    *) echo -e "${RED}无效选择！${NC}" ;;
  esac
}

view_logs() {
  echo -e "\n${CYAN}选择服务：${NC}"
  list_instances_with_index
  read -p "请输入服务序号: " idx
  local reg="$(pick_reg_by_index "$idx")"
  [[ -z "$reg" ]] && { echo -e "${RED}无效选择！${NC}"; return; }
  local svc="$(service_name_of "$reg")"

  echo -e "\n${YELLOW}您选择了 ${svc}${NC}"
  echo -e "1 输出日志\n2 监听日志"
  read -p "请输入操作编号: " action
  case "$action" in
    1) echo -e "${YELLOW}显示 ${svc} 的最新 200 行日志：${NC}"; journalctl -u "$svc" -n 200 --no-pager ;;
    2) echo -e "${YELLOW}正在监听 ${svc} 的日志... 按 Ctrl+C 停止。${NC}"; journalctl -u "$svc" -f ;;
    *) echo -e "${RED}无效选择！${NC}" ;;
  esac
}

# ========== 配置修改/删除 ==========
backup_cfg() {
  local cfg="$1"
  cp -f "$cfg" "${cfg}.bak.$(date +%Y%m%d%H%M%S)"
}

update_json_inplace() {
  local cfg="$1"; shift
  local tmp
  tmp="$(mktemp)"
  if jq "$@" "$cfg" >"$tmp"; then
    mv "$tmp" "$cfg"
  else
    rm -f "$tmp"
    echo -e "${WHITE_ON_RED}jq 写入失败，已保留原文件：${cfg}${NC}"
    return 1
  fi
}

restart_service_of() {
  local reg="$1" svc; svc="$(service_name_of "$reg")"
  systemctl restart "$svc" && echo -e "${GREEN}服务已重启：${svc}${NC}" || echo -e "${RED}服务重启失败：${svc}${NC}"
}

# 4.1 修改签名（含可达性测试与菜单）
change_signature() {
  local reg="$1" cfg; cfg="$(config_path_of "$reg")"; ensure_config "$reg" || return
  echo -e ""
  read -p "$(echo -e ${YELLOW}是否要执行签名可访问性测试？（y/n）：${NC})" do_probe
  [[ "$do_probe" =~ ^[yY]$ ]] && run_signature_probes

  print_signature_menu
  read -p "$(echo -e ${YELLOW}输入编号（1/2/3/4/5）：${NC}) " choice

  local lorana_cloudflare="https://cf-sign.xuetao.host/40768"
  local lorana_backbone="https://backbone.seal-sign.xuetao.host/sign/40768"
  local lorana_edge="https://edge.seal-sign.xuetao.host/sign/40768"
  local lorana_turbo="https://turbo.seal-sign.xuetao.host/sign/40768"
  local lorana_proxy_backup="http://39.108.115.52:58080/api/sign/39038"

  local url="$lorana_cloudflare"
  case "${choice:-}" in
    1) url="$lorana_cloudflare" ;;
    2) url="$lorana_backbone" ;;
    3) url="$lorana_edge" ;;
    4) url="$lorana_turbo" ;;
    5) url="$lorana_proxy_backup" ;;
    *) echo -e "${YELLOW}未选择有效编号，使用默认：${BLUE}雪桃家自签 - Cloudflare${NC}" ;;
  esac

  backup_cfg "$cfg"
  update_json_inplace "$cfg" --arg u "$url" '.SignServerUrl=$u'
  echo -e "${GREEN}签名地址已更新为：${BLUE}$url${NC}"
  restart_service_of "$reg"
}

# JSON 辅助：实现存在性检测
impl_exists() {
  local cfg="$1" type="$2"
  jq -e --arg t "$type" '.Implementations|map(select(.Type==$t))|length>0' "$cfg" >/dev/null
}

# 4.2 修改 正向WS 端口（若不存在则创建默认实现）
change_fwd_port() {
  local reg="$1" cfg; cfg="$(config_path_of "$reg")"; ensure_config "$reg" || return
  local cur
  cur="$(jq -r '.Implementations[]?|select(.Type=="ForwardWebSocket")|.Port' "$cfg" 2>/dev/null | head -n1)"
  [[ -z "$cur" || "$cur" == "null" ]] && cur="18080"

  read_port_prompt "请输入【正向WS】端口（当前 ${cur}，仅本机）：" "$cur"
  local newp="$REPLY_PORT"

  backup_cfg "$cfg"
  if impl_exists "$cfg" "ForwardWebSocket"; then
    update_json_inplace "$cfg" --argjson p "$newp" '(.Implementations[]|select(.Type=="ForwardWebSocket")|.Port)=$p'
  else
    update_json_inplace "$cfg" --argjson p "$newp" \
      '.Implementations += [{"Type":"ForwardWebSocket","Host":"127.0.0.1","Port":$p,"HeartBeatInterval":5000,"HeartBeatEnable":true,"AccessToken":""}]'
  fi

  echo -e "${GREEN}正向WS端口已更新：${YELLOW}${newp}${NC}"
  restart_service_of "$reg"
}

# 4.3 修改 反向WS 端口（可创建）
change_rev_port() {
  local reg="$1" cfg; cfg="$(config_path_of "$reg")"; ensure_config "$reg" || return
  local exists=0; impl_exists "$cfg" "ReverseWebSocket" && exists=1

  if (( exists==1 )); then
    # 已存在 => 直接修改
    local cur
    cur="$(get_impl_port "$cfg" "ReverseWebSocket")"
    [[ -z "$cur" || "$cur" == "null" ]] && cur="18081"
    read_port_prompt "请输入【反向WS】端口（当前 ${cur}）：" "$cur"
    local newp="$REPLY_PORT"

    backup_cfg "$cfg"
    update_json_inplace "$cfg" --argjson p "$newp" '(.Implementations[]|select(.Type=="ReverseWebSocket")|.Port)=$p'
    echo -e "${GREEN}反向WS端口已更新为：${YELLOW}${newp}${NC}"
    restart_service_of "$reg"
  else
    # 不存在 => 先问是否新建；建议：基于正向端口 +1 并找空闲
    read -p "$(echo -e ${YELLOW}未检测到[反向WS]配置，是否要新建？（y/n）：${NC}) " c
    [[ "$c" =~ ^[yY]$ ]] || { echo -e "${RED}已取消。${NC}"; return; }

    local fwd="$(get_impl_port "$cfg" "ForwardWebSocket")"
    [[ -z "$fwd" || "$fwd" == "null" ]] && fwd=18080
    local suggest; suggest="$(suggest_free_port "$cfg" $((fwd+1)))"

    read_port_prompt "未配置【反向WS】；建议端口：${suggest}。请输入端口（回车采用建议）：" "$suggest"
    local newp="$REPLY_PORT"

    backup_cfg "$cfg"
    update_json_inplace "$cfg" --argjson p "$newp" \
      '.Implementations += [{"Type":"ReverseWebSocket","Host":"127.0.0.1","Port":$p,"Suffix":"/ws","ReconnectInterval":5000,"HeartBeatInterval":5000,"AccessToken":""}]'
    echo -e "${GREEN}已新建反向WS，并设置端口：${YELLOW}${newp}${NC}"
    restart_service_of "$reg"
  fi
}

# 4.4 修改 HTTP 端口（可创建）
change_http_port() {
  local reg="$1" cfg; cfg="$(config_path_of "$reg")"; ensure_config "$reg" || return
  local exists=0; impl_exists "$cfg" "Http" && exists=1

  if (( exists==1 )); then
    local cur
    cur="$(get_impl_port "$cfg" "Http")"
    [[ -z "$cur" || "$cur" == "null" ]] && cur="18082"
    read_port_prompt "请输入【HTTP】端口（当前 ${cur}）：" "$cur"
    local newp="$REPLY_PORT"

    backup_cfg "$cfg"
    update_json_inplace "$cfg" --argjson p "$newp" '(.Implementations[]|select(.Type=="Http")|.Port)=$p'
    echo -e "${GREEN}HTTP 端口已更新为：${YELLOW}${newp}${NC}"
    restart_service_of "$reg"
  else
    read -p "$(echo -e ${YELLOW}未检测到[HTTP]配置，是否要新建？（y/n）：${NC}) " c
    [[ "$c" =~ ^[yY]$ ]] || { echo -e "${RED}已取消。${NC}"; return; }

    # 建议：优先在“反向+1”，否则“正向+2”，再找空闲
    local fwd="$(get_impl_port "$cfg" "ForwardWebSocket")"
    local rev="$(get_impl_port "$cfg" "ReverseWebSocket")"
    [[ -z "$fwd" || "$fwd" == "null" ]] && fwd=18080
    local base
    if [[ -n "$rev" && "$rev" != "null" ]]; then
      base=$((rev+1))
    else
      base=$((fwd+2))
    fi
    local suggest; suggest="$(suggest_free_port "$cfg" "$base")"

    read_port_prompt "未配置【HTTP】；建议端口：${suggest}。请输入端口（回车采用建议）：" "$suggest"
    local newp="$REPLY_PORT"

    backup_cfg "$cfg"
    update_json_inplace "$cfg" --argjson p "$newp" \
      '.Implementations += [{"Type":"Http","Host":"*","Port":$p,"AccessToken":""}]'
    echo -e "${GREEN}已新建 HTTP，并设置端口：${YELLOW}${newp}${NC}"
    restart_service_of "$reg"
  fi
}

# 5 删除服务配置（仅反向WS/HTTP，可多选）
delete_impl_menu() {
  local reg="$1" cfg; cfg="$(config_path_of "$reg")"; ensure_config "$reg" || return
  local has_rev=0 has_http=0
  impl_exists "$cfg" "ReverseWebSocket" && has_rev=1
  impl_exists "$cfg" "Http" && has_http=1

  local opts=()
  echo -e "\n${YELLOW}可删除的配置实现（ForwardWebSocket 不提供删除）：${NC}"
  if (( has_rev==1 )); then echo -e "  1) ReverseWebSocket"; opts+=(1); fi
  if (( has_http==1 )); then echo -e "  2) Http";          opts+=(2); fi
  if (( has_rev==0 && has_http==0 )); then
    echo -e "${RED}没有可删除的实现。${NC}"; return
  fi
  read -p "输入要删除的编号（可多选，空格分隔，如：1 2）： " choices

  backup_cfg "$cfg"
  for c in $choices; do
    case "$c" in
      1) (( has_rev==1 )) && update_json_inplace "$cfg" '.Implementations |= map(select(.Type!="ReverseWebSocket"))' ;;
      2) (( has_http==1 )) && update_json_inplace "$cfg" '.Implementations |= map(select(.Type!="Http"))' ;;
    esac
  done
  echo -e "${GREEN}已更新配置。${NC}"
  restart_service_of "$reg"
}

# 6 查看服务配置（原始/人话）
view_config() {
  # 如果传入了注册名，就直接用；否则进入交互选择
  local reg="${1:-}"
  if [[ -z "$reg" ]]; then
    echo -e "\n${CYAN}选择服务：${NC}"
    list_instances_with_index
    read -p "请输入服务序号: " idx
    reg="$(pick_reg_by_index "$idx")"
    [[ -z "$reg" ]] && { echo -e "${RED}无效选择！${NC}"; return; }
  fi

  local cfg="$(config_path_of "$reg")"
  ensure_config "$reg" || return

  echo -e "\n${YELLOW}查看方式：${NC}\n1 原始配置（直接cat文件）\n2 人话（看结构化摘要）"
  read -p "请输入编号: " m
  case "$m" in
    1)
      echo -e "${CYAN}----- $cfg -----${NC}"
      cat "$cfg"
      ;;
    2)
      echo -e "${CYAN}----- 配置摘要（${reg}） -----${NC}"
      local sign="$(jq -r '.SignServerUrl' "$cfg" 2>/dev/null)"
      echo -e "签名地址：${BLUE}${sign}${NC}"
      echo -e "配置列表："
      jq -r '.Implementations[]?|"\(.Type)  host=\(.Host//"-")  port=\(.Port//"-")  suffix=\(.Suffix//"-")  hb=\(.HeartBeatInterval//"-")"' "$cfg" \
        | sed "s/^/  - /"
      ;;
    *)
      echo -e "${RED}无效选择！${NC}"
      ;;
  esac
}

# 7 删除服务实例（移除 systemd + 目录 + CSV）
delete_instance() {
  echo -e "\n${CYAN}选择服务：${NC}"
  list_instances_with_index
  read -p "请输入服务序号: " idx
  local reg="$(pick_reg_by_index "$idx")"
  [[ -z "$reg" ]] && { echo -e "${RED}无效选择！${NC}"; return; }
  local svc="$(service_name_of "$reg")"
  local dir="$(instance_dir_of "$reg")"
  echo -e "${WHITE_ON_RED}危险操作！将删除实例目录并移除 systemd 服务！${NC}"
  read -p "确认删除 ${svc}（目录：$dir）？（y/n）" c1
  [[ "$c1" =~ ^[yY]$ ]] || { echo -e "${RED}已取消。${NC}"; return; }
  read -p "再次确认：真的要删除吗？（y/n）" c2
  [[ "$c2" =~ ^[yY]$ ]] || { echo -e "${RED}已取消。${NC}"; return; }

  systemctl stop "$svc" 2>/dev/null || true
  systemctl disable "$svc" 2>/dev/null || true
  sudo rm -f "/etc/systemd/system/${svc}.service"
  sudo systemctl daemon-reload

  rm -rf "$dir"
  sed -i "/^${reg},/d" "$lagrange_csv"

  echo -e "${GREEN}服务 ${svc} 与目录已删除。${NC}"
}

# 4 修改服务配置（聚合入口）
modify_config() {
  echo -e "\n${CYAN}选择服务：${NC}"
  list_instances_with_index
  read -p "请输入服务序号: " idx
  local reg="$(pick_reg_by_index "$idx")"
  [[ -z "$reg" ]] && { echo -e "${RED}无效选择！${NC}"; return; }

  local cfg="$(config_path_of "$reg")"
  ensure_config "$reg" || return

  echo -e "\n${YELLOW}你要修改什么？${NC}"
  echo -e "1 修改签名"
  echo -e "2 修改[正向WS]端口"
  echo -e "3 修改[反向WS]端口"
  echo -e "4 修改[HTTP]端口"
  echo -e "5 删除[反向WS]/[HTTP]服务"
  echo -e "6 查看配置"
  echo -e ""
  read -p "请输入编号: " which

  case "$which" in
    1) change_signature "$reg" ;;
    2) change_fwd_port "$reg" ;;
    3) change_rev_port "$reg" ;;
    4) change_http_port "$reg" ;;
    5) delete_impl_menu "$reg" ;;
    6) view_config "$reg" ;;
    *) echo -e "${RED}无效选择！${NC}" ;;
  esac
}

# ========== 主菜单 ==========
while true; do
  echo -e "\n${CYAN}Lagrange 服务管理：${NC}"
  echo -e "1 查看服务列表"
  echo -e "2 启停服务"
  echo -e "3 查看服务日志"
  echo -e "4 修改服务配置"
  echo -e "5 删除服务实例"
  echo -e "0 退出"
  read -p "请输入操作编号: " op

  case "$op" in
    1) list_instances ;;
    2) manage_service ;;
    3) view_logs ;;
    4) modify_config ;;
    5) delete_instance ;;
    0) echo -e "${GREEN}退出管理工具。${NC}"; exit 0 ;;
    *) echo -e "${RED}无效选择！${NC}" ;;
  esac
done
