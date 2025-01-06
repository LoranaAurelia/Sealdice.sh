#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE_ON_RED='\033[41;37m'
NC='\033[0m' # 无色

# 新增动态接收参数
work_dir="$2"
if [[ -z "$work_dir" ]]; then
    echo -e "${RED}工作目录未指定，请检查调用命令！${NC}"
    exit 1
fi

# 动态调整路径
data_file="$work_dir/sealdice-sh/data.csv"
download_dir="$work_dir/sealdice-sh/downloads"
sealdice_dir="$work_dir/sealdice/Dices"

# 检查文件是否存在
if [[ ! -f "$data_file" ]]; then
    echo -e "${RED}data.csv 文件未找到，请检查工作目录设置！${NC}"
    exit 1
fi

# 获取公网IP地址的API
ip_api="http://ipinfo.io/ip"

# 下载功能
if [[ "$1" == "download" ]]; then
    echo -e "${YELLOW}检测下载目录：$download_dir/sealdice${NC}"
    mkdir -p "$download_dir/sealdice/146" "$download_dir/sealdice/150"

    # 检测目录是否已存在内容
    if [[ -n $(ls -A "$download_dir/sealdice/146" 2>/dev/null) || -n $(ls -A "$download_dir/sealdice/150" 2>/dev/null) ]]; then
        echo -e "${YELLOW}下载目录中已存在内容，是否覆盖？(y/n)${NC}"
        while true; do
            read -r overwrite_choice
            if [[ "$overwrite_choice" == "y" || "$overwrite_choice" == "Y" ]]; then
                rm -rf "$download_dir/sealdice/146/*" "$download_dir/sealdice/150/*"
                break
            elif [[ "$overwrite_choice" == "n" || "$overwrite_choice" == "N" ]]; then
                echo -e "${RED}取消下载操作。${NC}"
                exit 0
            else
                echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
            fi
        done
    fi

    # 开始下载文件
    echo -e "${GREEN}开始下载 Sealdice 文件...${NC}"
    mkdir -p "$download_dir/sealdice/146" "$download_dir/sealdice/150"

    echo -e "${YELLOW}正在下载 1.4.6 版本...${NC}"
    curl -o "$download_dir/sealdice/146/146.tar.gz" https://d1.sealdice.com/sealdice-core_1.4.6_linux_amd64.tar.gz --progress-bar

    echo -e "${YELLOW}正在下载 1.5.0 版本...${NC}"
    curl -o "$download_dir/sealdice/150/150.tar.gz" https://d1.sealdice.com/dev/sealdice_20241230-51780a6_linux_amd64.tar.gz --progress-bar

    # 检查下载结果
    if [[ -f "$download_dir/sealdice/146/146.tar.gz" && -f "$download_dir/sealdice/150/150.tar.gz" ]]; then
        echo -e "${GREEN}Sealdice 文件下载完成！${NC}"
        exit 0
    else
        echo -e "${RED}下载失败，请检查网络连接或目标地址是否可用。${NC}"
        exit 1
    fi
fi

