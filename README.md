# Sealdice.sh

这是一个一键部署和管理 Sealdice、Napcat 与 Lagrange 的脚本。

> **仅支持下列操作系统：**
>
> - Debian
> - Ubuntu

---

## 功能简介

- 一键部署 Sealdice
- 分离部署 Napcat 和 Lagrange
- 提供服务的运行管理（启停、日志查看、开机启动管理等）
- 便捷的脚本更新和卸载

---

## 系统要求

在执行脚本之前，请确保系统满足以下要求：

1. **操作系统**：Debian 或 Ubuntu
2. **用户权限**：强制要求 root 用户，sudo 不行。
3. **必要软件包**：需要以下工具已安装：
    - `curl`
    - `sudo`
    - `bash`
    - `wget`
    - `ufw`

使用以下命令安装必要的软件包：

```bash
apt update && apt install -y curl sudo bash wget ufw
```

---

## 使用方法

### 下载并运行脚本

执行以下命令下载并运行脚本：
```bash
curl -o sealdice.sh "https://sdsh.cn.xuetao.host/sealdice.sh" && chmod +x sealdice.sh && ./sealdice.sh
```

### 脚本主菜单

运行脚本后，您将看到类似以下的主菜单：

```plaintext
-------- Sealdice 一键部署脚本 --------

[ 部署相关 ]
0 下载 Sealdice
1 部署 Sealdice
2 分离部署：部署 Napcat
3 分离部署：部署 Lagrange

[ 运行管理 ]
4 Sealdice 运行管理
5 Napcat 运行管理
6 Lagrange 运行管理

[ 脚本操作 ]
7 更新脚本
8 卸载脚本

9 退出脚本
-------- By 雪桃 --------
```

根据提示输入数字选择相应的功能。

---

## 注意事项

1. **适配系统**：本脚本仅适用于 Debian 和 Ubuntu 系统，其它操作系统可能无法正常运行。
2. **防火墙配置**：脚本会自动开放必要的端口，请确保您的云服务商防火墙规则中相应端口已放行。
3. **NAT 网络**：如果您的主机位于 NAT 网络中，请自行配置端口映射。
4. **运行环境**：请在支持 `bash` 和 `sudo` 的环境下运行。

---

## 许可证

本项目采用 MIT 许可证。

---

感谢使用！希望脚本能为您带来便利！
