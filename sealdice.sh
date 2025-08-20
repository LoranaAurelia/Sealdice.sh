#!/bin/bash

# 文件名定义
dice_script="deploy_dice.sh"
manage_dice_script="manage_dice.sh"
manage_napcat_script="manage_napcat.sh"
lagrange_script="deploy_lagrange.sh"
manage_lagrange_script="manage_lagrange.sh"
remote_url="https://raw.githubusercontent.com/LoranaAurelia/Sealdice.sh/main"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 无色

# 脚本存储路径
hidden_dir="/usr/local/sealdice-scripts"
env_file="/etc/profile.d/sealdice_env.sh"

# 检查是否初次运行并隐藏脚本
if [[ ! -d "$hidden_dir" ]]; then
    mkdir -p "$hidden_dir"
    # 下载主脚本
    curl -o "$hidden_dir/sealdice.sh" "$remote_url/sealdice.sh" && chmod +x "$hidden_dir/sealdice.sh"
    cd "$hidden_dir" || exit

    echo -e "${YELLOW}脚本存储目录：$hidden_dir${NC}"
    echo -e "${YELLOW}请输入工作目录 (默认为 /Sealdice) (直接回车使用默认): ${NC}"
    read -r work_dir
    work_dir=${work_dir:-/Sealdice}

    # 创建必要目录
    mkdir -p "$work_dir/sealdice-sh/downloads" "$work_dir/sealdice" "$work_dir/napcat" "$work_dir/lagrange"
    touch "$work_dir/sealdice-sh/data.csv"
    touch "$work_dir/sealdice-sh/lagrange.csv"
    chmod -R 777 "$work_dir"

    # 设置环境变量
    echo "export SEALDICE_WORK_DIR=$work_dir" | sudo tee "$env_file" > /dev/null
    export SEALDICE_WORK_DIR="$work_dir"  # 立即生效
    source "$env_file"

    # 下载所有辅助脚本
    echo -e "${YELLOW}正在下载所有依赖脚本...${NC}"
    curl -o "$hidden_dir/$dice_script"            "$remote_url/$dice_script"            && chmod +x "$hidden_dir/$dice_script"
    curl -o "$hidden_dir/$manage_dice_script"     "$remote_url/$manage_dice_script"     && chmod +x "$hidden_dir/$manage_dice_script"
    curl -o "$hidden_dir/$manage_napcat_script"   "$remote_url/$manage_napcat_script"   && chmod +x "$hidden_dir/$manage_napcat_script"
    curl -o "$hidden_dir/$lagrange_script"        "$remote_url/$lagrange_script"        && chmod +x "$hidden_dir/$lagrange_script"
    curl -o "$hidden_dir/$manage_lagrange_script" "$remote_url/$manage_lagrange_script" && chmod +x "$hidden_dir/$manage_lagrange_script"

    # 创建快捷命令
    sudo ln -sf "$hidden_dir/sealdice.sh" /usr/local/bin/sealdice
    echo -e "${GREEN}安装完成！现在可以直接使用 \"sealdice\" 命令运行脚本。${NC}"
    exit 0
fi

# 加载工作目录环境变量
if [[ -f "$env_file" ]]; then
    source "$env_file"
    if [[ -z "$SEALDICE_WORK_DIR" || ! -d "$SEALDICE_WORK_DIR" ]]; then
        echo -e "${RED}工作目录未正确设置或不存在，请重新配置工作目录！${NC}"
        echo -e "${YELLOW}请输入工作目录 (默认为 /Sealdice) (直接回车使用默认): ${NC}"
        read -r work_dir
        work_dir=${work_dir:-/Sealdice}

        # 创建必要目录
        mkdir -p "$work_dir/sealdice-sh/downloads" "$work_dir/sealdice" "$work_dir/napcat" "$work_dir/lagrange"
        touch "$work_dir/sealdice-sh/data.csv"
        touch "$work_dir/sealdice-sh/lagrange.csv"
        chmod -R 777 "$work_dir"

        # 更新环境变量
        echo "export SEALDICE_WORK_DIR=$work_dir" | sudo tee "$env_file" > /dev/null
        export SEALDICE_WORK_DIR="$work_dir"
        source "$env_file"

        echo -e "${GREEN}工作目录已更新并生效：$SEALDICE_WORK_DIR${NC}"
    fi