# 部署功能函数
deploy_dice() {
    local selected_version="$1"

    # 检测并显示现有注册信息
    # 检测并显示现有注册信息
    # 检测并显示现有注册信息
    # 检测并显示现有注册信息
    if [[ -s "$data_file" ]]; then
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
            echo -e "${CYAN}|${NC}$(printf '%-*s' $col1_width "${CYAN}${reg_name}${NC}")${CYAN}|${NC}$(printf '%-*s' $col2_width "${BLUE}${display_name}${NC}")${CYAN}|${NC}$(printf '%-*s' $col3_width "$status_colored")${CYAN}|${NC}$(printf '%-*s' $col4_width "${YELLOW}${version}${NC}")${CYAN}|${NC}$(printf '%-*s' $col5_width "${GREEN}${port}${NC}")${CYAN}|${NC}"
        done < "$data_file"

        # 打印底部边框
        echo -e "${CYAN}+$(printf '%-*s' $col1_width '' | tr ' ' '-')+$(printf '%-*s' $col2_width '' | tr ' ' '-')+$(printf '%-*s' $col3_width '' | tr ' ' '-')+$(printf '%-*s' $col4_width '' | tr ' ' '-')+$(printf '%-*s' $col5_width '' | tr ' ' '-')+${NC}"
    else
        echo -e "${YELLOW}当前没有任何已注册的 Sealdice 实例。${NC}"
    fi

    # 询问是否部署新骰
    echo -e "\n${YELLOW}是否部署新骰？（y/n）${NC}"
    while true; do
        read -r deploy_new
        if [[ "$deploy_new" == "y" || "$deploy_new" == "Y" ]]; then
            break
        elif [[ "$deploy_new" == "n" || "$deploy_new" == "N" ]]; then
            echo -e "${GREEN}取消部署操作，返回主菜单。${NC}"
            exit 0
        else
            echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
        fi
    done

    echo -e "\n${CYAN}开始部署 Sealdice $selected_version 版本${NC}"

    while true; do
        echo -e "${YELLOW}请输入注册名 (仅限小写英文字母、数字和下划线，最大长度 25): ${NC}"
        read -r reg_name
        if [[ ! "$reg_name" =~ ^[a-z0-9_]+$ ]]; then
            echo -e "${RED}注册名无效，只能包含小写英文字母、数字和下划线。请重新输入。${NC}"
            continue
        fi
        if [[ ${#reg_name} -gt 25 ]]; then
            echo -e "${RED}注册名过长，请确保长度不超过 25 个字符。${NC}"
            continue
        fi
        if grep -q "^$reg_name," "$data_file" 2>/dev/null; then
            echo -e "${RED}注册名已存在，请重新输入。${NC}"
            continue
        fi
        break
    done

    while true; do
        echo -e "${YELLOW}请输入别名/显示名: ${NC}"
        read -r display_name
        if [[ -z "$display_name" ]]; then
            echo -e "${RED}别名不能为空，请重新输入。${NC}"
            continue
        fi
        break
    done

    # 解压操作，确保显示路径和解压进度
    echo -e "${YELLOW}解压文件到路径: $sealdice_dir/$reg_name${NC}"
    mkdir -p "$sealdice_dir/$reg_name"

    # 检查目标文件是否存在
    if [[ ! -f "$download_dir/sealdice/$selected_version/$selected_version.tar.gz" ]]; then
        echo -e "${RED}解压失败：未找到文件 $download_dir/sealdice/$selected_version/$selected_version.tar.gz，请检查下载路径和文件！${NC}"
        exit 1
    fi

    # 解压并显示进度
    tar -xzvf "$download_dir/sealdice/$selected_version/$selected_version.tar.gz" -C "$sealdice_dir/$reg_name" | while IFS= read -r line; do
        echo -e "${GREEN}[解压中]${NC} $line"
    done

    # 验证解压结果
    if [[ -f "$sealdice_dir/$reg_name/sealdice-core" && -d "$sealdice_dir/$reg_name/lagrange" && -d "$sealdice_dir/$reg_name/data" ]]; then
        echo -e "${GREEN}文件解压完成，已解压至: $sealdice_dir/$reg_name${NC}"
    else
        echo -e "${RED}解压失败，缺少必要文件或文件夹，请检查压缩包内容！${NC}"
        exit 1
    fi

    # 验证解压结果
    if [[ -f "$sealdice_dir/$reg_name/sealdice-core" && -d "$sealdice_dir/$reg_name/lagrange" && -d "$sealdice_dir/$reg_name/data" ]]; then
        echo -e "${GREEN}文件解压完成，已解压至: $sealdice_dir/$reg_name${NC}"
        
        # 设置权限
        echo -e "${YELLOW}设置解压目录的权限...${NC}"
        chmod -R 755 "$sealdice_dir/$reg_name"
        chmod +x "$sealdice_dir/$reg_name/sealdice-core"
        echo -e "${GREEN}权限设置完成。${NC}"
    else
        echo -e "${RED}解压失败，缺少必要文件或文件夹，请检查压缩包内容！${NC}"
        exit 1
    fi

    while true; do
        echo -e "${YELLOW}你想指定端口为多少？（默认：3211，如果部署多个 Sealdice 请注意修改）${NC}"
        read -p "请输入端口: " port
        port=${port:-3211}

        if lsof -i:$port &>/dev/null; then
            echo -e "${RED}端口 $port 已被占用，请重新输入。${NC}"
            continue
        fi
        break
    done

# 防火墙放行端口
echo -e "${YELLOW}正在配置防火墙，放行端口 $port...${NC}"
if sudo ufw allow "$port" &>/dev/null; then
    echo -e "${GREEN}端口 $port 已成功放行。${NC}"
else
    echo -e "${RED}防火墙配置失败，无法放行端口 $port，请手动检查配置！${NC}"
    
    # 回滚逻辑：删除服务文件和 CSV 记录
    echo -e "${RED}回滚操作：清理创建的服务和 CSV 记录。${NC}"
    sudo rm -f "/etc/systemd/system/$service_name.service"
    sed -i "/^$reg_name,/d" "$data_file"
    sudo systemctl daemon-reload
    echo -e "${RED}清理完成，部署终止。${NC}"
    exit 1
fi

# 创建 systemd 服务并启动
service_name="sdsh_$reg_name"
service_path="/etc/systemd/system/$service_name.service"

cat <<EOL | sudo tee "$service_path"
[Unit]
Description=Sealdice Service for $reg_name
After=network.target

[Service]
Type=simple
WorkingDirectory=$sealdice_dir/$reg_name
ExecStart=$sealdice_dir/$reg_name/sealdice-core --address=0.0.0.0:$port
Restart=always

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl enable "$service_name"
sudo systemctl start "$service_name"

    # 确保服务启动成功后再写入 CSV
    if systemctl is-active --quiet "$service_name"; then
        public_ip=$(curl -s "$ip_api")

        # 获取可能的内网地址列表
        internal_ips=$(ip -o -4 addr show | awk '{print $4}' | cut -d/ -f1)

        echo -e "${CYAN}============================================${NC}"
        echo -e "${GREEN}服务创建成功！${NC}"
        echo -e "服务注册名：${CYAN}$reg_name${NC}"
        echo -e "显示名：${CYAN}$display_name${NC}"
        echo -e "服务版本：${CYAN}$selected_version${NC}"
        echo -e "服务端口：${CYAN}$port${NC}"
        echo -e "${YELLOW}访问地址：${NC}${BLUE}http://$public_ip:$port${NC}"
        echo -e "${YELLOW}可能的内网地址：${NC}"
        for ip in $internal_ips; do
            echo -e "${CYAN} - http://$ip:$port${NC}"
        done
        echo -e "${CYAN}============================================${NC}"

        echo -e "${YELLOW}提示：如果您的服务商为腾讯云、阿里云或 Azure等大厂，请确保放行端口 ${CYAN}$port${NC}"
        echo -e "${YELLOW}提示：如果您的主机为NAT机，请为端口 ${CYAN}$port ${YELLOW}映射${NC}"

        # 确保 CSV 文件写入在成功后执行
        echo "$reg_name,$display_name,$selected_version,$port" >> "$data_file"

        # 添加 exit 0 在此处终止脚本
        echo -e "${GREEN}部署完成，脚本结束。${NC}"
        exit 0
    else
        echo -e "${RED}============================================${NC}"
        echo -e "${RED}服务启动失败！${NC}"
        echo -e "请检查以下内容以排查问题："
        echo -e "1. ${CYAN}检查服务状态：${NC} sudo systemctl status $service_name"
        echo -e "2. ${CYAN}查看服务日志：${NC} sudo journalctl -u $service_name"
        echo -e "${YELLOW}建议：使用 AI 工具或搜索引擎进行问题排查，然后再咨询 Sealdice 社区。${NC}"
        echo -e "${RED}============================================${NC}"

        # 删除服务文件和记录
        echo -e "${RED}执行回滚操作：清理创建的服务配置。${NC}"
        sudo systemctl disable "$service_name" &>/dev/null
        sudo rm -f "/etc/systemd/system/$service_name.service"
        sudo systemctl daemon-reload

        echo -e "${RED}由于服务启动失败，所有相关配置已被清理。${NC}"
        exit 1
    fi
}

# 检查下载目录是否有必要文件
if [[ ! -f "$download_dir/sealdice/146/146.tar.gz" || ! -f "$download_dir/sealdice/150/150.tar.gz" ]]; then
    echo -e "${YELLOW}检测到你未曾进行过Sealdice的下载。是否立即下载？（y/n）${NC}"
    while true; do
        read -r download_choice
        if [[ "$download_choice" == "y" || "$download_choice" == "Y" ]]; then
            echo -e "${GREEN}开始下载 Sealdice 文件...${NC}"
            
            # 下载 1.4.6
            mkdir -p "$download_dir/sealdice/146"
            echo -e "${YELLOW}正在下载 1.4.6 版本...${NC}"
            curl -o "$download_dir/sealdice/146/146.tar.gz" https://d1.sealdice.com/sealdice-core_1.4.6_linux_amd64.tar.gz --progress-bar
            
            # 下载 1.5.0
            mkdir -p "$download_dir/sealdice/150"
            echo -e "${YELLOW}正在下载 1.5.0 版本...${NC}"
            curl -o "$download_dir/sealdice/150/150.tar.gz" https://d1.sealdice.com/dev/sealdice_20241230-51780a6_linux_amd64.tar.gz --progress-bar

            # 验证下载结果
            if [[ -f "$download_dir/sealdice/146/146.tar.gz" && -f "$download_dir/sealdice/150/150.tar.gz" ]]; then
                echo -e "${GREEN}Sealdice 文件下载完成！${NC}"
                break
            else
                echo -e "${RED}下载失败，请检查网络连接或目标地址是否可用。${NC}"
                exit 1
            fi
        elif [[ "$download_choice" == "n" || "$download_choice" == "N" ]]; then
            echo -e "${RED}下载被取消，无法继续部署。${NC}"
            exit 1
        else
            echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
        fi
    done
fi


while true; do
    echo -e "\n${CYAN}请选择你想部署的版本：${NC}"
    echo -e "${GREEN}1${NC} 1.4.6 (旧版本)"
    echo -e "${GREEN}2${NC} 1.5.0（预发布版，全新部署建议）"
    echo -e "${GREEN}3${NC} 我不知道它们的区别？"
    read -p "请输入选择 (1/2/3): " version_choice

    case $version_choice in
        1)
            while true; do
                echo -e "\n${YELLOW}你是否为全新部署？（y/n）${NC}"
                read -r is_fresh_146
                if [[ "$is_fresh_146" == "y" || "$is_fresh_146" == "Y" ]]; then
                    echo -e "\n${YELLOW}如果你是全新部署，建议使用${NC} ${WHITE_ON_RED}1.5.0版本${NC}${YELLOW}，以避免${WHITE_ON_RED}数据丢失风险${NC}${YELLOW}。\n你是否要切换去部署1.5.0？（y/n）${NC}"
                    read -r switch_to_150
                    if [[ "$switch_to_150" == "y" || "$switch_to_150" == "Y" ]]; then
                        echo -e "${GREEN}切换到部署 1.5.0 版本。${NC}"
                        deploy_dice "150"  # 直接调用 1.5.0 的部署逻辑
                        exit 0
                    elif [[ "$switch_to_150" == "n" || "$switch_to_150" == "N" ]]; then
                        echo -e "${GREEN}继续部署 1.4.6 版本。${NC}"
                        deploy_dice "146"  # 调用 1.4.6 的部署逻辑
                        exit 0
                    else
                        echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
                    fi
                elif [[ "$is_fresh_146" == "n" || "$is_fresh_146" == "N" ]]; then
                    echo -e "\n${YELLOW}1.4.6 版本为老数据库的版本。如果你需要迁移，并且之前的数据是来自 1.5.0 版本以上的话，请不要继续，建议选择 1.5.0 版本。\n是否继续？（y/n）${NC}"
                    read -r proceed_146
                    if [[ "$proceed_146" == "y" || "$proceed_146" == "Y" ]]; then
                        echo -e "\n${RED}我已仔细阅读，并确认我要部署 1.4.6 版本的 Sealdice。（y/n）${NC}"
                        read -r confirm_146
                        if [[ "$confirm_146" == "y" || "$confirm_146" == "Y" ]]; then
                            echo -e "${GREEN}继续部署 1.4.6 版本。${NC}"
                            deploy_dice "146"
                            exit 0
                        elif [[ "$confirm_146" == "n" || "$confirm_146" == "N" ]]; then
                            echo -e "${YELLOW}返回版本选择页面。${NC}"
                            continue 2
                        else
                            echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
                        fi
                    elif [[ "$proceed_146" == "n" || "$proceed_146" == "N" ]]; then
                        deploy_dice "150"
                        exit 0
                    else
                        echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
                    fi
                else
                    echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
                fi
            done
            ;;
        2)
            while true; do
                echo -e "\n${YELLOW}你是否为全新部署？（y/n）${NC}"
                read -r is_fresh_150
                if [[ "$is_fresh_150" == "y" || "$is_fresh_150" == "Y" ]]; then
                    echo -e "${GREEN}继续部署 1.5.0 版本。${NC}"
                    deploy_dice "150"
                    exit 0
                elif [[ "$is_fresh_150" == "n" || "$is_fresh_150" == "N" ]]; then
                    echo -e "\n${WHITE_ON_RED}请仔细阅读：1.5.0 的数据库更新可能会导致数据丢失！${NC}"
                    echo -e "${RED}主要丢失数据包括：人物卡、日志、群聊名称等。${NC}"
                    echo -e "${YELLOW}如果你的数据来自 1.4.6 并需要迁移，请备份好数据！是否继续？（y/n）${NC}"
                    read -r proceed_150
                    if [[ "$proceed_150" == "y" || "$proceed_150" == "Y" ]]; then
                        echo -e "\n${RED}我已确认如果持有 1.4.6 数据，在此过程中产生的数据丢失风险由我自行承担。（y/n）${NC}"
                        read -r confirm_150
                        if [[ "$confirm_150" == "y" || "$confirm_150" == "Y" ]]; then
                            echo -e "\n${RED}我已仔细阅读，并确认我要部署 1.5.0 版本。（y/n）${NC}"
                            read -r final_confirm_150
                            if [[ "$final_confirm_150" == "y" || "$final_confirm_150" == "Y" ]]; then
                                echo -e "${GREEN}继续部署 1.5.0 版本。${NC}"
                                deploy_dice "150"
                                exit 0
                            elif [[ "$final_confirm_150" == "n" || "$final_confirm_150" == "N" ]]; then
                                echo -e "${YELLOW}返回版本选择页面。${NC}"
                                continue 2
                            else
                                echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
                            fi
                        elif [[ "$confirm_150" == "n" || "$confirm_150" == "N" ]]; then
                            echo -e "${YELLOW}返回版本选择页面。${NC}"
                            continue 2
                        else
                            echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
                        fi
                    elif [[ "$proceed_150" == "n" || "$proceed_150" == "N" ]]; then
                        echo -e "${YELLOW}返回版本选择页面。${NC}"
                        continue 2
                    else
                        echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
                    fi
                else
                    echo -e "${RED}无效输入，请输入 y 或 n。${NC}"
                fi
            done
            ;;
        3)
            echo -e "${CYAN}1.4.6 是旧版数据库，1.5.0 是新版数据库，升级可能丢失数据。全新部署建议使用 1.5.0！${NC}"
            continue
            ;;
        *)
            echo -e "${RED}无效选择，请重新输入。${NC}"
            continue
            ;;
    esac
    break
done


# 默认提示
echo -e "${RED}未指定有效的操作参数 (download/deploy)。${NC}"
exit 1