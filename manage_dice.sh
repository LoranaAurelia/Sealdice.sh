#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
WHITE_ON_RED='\033[41;37m'
NC='\033[0m' # 无色

# CSV 数据文件路径
work_dir="$SEALDICE_WORK_DIR"
data_file="$work_dir/sealdice-sh/data.csv"

# 检查 CSV 文件是否存在
if [[ ! -f "$data_file" ]]; then
    echo -e "${WHITE_ON_RED}CSV 文件未找到，请检查工作目录！${NC}"
    exit 1
fi

# 移除 ANSI 颜色码的辅助函数
strip_ansi_codes() {
    echo -e "$1" | sed 's/\x1B\[[0-9;]*[mK]//g'
}

list_services() {
    # 定义列宽
    col1_width=20  # 注册名宽度
    col2_width=30  # 显示名宽度
    col3_width=15  # 运行状态宽度
    col4_width=10  # 版本宽度
    col5_width=10  # 端口宽度

    # 打印边框和表头
    echo -e "${CYAN}+$(printf '%-*s' $col1_width '' | tr ' ' '-')+$(printf '%-*s' $col2_width '' | tr ' ' '-')+$(printf '%-*s' $col3_width '' | tr ' ' '-')+$(printf '%-*s' $col4_width '' | tr ' ' '-')+$(printf '%-*s' $col5_width '' | tr ' ' '-')+${NC}"
    echo -e "${CYAN}|$(printf '%-*s' $col1_width " 注册名")|$(printf '%-*s' $col2_width " 显示名")|$(printf '%-*s' $col3_width " 运行状态")|$(printf '%-*s' $col4_width " 版本")|$(printf '%-*s' $col5_width " 端口")|${NC}"
    echo -e "${CYAN}+$(printf '%-*s' $col1_width '' | tr ' ' '-')+$(printf '%-*s' $col2_width '' | tr ' ' '-')+$(printf '%-*s' $col3_width '' | tr ' ' '-')+$(printf '%-*s' $col4_width '' | tr ' ' '-')+$(printf '%-*s' $col5_width '' | tr ' ' '-')+${NC}"

    # 遍历 CSV 数据并打印内容
    while IFS=',' read -r reg_name display_name version port; do
        service_name="sdsh_$reg_name"
        status=$(systemctl is-active "$service_name" 2>/dev/null || echo "未运行")

        # 根据状态选择颜色
        status_colored=$([[ "$status" == "active" ]] && echo -e "${GREEN}运行中${NC}" || echo -e "${RED}未运行${NC}")

        # 打印内容
        echo -e "|$(printf '%-*s' $col1_width "${CYAN}${reg_name}${NC}")|$(printf '%-*s' $col2_width "${BLUE}${display_name}${NC}")|$(printf '%-*s' $col3_width "$status_colored")|$(printf '%-*s' $col4_width "${YELLOW}${version}${NC}")|$(printf '%-*s' $col5_width "${GREEN}${port}${NC}")|"
    done < "$data_file"

    # 打印底部边框
    echo -e "${CYAN}+$(printf '%-*s' $col1_width '' | tr ' ' '-')+$(printf '%-*s' $col2_width '' | tr ' ' '-')+$(printf '%-*s' $col3_width '' | tr ' ' '-')+$(printf '%-*s' $col4_width '' | tr ' ' '-')+$(printf '%-*s' $col5_width '' | tr ' ' '-')+${NC}"
}

