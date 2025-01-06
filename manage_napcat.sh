#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE_ON_RED='\033[41;37m'
NC='\033[0m' # 无色

# 检查是否安装 Napcat
if ! command -v napcat &>/dev/null; then
    echo -e "${RED}Napcat 未安装，请先安装后再运行此脚本！${NC}"
    exit 1
fi

# 显示当前运行的 Napcat 服务
show_napcat_status() {
    echo -e "\n${CYAN}当前 Napcat 服务状态：${NC}"
    napcat status || echo -e "${RED}未检测到任何运行的服务。${NC}"
}

# 主菜单
while true; do
    show_napcat_status

    echo -e "\n${CYAN}您想进行什么操作？${NC}"
    echo -e "1. 添加账号"
    echo -e "2. 运行账号"
    echo -e "3. 停止账号"
    echo -e "4. 修改账号配置"
    echo -e "5. 管理开机启动"
    echo -e "6. 查看日志"
    echo -e "7. 查看服务连接方式与地址"
    echo -e "0. 退出"
    read -p "请输入选项（1-6）：" option

    case $option in
        1)
            echo -e "${CYAN}请输入 Napcat 账号的 QQ 号：（请正确输入）${NC}"
            read -p "QQ 号: " qq_number

            # 检查 JSON 配置文件是否已存在
            config_file="/opt/QQ/resources/app/app_launcher/napcat/config/onebot11_${qq_number}.json"
            if [[ -f "$config_file" ]]; then
                echo -e "${WHITE_ON_RED}检测到配置文件已存在：$config_file${NC}"
                read -p "是否删除现有配置并重新创建？（y/n）" confirm
                if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                    echo -e "${RED}操作已取消。${NC}"
                    return
                fi
                rm -f "$config_file"
                echo -e "${GREEN}已删除现有配置文件。${NC}"
            fi

            # 创建 JSON 配置文件
            mkdir -p $(dirname "$config_file")
            cat > "$config_file" <<EOF
{
  "network": {
    "websocketClients": [],
    "websocketServers": [],
    "httpClients": [],
    "httpServers": []
  },
  "musicSignUrl": "",
  "enableLocalFile2Url": false,
  "parseMultMsg": true
}
EOF
            echo -e "${GREEN}配置文件已创建：$config_file${NC}"

            # 配置端口
            while true; do
                echo -e "${CYAN}您想使用什么端口？（请指定端口号，如果部署多个 Napcat 请注意选择不同的端口）${NC}"
                echo -e "${RED}Napcat 和 Sealdice 请不要使用相同端口！${NC}"
                read -p "端口号: " port

                # 检查端口是否被占用
                if lsof -i:$port &>/dev/null; then
                    echo -e "${RED}端口 $port 已被占用，请选择其他端口。${NC}"
                    continue
                fi
                break
            done

            # 配置 WebSocket 方式
            echo -e "${CYAN}您想使用什么 WebSocket 方式？${NC}"
            echo -e "1. 正向 WebSocket（默认推荐）"
            echo -e "2. 反向 WebSocket"
            read -p "请输入选项（1/2，默认 1）: " ws_choice
            ws_choice=${ws_choice:-1}

            if [[ "$ws_choice" == "1" ]]; then
                echo -e "${GREEN}正在配置正向 WebSocket...${NC}"
                jq ".network.websocketServers += [{\"name\": \"ws\", \"enable\": true, \"host\": \"0.0.0.0\", \"port\": $port, \"messagePostFormat\": \"array\", \"reportSelfMessage\": false, \"token\": \"\", \"enableForcePushEvent\": true, \"debug\": false, \"heartInterval\": 30000}]" "$config_file" > tmp.$$.json && mv tmp.$$.json "$config_file"
            else
                echo -e "${GREEN}正在配置反向 WebSocket...${NC}"
                jq ".network.websocketClients += [{\"name\": \"ws\", \"enable\": false, \"url\": \"ws://localhost:$port/ws\", \"messagePostFormat\": \"array\", \"reportSelfMessage\": false, \"reconnectInterval\": 5000, \"token\": \"\", \"debug\": false, \"heartInterval\": 30000}]" "$config_file" > tmp.$$.json && mv tmp.$$.json "$config_file"
            fi

            # 提示信息
            connection_type=$([[ "$ws_choice" == "1" ]] && echo "正向 WebSocket" || echo "反向 WebSocket")
            connection_url=$([[ "$ws_choice" == "1" ]] && echo "ws://localhost:$port" || echo "ws://localhost:$port/ws")

            # 输出高亮提示信息，确保可读性更好
            echo -e "${CYAN}"
            echo -e "=========================================="
            echo -e "         请将以下信息记录下来："
            echo -e "==========================================${NC}"
            echo -e ""
            echo -e "${YELLOW}连接方式：${NC}${GREEN}${connection_type}${NC}"
            echo -e "${YELLOW}连接地址：${NC}${BLUE}${connection_url}${NC}"
            echo -e ""
            echo -e "=========================================="
            echo -e "在之后的操作中："
            echo -e "1. 使用脚本提供的命令查看 Napcat 的日志，Napcat 会需要你扫码登录。"
            echo -e "2. 在账号成功登录后，向账号发送消息，检查 Napcat 是否可以成功接收。"
            echo -e "3. 如果连接成功，请 Ctrl+C 离开 Napcat 日志页面，并在 Sealdice 按照上述连接方式和连接地址进行连接。"
            echo -e "==========================================${NC}"
            echo -e ""

            read -p "你是否确认已记录并保存这些信息？（y/n）" save_confirm
            if [[ "$save_confirm" != "y" && "$save_confirm" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                exit 0
            fi

            read -p "是否继续下一步？（y/n）" continue_confirm
            if [[ "$continue_confirm" != "y" && "$continue_confirm" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                exit 0
            fi

            # 开放防火墙端口
            echo -e "${YELLOW}正在配置防火墙，放行端口 $port...${NC}"
            if sudo ufw allow "$port" &>/dev/null; then
                echo -e "${GREEN}端口 $port 已成功放行。${NC}"
            else
                echo -e "${RED}防火墙配置失败，无法放行端口 $port，请手动检查配置！${NC}"
                exit 1
            fi

            # 启动 Napcat
            echo -e "${CYAN}正在启动 Napcat...${NC}"
            napcat start "$qq_number"

            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Napcat 启动失败，请检查日志！${NC}"
                exit 1
            fi

            # 提示用户查看日志
            echo -e "${GREEN}Napcat 已成功启动！${NC}"
            echo -e "${CYAN}请手动运行以下命令进行扫码登入：${NC}\n"
            echo -e "${YELLOW}napcat log \"$qq_number\"${NC}\n"
            echo -e "${CYAN}您可以通过该命令进入 Napcat 的日志，进行扫码登入，完成后按 Ctrl+C 退出日志查看界面。${NC}"
            exit 0
            ;;
        2)
            # 运行账号
            echo -e "${CYAN}正在获取当前运行状态...${NC}"
            napcat status

            echo -e "${CYAN}正在扫描配置文件夹：/opt/QQ/resources/app/app_launcher/napcat/config${NC}"
            config_dir="/opt/QQ/resources/app/app_launcher/napcat/config"
            if [[ -d "$config_dir" ]]; then
                echo -e "${CYAN}检测到以下 QQ 配置文件：${NC}"
                for file in "$config_dir"/onebot11_*.json; do
                    [[ -f "$file" ]] || continue
                    qq_number=$(basename "$file" | sed 's/onebot11_//;s/.json//')
                    echo -e " - ${YELLOW}$qq_number${NC}"
                done
            else
                echo -e "${RED}未找到配置文件夹，请检查路径是否正确！${NC}"
                return
            fi

            echo -e "${CYAN}请输入您想运行的账号 QQ 号：${NC}"
            read -p "QQ 号: " qq_number

            # 检查 JSON 配置文件是否存在
            config_file="/opt/QQ/resources/app/app_launcher/napcat/config/onebot11_${qq_number}.json"
            if [[ ! -f "$config_file" ]]; then
                echo -e "${RED}未找到配置文件：$config_file，请确认账号是否正确！${NC}"
                return
            fi

            echo -e "${YELLOW}即将启动 Napcat 账号 $qq_number...${NC}"
            napcat start "$qq_number"

            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Napcat 账号 $qq_number 已成功启动！${NC}"
            else
                echo -e "${RED}启动失败，请检查日志或配置！${NC}"
            fi
            ;;

        3)
            # 停止账号
            echo -e "${CYAN}正在获取当前运行状态...${NC}"
            napcat status

            echo -e "${CYAN}正在扫描配置文件夹：/opt/QQ/resources/app/app_launcher/napcat/config${NC}"
            config_dir="/opt/QQ/resources/app/app_launcher/napcat/config"
            if [[ -d "$config_dir" ]]; then
                echo -e "${CYAN}检测到以下 QQ 配置文件：${NC}"
                for file in "$config_dir"/onebot11_*.json; do
                    [[ -f "$file" ]] || continue
                    qq_number=$(basename "$file" | sed 's/onebot11_//;s/.json//')
                    echo -e " - ${YELLOW}$qq_number${NC}"
                done
            else
                echo -e "${RED}未找到配置文件夹，请检查路径是否正确！${NC}"
                return
            fi

            echo -e "${CYAN}请输入您想停止的账号 QQ 号：${NC}"
            read -p "QQ 号: " qq_number

            # 检查 JSON 配置文件是否存在
            config_file="/opt/QQ/resources/app/app_launcher/napcat/config/onebot11_${qq_number}.json"
            if [[ ! -f "$config_file" ]]; then
                echo -e "${RED}未找到配置文件：$config_file，请确认账号是否正确！${NC}"
                return
            fi

            echo -e "${YELLOW}即将停止 Napcat 账号 $qq_number...${NC}"
            napcat stop "$qq_number"

            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Napcat 账号 $qq_number 已成功停止！${NC}"
            else
                echo -e "${RED}停止失败，请检查日志或配置！${NC}"
            fi
            ;;
        4)
            echo -e "${CYAN}正在获取当前运行状态...${NC}"
            napcat status

            # 检查配置文件夹中的 onebot11_ 开头的文件
            config_dir="/opt/QQ/resources/app/app_launcher/napcat/config"
            echo -e "${CYAN}正在扫描配置文件夹：${config_dir}${NC}"

            if [[ ! -d "$config_dir" ]]; then
                echo -e "${RED}配置目录不存在，请检查 Napcat 是否安装正确！${NC}"
                return
            fi

            qq_files=($(ls "$config_dir"/onebot11_*.json 2>/dev/null | grep -oP "onebot11_\K\d+"))
            if [[ ${#qq_files[@]} -eq 0 ]]; then
                echo -e "${RED}未找到任何 QQ 配置文件，请确认是否已添加账号！${NC}"
                return
            fi

            echo -e "${CYAN}检测到以下 QQ 配置文件：${NC}"
            for qq in "${qq_files[@]}"; do
                echo -e " - ${GREEN}${qq}${NC}"
            done

            echo -e "${CYAN}请输入您想修改的账号 QQ 号：（请正确输入）${NC}"
            read -p "QQ 号: " qq_number

            # 检查 JSON 配置文件是否存在
            config_file="${config_dir}/onebot11_${qq_number}.json"
            if [[ ! -f "$config_file" ]]; then
                echo -e "${RED}未找到配置文件：$config_file，请确认账号是否正确！${NC}"
                return
            fi

            echo -e "${CYAN}您想修改什么配置？${NC}"
            echo -e "1. 修改端口"
            echo -e "2. 修改正向/反向 WebSocket"
            echo -e "3. 修改监听/连接地址"
            read -p "请输入选项（1/2/3）: " modify_choice

            case $modify_choice in
                1) 
                    # 修改端口
                    while true; do
                        echo -e "${CYAN}请输入新的端口号：（请注意与现有服务的端口不冲突）${NC}"
                        read -p "端口号: " new_port

                        # 检查端口是否被占用
                        if lsof -i:$new_port &>/dev/null; then
                            echo -e "${RED}端口 $new_port 已被占用，请选择其他端口！${NC}"
                            continue
                        fi

                        # 更新 JSON 配置
                        if jq ".network.websocketServers |= map(.port = $new_port)" "$config_file" > tmp.$$.json; then
                            mv tmp.$$.json "$config_file"
                            echo -e "${GREEN}端口已更新为 $new_port！${NC}"
                            break
                        elif jq ".network.websocketClients |= map(.url |= \"ws://localhost:$new_port/ws\")" "$config_file" > tmp.$$.json; then
                            mv tmp.$$.json "$config_file"
                            echo -e "${GREEN}端口已更新为 $new_port！${NC}"
                            break
                        else
                            echo -e "${RED}更新端口失败，请检查配置文件！${NC}"
                            return
                        fi
                    done
                    ;;
                2) 
                    # 修改 WebSocket 方式
                    echo -e "${CYAN}您想使用什么 WebSocket 方式？${NC}"
                    echo -e "1. 正向 WebSocket"
                    echo -e "2. 反向 WebSocket"
                    read -p "请输入选项（1/2，默认 1）: " ws_choice
                    ws_choice=${ws_choice:-1}

                    if [[ "$ws_choice" == "1" ]]; then
                        # 配置正向 WebSocket
                        jq ".network.websocketClients = [] | .network.websocketServers += [{\"name\": \"ws\", \"enable\": true, \"host\": \"0.0.0.0\", \"port\": 3001, \"messagePostFormat\": \"array\", \"reportSelfMessage\": false, \"token\": \"\", \"enableForcePushEvent\": true, \"debug\": false, \"heartInterval\": 30000}]" "$config_file" > tmp.$$.json && mv tmp.$$.json "$config_file"
                        echo -e "${GREEN}已切换为正向 WebSocket！${NC}"
                    else
                        # 配置反向 WebSocket
                        jq ".network.websocketServers = [] | .network.websocketClients += [{\"name\": \"ws\", \"enable\": false, \"url\": \"ws://localhost:3001/ws\", \"messagePostFormat\": \"array\", \"reportSelfMessage\": false, \"reconnectInterval\": 5000, \"token\": \"\", \"debug\": false, \"heartInterval\": 30000}]" "$config_file" > tmp.$$.json && mv tmp.$$.json "$config_file"
                        echo -e "${GREEN}已切换为反向 WebSocket！${NC}"
                    fi
                    ;;
                3)
                    # 修改监听/连接地址
                    if jq ".network.websocketServers | length > 0" "$config_file" | grep -q true; then
                        echo -e "${CYAN}当前为正向 WebSocket，请选择监听地址：${NC}"
                        echo -e "1. 0.0.0.0（允许外部访问）"
                        echo -e "2. 127.0.0.1（仅本地访问）"
                        echo -e "3. 自定义地址"
                        read -p "请输入选项（1/2/3）: " addr_choice

                        case $addr_choice in
                            1) 
                                new_host="0.0.0.0"
                                ;;
                            2) 
                                new_host="127.0.0.1"
                                ;;
                            3)
                                read -p "请输入自定义地址: " new_host
                                ;;
                            *)
                                echo -e "${RED}无效选择，操作已取消！${NC}"
                                return
                                ;;
                        esac

                        jq ".network.websocketServers |= map(.host = \"$new_host\")" "$config_file" > tmp.$$.json && mv tmp.$$.json "$config_file"
                        echo -e "${GREEN}监听地址已更新为 $new_host！${NC}"
                    else
                        echo -e "${CYAN}当前为反向 WebSocket，请输入连接地址（不需要包含 /ws）：${NC}"
                        read -p "连接地址: " new_url

                        jq ".network.websocketClients |= map(.url = \"ws://$new_url/ws\")" "$config_file" > tmp.$$.json && mv tmp.$$.json "$config_file"
                        echo -e "${GREEN}连接地址已更新为 ws://$new_url/ws！${NC}"
                    fi
                    ;;
                *)
                    echo -e "${RED}无效选择！${NC}"
                    ;;
            esac
            ;;
        5)
            # 管理开机启动
            echo -e "${CYAN}您想开启某账号的开机启动，还是关闭开机启动？${NC}"
            echo -e "1 开启"
            echo -e "2 关闭"
            read -p "请输入选项（1/2）: " startup_choice

            if [[ "$startup_choice" != "1" && "$startup_choice" != "2" ]]; then
                echo -e "${RED}无效选择，操作已取消。${NC}"
                return
            fi

            echo -e "${CYAN}正在获取当前运行状态...${NC}"
            napcat status

            echo -e "${CYAN}正在扫描配置文件夹：/opt/QQ/resources/app/app_launcher/napcat/config${NC}"
            config_dir="/opt/QQ/resources/app/app_launcher/napcat/config"
            if [[ -d "$config_dir" ]]; then
                echo -e "${CYAN}检测到以下 QQ 配置文件：${NC}"
                for file in "$config_dir"/onebot11_*.json; do
                    [[ -f "$file" ]] || continue
                    qq_number=$(basename "$file" | sed 's/onebot11_//;s/.json//')
                    echo -e " - ${YELLOW}$qq_number${NC}"
                done
            else
                echo -e "${RED}未找到配置文件夹，请检查路径是否正确！${NC}"
                return
            fi

            echo -e "${CYAN}请输入您想设置的账号 QQ 号：${NC}"
            read -p "QQ 号: " qq_number

            # 检查 JSON 配置文件是否存在
            config_file="/opt/QQ/resources/app/app_launcher/napcat/config/onebot11_${qq_number}.json"
            if [[ ! -f "$config_file" ]]; then
                echo -e "${RED}未找到配置文件：$config_file，请确认账号是否正确！${NC}"
                return
            fi

            if [[ "$startup_choice" == "1" ]]; then
                echo -e "${YELLOW}即将为 Napcat 账号 $qq_number 添加开机启动...${NC}"
                napcat startup "$qq_number"
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}账号 $qq_number 的开机启动已成功添加！${NC}"
                else
                    echo -e "${RED}设置失败，请检查日志或配置！${NC}"
                fi
            else
                echo -e "${YELLOW}即将取消 Napcat 账号 $qq_number 的开机启动...${NC}"
                napcat startdown "$qq_number"
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}账号 $qq_number 的开机启动已成功取消！${NC}"
                else
                    echo -e "${RED}设置失败，请检查日志或配置！${NC}"
                fi
            fi
            ;;
        6)
            # 查看日志
            echo -e "${YELLOW}在日志查看界面中，使用 Ctrl+C 来退出。是否继续？（y/n）${NC}"
            read -p "请输入选择: " log_confirm
            if [[ "$log_confirm" != "y" && "$log_confirm" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                return
            fi

            echo -e "${CYAN}正在获取当前运行状态...${NC}"
            napcat status

            echo -e "${CYAN}请输入您想查看日志的账号 QQ 号：${NC}"
            read -p "QQ 号: " qq_number

            echo -e "${CYAN}正在查看 Napcat 账号 $qq_number 的日志... 按 Ctrl+C 退出。${NC}"
            napcat log "$qq_number"
            ;;
        7)
            # 查看连接方式与地址
            echo -e "${CYAN}正在扫描配置文件夹：${NC}/opt/QQ/resources/app/app_launcher/napcat/config"

            config_dir="/opt/QQ/resources/app/app_launcher/napcat/config"
            if [[ ! -d "$config_dir" ]]; then
                echo -e "${RED}配置文件夹不存在，请确认 Napcat 是否已安装！${NC}"
                return
            fi

            echo -e "${CYAN}检测到以下 QQ 配置文件：${NC}"
            configs=$(ls "$config_dir" | grep '^onebot11_.*\.json$')
            if [[ -z "$configs" ]]; then
                echo -e "${RED}未检测到任何配置文件，请确认是否已部署账号！${NC}"
                return
            fi

            echo -e "${YELLOW}"
            echo -e "=========================================="
            echo -e "         检测到的账号："
            echo -e "==========================================${NC}"

            for config in $configs; do
                qq_number=$(echo "$config" | sed -E 's/onebot11_(.*)\.json/\1/')
                echo -e " - ${GREEN}$qq_number${NC}"
            done

            echo -e ""
            read -p "请输入您要查看的账号 QQ 号: " qq_number
            config_file="$config_dir/onebot11_${qq_number}.json"

            if [[ ! -f "$config_file" ]]; then
                echo -e "${RED}未找到配置文件：$config_file，请确认 QQ 号是否正确！${NC}"
                return
            fi

            echo -e "${CYAN}正在读取配置文件...${NC}"

            # 获取连接方式和地址
            connection_type=""
            connection_url=""
            if jq -e ".network.websocketServers | length > 0" "$config_file" &>/dev/null; then
                connection_type="正向 WebSocket"
                connection_port=$(jq -r ".network.websocketServers[0].port" "$config_file")
                connection_url="ws://localhost:$connection_port"
            elif jq -e ".network.websocketClients | length > 0" "$config_file" &>/dev/null; then
                connection_type="反向 WebSocket"
                connection_url=$(jq -r ".network.websocketClients[0].url" "$config_file")
            else
                echo -e "${RED}配置文件中未找到有效的连接信息！${NC}"
                return
            fi

            # 输出高亮提示信息，确保可读性更好
            echo -e "${CYAN}"
            echo -e "=========================================="
            echo -e "    请按照以下内容填入Sealdice进行连接："
            echo -e "==========================================${NC}"
            echo -e ""
            echo -e "${YELLOW}连接方式：${NC}${GREEN}${connection_type}${NC}"
            echo -e "${YELLOW}连接地址：${NC}${BLUE}${connection_url}${NC}"
            ;;
        0)
            echo -e "${GREEN}退出 Napcat 管理工具。${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重新输入！${NC}"
            ;;
    esac

done
