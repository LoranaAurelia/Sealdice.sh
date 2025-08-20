#!/bin/bash
set -euo pipefail

# ========== 颜色 ==========
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE_ON_RED='\033[41;37m'
NC='\033[0m' # 无色

# ========== 依赖检测 ==========
if ! command -v napcat >/dev/null 2>&1; then
  echo -e "${WHITE_ON_RED}未检测到 Napcat 可执行文件！${NC}"
  echo -e "${YELLOW}请先安装 Napcat 后再运行本脚本。${NC}"
  exit 1
fi

# ========== 主循环（仅 1 个选项） ==========
while true; do
  clear || true
  echo -e "${YELLOW}┌────────────── Napcat 管理（精简版） ───────────────┐${NC}"
  echo -e "  Napcat 提供了更完善的交互式 TUI，请直接使用它完成："
  echo -e "  ${GREEN}添加/运行/停止账号、修改配置、查看日志、设置开机自启${NC}"
  echo -e ""
  echo -e "  直接命令： ${BLUE}napcat${NC}"
  echo -e "${YELLOW}└────────────────────────────────────────────────────┘${NC}"
  echo -e ""
  echo -e "${CYAN}请选择：${NC}"
  echo -e "1) 打开 Napcat TUI（等同执行：napcat）"
  echo -e "0) 退出"
  read -rp "输入编号: " op

  case "$op" in
    1)
      echo -e "${GREEN}进入 Napcat TUI（退出 TUI 可按 Ctrl+C 或按提示操作）...${NC}"
      # 使用 exec 让 TUI 接管当前终端，退出后直接结束脚本
      exec napcat
      ;;
    0)
      echo -e "${GREEN}已退出。${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}无效选项，请重试。${NC}"
      sleep 1
      ;;
  esac
done