list_services_with_index() {
    # 定义列宽
    col1_width=5   # 序号宽度
    col2_width=20  # 注册名宽度
    col3_width=30  # 显示名宽度
    col4_width=15  # 运行状态宽度
    col5_width=10  # 版本宽度
    col6_width=10  # 端口宽度

    # 打印边框和表头
    echo -e "${CYAN}+$(printf '%-*s' $col1_width '' | tr ' ' '-')+$(printf '%-*s' $col2_width '' | tr ' ' '-')+$(printf '%-*s' $col3_width '' | tr ' ' '-')+$(printf '%-*s' $col4_width '' | tr ' ' '-')+$(printf '%-*s' $col5_width '' | tr ' ' '-')+$(printf '%-*s' $col6_width '' | tr ' ' '-')+${NC}"
    echo -e "${CYAN}|$(printf '%-*s' $col1_width " 序号")|$(printf '%-*s' $col2_width " 注册名")|$(printf '%-*s' $col3_width " 显示名")|$(printf '%-*s' $col4_width " 运行状态")|$(printf '%-*s' $col5_width " 版本")|$(printf '%-*s' $col6_width " 端口")|${NC}"
    echo -e "${CYAN}+$(printf '%-*s' $col1_width '' | tr ' ' '-')+$(printf '%-*s' $col2_width '' | tr ' ' '-')+$(printf '%-*s' $col3_width '' | tr ' ' '-')+$(printf '%-*s' $col4_width '' | tr ' ' '-')+$(printf '%-*s' $col5_width '' | tr ' ' '-')+$(printf '%-*s' $col6_width '' | tr ' ' '-')+${NC}"

    # 遍历 CSV 数据并打印内容
    local i=1
    while IFS=',' read -r reg_name display_name version port; do
        service_name="sdsh_$reg_name"
        status=$(systemctl is-active "$service_name" 2>/dev/null || echo "未运行")

        # 根据状态选择颜色
        status_colored=$([[ "$status" == "active" ]] && echo -e "${GREEN}运行中${NC}" || echo -e "${RED}未运行${NC}")

        # 打印内容
        echo -e "|$(printf '%-*s' $col1_width "${WHITE}$i${NC}")|$(printf '%-*s' $col2_width "${CYAN}${reg_name}${NC}")|$(printf '%-*s' $col3_width "${BLUE}${display_name}${NC}")|$(printf '%-*s' $col4_width "$status_colored")|$(printf '%-*s' $col5_width "${YELLOW}${version}${NC}")|$(printf '%-*s' $col6_width "${GREEN}${port}${NC}")|"
        i=$((i + 1))
    done < "$data_file"

    # 打印底部边框
    echo -e "${CYAN}+$(printf '%-*s' $col1_width '' | tr ' ' '-')+$(printf '%-*s' $col2_width '' | tr ' ' '-')+$(printf '%-*s' $col3_width '' | tr ' ' '-')+$(printf '%-*s' $col4_width '' | tr ' ' '-')+$(printf '%-*s' $col5_width '' | tr ' ' '-')+$(printf '%-*s' $col6_width '' | tr ' ' '-')+${NC}"
}

# 控制服务启停函数
manage_service() {
    echo -e "\n${CYAN}选择服务：${NC}"
    list_services_with_index

    read -p "请输入服务序号: " choice
    local selected_service="$(sed -n "${choice}p" "$data_file" | cut -d',' -f1)"
    
    if [[ -z "$selected_service" ]]; then
        echo -e "${RED}无效选择！${NC}"
        return
    fi

    service_name="sdsh_$selected_service"
    echo -e "\n${YELLOW}您选择了 $service_name${NC}"
    echo -e "1 启动\n2 停止\n3 重启"
    read -p "请输入操作编号: " action

    case $action in
        1)
            echo -e "${YELLOW}即将启动服务 $service_name。${NC}"
            systemctl start "$service_name"
            if systemctl is-active --quiet "$service_name"; then
                echo -e "${GREEN}服务 $service_name 已成功启动。${NC}"
            else
                echo -e "${RED}启动服务失败，请检查日志。${NC}"
            fi
            ;;
        2)
            echo -e "${YELLOW}即将停止服务 $service_name。${NC}"
            systemctl stop "$service_name"
            if ! systemctl is-active --quiet "$service_name"; then
                echo -e "${GREEN}服务 $service_name 已成功停止。${NC}"
            else
                echo -e "${RED}停止服务失败，请检查日志。${NC}"
            fi
            ;;
        3)
            echo -e "${YELLOW}即将重启服务 $service_name。${NC}"
            systemctl restart "$service_name"
            if systemctl is-active --quiet "$service_name"; then
                echo -e "${GREEN}服务 $service_name 已成功重启。${NC}"
            else
                echo -e "${RED}重启服务失败，请检查日志。${NC}"
            fi
            ;;
        *)
            echo -e "${RED}无效选择！${NC}"
            ;;
    esac
}

