# 安装步骤

## 前提：卸载冲突驱动

如果之前安装过其他 NTFS 工具，先卸载避免冲突：

```bash
# Hasleo NTFS
sudo rm -f /Library/LaunchDaemons/com.hasleo.NTFS4MacMounterService.plist
sudo rm -rf "/Applications/Hasleo NTFS For Mac.app"

# Paragon NTFS
sudo rm -f /Library/LaunchDaemons/com.paragon-software.ntfs.pkg-installer.plist
sudo rm -f /Library/PrivilegedHelperTools/com.paragon-software.ntfs.pkg-installer
sudo rm -rf "/Library/Application Support/Paragon Software"
sudo rm -rf "/Applications/NTFS for Mac.app"
```

## 1. 安装 macFUSE

从 [macFUSE Releases](https://github.com/macfuse/macfuse/releases/latest) 下载最新 `.pkg` 安装。

> 国内无法访问时使用代理：`https://ghproxy.com/https://github.com/macfuse/macfuse/releases/latest`

安装后**重启 Mac**。重启后进入 **系统设置 → 隐私与安全性**，允许来自 "Benjamin Fleischer" 的系统扩展。

验证：
```bash
kextstat | grep macfuse   # 应显示 io.macfuse.filesystems.macfuse
```

## 2. 安装 ntfs-3g-mac

```bash
brew install ntfs-3g-mac
```

创建 mount_ntfs 链接（让系统能找到 ntfs-3g）：

```bash
sudo mkdir -p /usr/local/sbin
sudo ln -sf /opt/homebrew/Cellar/ntfs-3g-mac/2026.7.7/sbin/mount_ntfs /usr/local/sbin/mount_ntfs
```

> 注意：路径中的版本号 `2026.7.7` 可能不同，用 `ls /opt/homebrew/Cellar/ntfs-3g-mac/` 查看实际版本。

## 3. 安装 GNU rsync

macOS 自带的 `openrsync` 不兼容 NTFS，需要 GNU 版：

```bash
conda install -c conda-forge rsync -y
```

验证：
```bash
/opt/anaconda3/bin/rsync --version | head -1
# 应输出: rsync  version 3.1.3
```

## 4. 验证安装

```bash
# 检查核心组件
ls /opt/homebrew/bin/ntfs-3g
ls /usr/local/sbin/mount_ntfs
ls /opt/anaconda3/bin/rsync
```

全部完成。