else
    echo -e "${YELLOW}环境变量文件不存在，正在创建默认工作目录！${NC}"
    echo -e "${YELLOW}请输入工作目录 (默认为 /Sealdice) (直接回车使用默认): ${NC}"
    read -r work_dir
    work_dir=${work_dir:-/Sealdice}

    # 创建必要目录
    mkdir -p "$work_dir/sealdice-sh/downloads" "$work_dir/sealdice" "$work_dir/napcat" "$work_dir/lagrange"
    touch "$work_dir/sealdice-sh/data.csv"
    touch "$work_dir/sealdice-sh/lagrange.csv"
    chmod -R 777 "$work_dir"

    # 创建环境变量文件
    echo "export SEALDICE_WORK_DIR=$work_dir" | sudo tee "$env_file" > /dev/null
    export SEALDICE_WORK_DIR="$work_dir"
    source "$env_file"

    echo -e "${GREEN}工作目录已设置并生效：$SEALDICE_WORK_DIR${NC}"
fi

# 主菜单
while true; do
    echo -e "\n${CYAN}-------- Sealdice 一键部署脚本 --------${NC}"
    echo -e "\n${BLUE}[ 部署相关 ]${NC}"
    echo -e "${GREEN}0${NC} 下载 Sealdice"
    echo -e "${GREEN}1${NC} 部署 Sealdice"
    echo -e "${GREEN}2${NC} 分离部署：部署 Napcat"
    echo -e "${GREEN}3${NC} 分离部署：部署 Lagrange"

    echo -e "\n${BLUE}[ 运行管理 ]${NC}"
    echo -e "${GREEN}4${NC} Sealdice 运行管理"
    echo -e "${GREEN}5${NC} Napcat 运行管理"
    echo -e "${GREEN}6${NC} Lagrange 运行管理"

    echo -e "\n${BLUE}[ 脚本操作 ]${NC}"
    echo -e "${GREEN}7${NC} 更新脚本"
    echo -e "${GREEN}8${NC} 卸载脚本"

    echo -e "\n${GREEN}9${NC} 退出脚本"

    echo -e "${CYAN}-------- By 雪桃 --------${NC}\n"

    read -p "请输入操作编号: " choice

    case $choice in
        0)
            bash "$hidden_dir/$dice_script" download "$SEALDICE_WORK_DIR"
            ;;
        1)
            bash "$hidden_dir/$dice_script" deploy "$SEALDICE_WORK_DIR"
            exit 0
            ;;

        2)
            echo -e "${CYAN}正在检查 Napcat 安装情况...${NC}"
            if command -v napcat &>/dev/null; then
                echo -e "${GREEN}Napcat 已检测到已安装！${NC}"
                read -p "是否执行 ${YELLOW}napcat update${NC} 进行更新？（y/n）" update_confirm
                if [[ "$update_confirm" =~ ^[yY]$ ]]; then
                    echo -e "${GREEN}正在执行 napcat update...${NC}"
                    if napcat update; then
                        echo -e "${GREEN}Napcat 更新成功！${NC}"
                        exit 0
                    else
                        echo -e "${RED}Napcat 更新失败，将尝试重新安装。${NC}"
                    fi
                else
                    echo -e "${RED}已取消更新操作。退出。${NC}"
                    exit 0
                fi
            fi

            # 如有历史目录，先提示删除（可选）
            if [[ -d "./Napcat" ]]; then
                echo -e "${WHITE_ON_RED}检测到当前目录下存在 ./Napcat 文件夹！${NC}"
                read -p "是否删除该文件夹后继续？（y/n）" confirm_rm
                if [[ "$confirm_rm" =~ ^[yY]$ ]]; then
                    rm -rf ./Napcat
                    echo -e "${GREEN}已删除 ./Napcat。${NC}"
                else
                    echo -e "${RED}操作已取消。${NC}"
                    exit 0
                fi
            fi

            echo -e "${CYAN}请选择安装镜像：${NC}"
            echo -e "1) Napcat 官方镜像（nclatest.znin.net）"
            echo -e "2) moeyy 代理"
            echo -e "3) 1win.eu 代理"
            echo -e "4) GitHub 原始镜像（raw.githubusercontent.com）"
            read -p "请输入选项（1/2/3/4）: " mirror_choice

            case "$mirror_choice" in
                1) NAPCAT_URL="https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh" ;;
                2) NAPCAT_URL="https://github.moeyy.xyz/https://raw.githubusercontent.com/NapNeko/NapCat-Installer/refs/heads/main/script/install.sh" ;;
                3) NAPCAT_URL="https://jiashu.1win.eu.org/https://raw.githubusercontent.com/NapNeko/NapCat-Installer/refs/heads/main/script/install.sh" ;;
                4) NAPCAT_URL="https://raw.githubusercontent.com/NapNeko/NapCat-Installer/refs/heads/main/script/install.sh" ;;
                *) echo -e "${RED}无效选择，退出安装！${NC}"; exit 1 ;;
            esac

            echo -e "${RED}在安装过程中请不要操作。确认开始安装 Napcat？（y/n）${NC}"
            read -r install_confirm
            if [[ ! "$install_confirm" =~ ^[yY]$ ]]; then
                echo -e "${RED}已取消安装。${NC}"
                exit 0
            fi

            echo -e "${GREEN}使用镜像：${BLUE}${NAPCAT_URL}${NC}"
            if curl -fsSL -o napcat.sh "$NAPCAT_URL"; then
                sudo bash napcat.sh --cli y --force
                rc=$?
                rm -f napcat.sh
                if [[ $rc -ne 0 ]]; then
                    echo -e "${WHITE_ON_RED}Napcat 安装脚本执行失败（exit=$rc）。请稍后重试或更换镜像。${NC}"
                    exit $rc
                fi
            else
                echo -e "${WHITE_ON_RED}下载安装脚本失败！请检查网络或更换镜像。${NC}"
                exit 1
            fi

            if command -v napcat &>/dev/null; then
                echo -e "${GREEN}Napcat 安装成功！可直接运行：${YELLOW}napcat${NC}"
            else
                echo -e "${RED}Napcat 安装失败，请检查日志。${NC}"
                exit 1
            fi
            ;;
        3)
            bash "$hidden_dir/$lagrange_script" deploy "$SEALDICE_WORK_DIR"
            exit 0
            ;;
        4)
            bash "$hidden_dir/$manage_dice_script"
            ;;
        5)
            bash "$hidden_dir/$manage_napcat_script"
            exit 0
            ;;
        6)
            bash "$hidden_dir/$manage_lagrange_script"
            exit 0
            ;;
        7)
            echo -e "${YELLOW}正在更新脚本...${NC}"
            curl -o "$hidden_dir/sealdice.sh"             "$remote_url/sealdice.sh"            && chmod +x "$hidden_dir/sealdice.sh"
            curl -o "$hidden_dir/$dice_script"            "$remote_url/$dice_script"           && chmod +x "$hidden_dir/$dice_script"
            curl -o "$hidden_dir/$manage_dice_script"     "$remote_url/$manage_dice_script"    && chmod +x "$hidden_dir/$manage_dice_script"
            curl -o "$hidden_dir/$manage_napcat_script"   "$remote_url/$manage_napcat_script"  && chmod +x "$hidden_dir/$manage_napcat_script"
            curl -o "$hidden_dir/$lagrange_script"        "$remote_url/$lagrange_script"       && chmod +x "$hidden_dir/$lagrange_script"
            curl -o "$hidden_dir/$manage_lagrange_script" "$remote_url/$manage_lagrange_script"&& chmod +x "$hidden_dir/$manage_lagrange_script"
            echo -e "${GREEN}脚本已更新！请重新执行sealdice命令！${NC}"
            exit 0
            ;;
        8)
            echo -e "${RED}完全卸载选项已选择。${NC}"

            # 提示用户将要删除的内容
            echo -e "${RED}即将删除以下内容：${NC}"
            echo -e "${YELLOW}- Sealdice 一键脚本${NC}"
            echo -e "${YELLOW}- 已部署的 Sealdice 服务${NC}"
            echo -e "${YELLOW}- Napcat 服务${NC}"
            echo -e "${YELLOW}- Lagrange 服务${NC}"
            read -p "这是不可逆的，您确认要继续吗？（y/n）" confirm_delete
            if [[ "$confirm_delete" != "y" && "$confirm_delete" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                return
            fi

            # 再次确认危险区域
            echo -e "${RED}危险区域！确认继续？（y/n）${NC}"
            read -p "" confirm_danger
            if [[ "$confirm_danger" != "y" && "$confirm_danger" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                return
            fi

            # 最终确认
            echo -e "${RED}Sealdice、Napcat 和 Lagrange 服务将被删除！继续？（y/n）${NC}"
            read -p "" final_confirm
            if [[ "$final_confirm" != "y" && "$final_confirm" != "Y" ]]; then
                echo -e "${RED}操作已取消。${NC}"
                return
            fi

            echo -e "${RED}正在完全卸载...${NC}"

            # 停止并删除所有以 sdsh_ 开头的服务
            echo -e "${YELLOW}正在处理系统服务...${NC}"
            for service in $(systemctl list-unit-files --type=service | grep "^sdsh_" | awk '{print $1}'); do
                echo -e "${YELLOW}正在停止服务: $service${NC}"
                if sudo systemctl stop "$service"; then
                    echo -e "${GREEN}服务 $service 停止成功。${NC}"
                else
                    echo -e "${RED}停止服务 $service 失败！请手动检查。${NC}"
                fi

                echo -e "${YELLOW}正在禁用服务: $service${NC}"
                if sudo systemctl disable "$service"; then
                    echo -e "${GREEN}服务 $service 禁用成功。${NC}"
                else
                    echo -e "${RED}禁用服务 $service 失败！请手动检查。${NC}"
                fi

                echo -e "${YELLOW}正在删除服务文件: $service${NC}"
                service_file=$(systemctl show -p FragmentPath "$service" | cut -d= -f2)
                if [[ -f "$service_file" ]]; then
                    if sudo rm -f "$service_file"; then
                        echo -e "${GREEN}服务文件 $service_file 删除成功。${NC}"
                    else
                        echo -e "${RED}删除服务文件 $service_file 失败！请手动检查。${NC}"
                    fi
                else
                    echo -e "${YELLOW}未找到服务文件 $service_file，可能已被手动删除。${NC}"
                fi
            done

            # 刷新系统服务状态
            echo -e "${YELLOW}刷新系统服务状态...${NC}"
            sudo systemctl daemon-reload
            sudo systemctl reset-failed

            # 检查是否有未成功删除的服务
            echo -e "${YELLOW}正在检查未删除的服务...${NC}"
            remaining_services=$(systemctl list-unit-files --type=service | grep "^sdsh_" | awk '{print $1}')
            if [[ -n "$remaining_services" ]]; then
                echo -e "${RED}以下服务仍然存在，请手动检查：${NC}"
                echo "$remaining_services"
            else
                echo -e "${GREEN}所有服务已成功删除。${NC}"
            fi

            # 删除环境变量
            echo -e "${YELLOW}正在删除环境变量配置...${NC}"
            if sudo rm -f "$env_file"; then
                echo -e "${GREEN}环境变量配置已删除。${NC}"
            else
                echo -e "${RED}未能删除环境变量配置，请手动检查文件: $env_file。${NC}"
            fi

            # 卸载 Napcat
            echo -e "${YELLOW}正在卸载 Napcat...${NC}"
            if command -v napcat &>/dev/null; then
                if napcat remove; then
                    echo -e "${GREEN}Napcat 卸载成功。${NC}"
                else
                    echo -e "${RED}Napcat 卸载失败，请手动检查。${NC}"
                fi
            else
                echo -e "${YELLOW}Napcat 未安装或已被移除，无需操作。${NC}"
            fi

            # 删除脚本相关文件和目录
            sudo rm -f /usr/local/bin/sealdice
            if [[ -n "$SEALDICE_WORK_DIR" ]]; then
                rm -rf "$SEALDICE_WORK_DIR"
                echo -e "${GREEN}工作目录 $SEALDICE_WORK_DIR 已删除。${NC}"
            fi
            rm -rf "$hidden_dir"
            echo -e "${GREEN}完全卸载完成！${NC}"
            exit 0
            ;;
        9)
            echo -e "${GREEN}退出脚本。${NC}"
            exit 0
            ;;
    esac

done