# 查看日志函数
view_logs() {
    echo -e "\n${CYAN}选择服务：${NC}"
    list_services_with_index

    read -p "请输入服务序号: " choice
    local selected_service="$(sed -n "${choice}p" "$data_file" | cut -d',' -f1)"
    
    if [[ -z "$selected_service" ]]; then
        echo -e "${RED}无效选择！${NC}"
        return
    fi

    service_name="sdsh_$selected_service"
    echo -e "\n${YELLOW}您选择了 $service_name${NC}"
    echo -e "1 输出日志\n2 监听日志"
    read -p "请输入操作编号: " action

    case $action in
        1)
            echo -e "${YELLOW}显示 $service_name 的最新 200 行日志：${NC}"
            journalctl -u "$service_name" -n 200 --no-pager
            ;;
        2)
            echo -e "${YELLOW}正在监听 $service_name 的日志... 按 Ctrl+C 停止。${NC}"
            journalctl -u "$service_name" -f
            ;;
        *)
            echo -e "${RED}无效选择！${NC}"
            ;;
    esac
}

delete_or_manage_service() {
    echo -e "\n${CYAN}选择服务：${NC}"
    list_services_with_index

    read -p "请输入服务序号: " choice
    local selected_service="$(sed -n "${choice}p" "$data_file" | cut -d',' -f1)"
    local display_name="$(sed -n "${choice}p" "$data_file" | cut -d',' -f2)"

    if [[ -z "$selected_service" ]]; then
        echo -e "${RED}无效选择！${NC}"
        return
    fi

    service_name="sdsh_$selected_service"
    echo -e "\n${YELLOW}您选择了 $service_name (${BLUE}$display_name${NC})${NC}"
    echo -e "1 启用服务\n2 停用服务\n3 删除服务"
    read -p "请输入操作编号: " action

    case $action in
        1)
            echo -e "${YELLOW}即将启用服务 $service_name（别名: $display_name）。${NC}"
            read -p "确认启用服务 $service_name 吗？（y/n）" confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                return
            fi

            systemctl enable "$service_name" &>/dev/null
            systemctl start "$service_name" &>/dev/null

            if systemctl is-active --quiet "$service_name"; then
                echo -e "${GREEN}服务 $service_name 已成功启用并启动。${NC}"
            else
                echo -e "${RED}启用服务失败，请检查日志。${NC}"
            fi
            ;;
        2)
            echo -e "${YELLOW}即将停用服务 $service_name（别名: $display_name）。${NC}"
            read -p "确认停用服务 $service_name 吗？（y/n）" confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                return
            fi

            systemctl stop "$service_name" &>/dev/null
            systemctl disable "$service_name" &>/dev/null

            if ! systemctl is-active --quiet "$service_name"; then
                echo -e "${GREEN}服务 $service_name 已成功停用并停止。${NC}"
            else
                echo -e "${RED}停用服务失败，请检查日志。${NC}"
            fi
            ;;
        3)
            echo -e "${WHITE_ON_RED}即将删除服务 $service_name（别名: $display_name）。此操作不会删除工作目录，但会移除系统服务记录！${NC}"
            echo -e "${RED}确认要删除服务 ${service_name} 吗？（y/n）${NC}"
            read -p "" confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                return
            fi

            echo -e "${RED}你知道你在做什么，对吧？（y/n）${NC}"
            read -p "" double_confirm
            if [[ "$double_confirm" != "y" && "$double_confirm" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                return
            fi
            systemctl stop "$service_name" &>/dev/null
            systemctl disable "$service_name" &>/dev/null
            sudo rm -f "/etc/systemd/system/$service_name.service"
            sudo systemctl daemon-reload

            sed -i "/^$selected_service,/d" "$data_file"

            echo -e "${GREEN}服务 $service_name 已成功删除！${NC}"
            ;;
        *)
            echo -e "${RED}无效选择！${NC}"
            ;;
    esac
}

# 主菜单
while true; do
    echo -e "\n${CYAN}Sealdice 服务管理菜单：${NC}"
    echo -e "1 查看服务列表\n2 启停服务\n3 查看服务日志\n4 删除服务\n\n0 退出"
    read -p "请输入操作编号: " option

    case $option in
        1)
            list_services
            ;;
        2)
            manage_service
            ;;
        3)
            view_logs
            ;;
        4)
            delete_or_manage_service
            ;;
        0)
            echo -e "${GREEN}退出管理工具。${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择！${NC}"
            ;;
    esac

done
