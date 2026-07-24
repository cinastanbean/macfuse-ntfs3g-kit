# macfuse-ntfs3g-kit

> 系统：macOS 26.5.2 (Tahoe) · Apple Silicon (M 系列)

---

## 项目定位

**免费开源的 macOS NTFS 工具集成**。本工程是对 macFUSE + ntfs-3g + GNU rsync 的打包封装，将分散的安装配置简化为一键脚本，提供挂载、同步、卸载一站式操作，不依赖任何付费商业软件。设计目标是可靠可用，不过分追求速度。

文档导航：

| 文档 | 内容 |
|------|------|
| [INSTALL.md](INSTALL.md) | 安装步骤 |
| [USAGE.md](USAGE.md) | 使用方式 |

---

## ntfs-3g vs Paragon NTFS for Mac

Paragon 是商业闭源驱动的标杆，性能出色但不免费。ntfs-3g 是开源替代，功能完整但速度存在差距：

| 对比维度 | Paragon NTFS | ntfs-3g |
|----------|-------------|---------|
| 驱动层级 | 内核态 | 用户空间（通过 macFUSE） |
| 缓存优化 | 内核级缓存 | FUSE 层桥接，无内核缓存 |
| 1GB 大文件写入 | ~80-100 MB/s | ~20-30 MB/s |
| 许可 | 收费（约 ￥100） | 免费开源 |
| 可靠性 | 高 | 高，数据完整性可靠 |

速度差距的根本原因：ntfs-3g 运行在用户空间，每次读写都要经过 macFUSE 桥接层，这是「免费」的交换代价。对于本项目的使用场景（定期增量同步备份），主要传输变化文件，实际体感差距不大。

---

## 为什么 Mac 不原生支持 NTFS 写入

Mac 原生只支持读取 NTFS，不支持写入。因为 NTFS 是微软的闭源专利格式，写入需要付费授权。苹果选择的跨平台格式是 exFAT（免费、两端均原生支持）。

要读写 NTFS，需要第三方驱动。本方案选择 macFUSE + ntfs-3g，因为它是唯一完全免费开源的路线。

### 插盘时的默认行为

当你把 NTFS 硬盘插入 Mac 后，系统会用 **macOS 自带的 NTFS 驱动**自动挂载，但这个驱动只支持**读取**，磁盘是只读状态。

`mount_ntfs.command` 脚本做的事情就是把它换成可读写的 ntfs-3g：

```
1. 卸载 →   diskutil unmount（解除 macOS 只读挂载）
2. 重载 →   ntfs-3g -o allow_other,...（用 ntfs-3g 重新读写挂载）
```

所以每次插盘后需要先执行 `mount_ntfs.command`，之后才能正常写入。

---

## 同步方案踩坑记录

macOS 文件写入 NTFS 时报 `Operation not permitted`，原因有两个：

1. **fchmodat 权限错误**：macOS 自带的 `openrsync` 即使加了 `--no-perms`，仍强制调用 `fchmodat()` 设置 Unix 权限，NTFS 不支持 chmod，直接中断同步。
2. **扩展属性 (xattr)**：macOS 文件的 `com.apple.quarantine`、`FinderInfo` 等扩展属性写入 NTFS 时被拒绝。

### 方案演进

| 尝试 | 方法 | 结果 |
|------|------|------|
| 1 | macOS 自带 `openrsync -av` | fchmodat 报错 |
| 2 | `openrsync + --no-t` | 仍报 fchmodat |
| 3 | `openrsync + --no-perms --chmod=ugo=rwX` | 仍报 fchmodat |
| 4 | `ditto -V` | xattr 报错即停 |
| 5 | `cp -Ruv` | macOS BSD cp 不支持 `-u` |
| 6 | `COPYFILE_DISABLE=1 + ditto` | 无效 |
| 7 | `COPYFILE_DISABLE=1 + cp -Rv` | 能复制，但全量无增量 |
| **8** ✅ | **conda GNU rsync 3.1.3** | `--no-perms` 真正生效，增量同步 |

### 最终同步命令

```bash
/opt/anaconda3/bin/rsync -av \
    --no-perms --no-owner --no-group --no-times \
    --delete --progress \
    --exclude '.DS_Store' --exclude '__pycache__/' --exclude '*.pyc' \
    --exclude '.pytest_cache/' --exclude 'node_modules/' --exclude '.codebuddy/' \
    --exclude '*.log' --exclude '.svn/' --exclude '.git/' \
    "$SRC"/ "$DST"/
```

### 为什么用 conda 装 rsync

- Homebrew 依赖清华镜像 git clone，高峰期排队 600+，安装超时
- conda 走独立二进制分发包通道，秒装

---

## 硬盘同步建议

本工程主要面向 **WD MyBook** 盘，使用 rsync 增量同步。

### 西部数据官方工具

WD 也提供官方管理软件，但同步功能不如希捷 Toolkit 完善：

| 工具 | 说明 |
|------|------|
| **WD Discovery** | 桌面管理软件，支持 macOS。主要用于硬盘检测、加密管理、社交媒体导入，备份/同步功能较基础。已有最新版 5.3。 |
| **Acronis True Image for WD** | 全盘镜像备份工具，WD 用户免费。偏向系统级整机备份，不适合日常文件增量同步。 |
| **WD Backup** | 已停产，被 WD Discovery 取代。 |

> 结论：WD 官方工具在文件同步场景下不如 rsync 脚本灵活。MyBook 盘继续用 rsync 即可，没必要折腾 WD Discovery。

### 希捷官方工具

如果用的是 **希捷 (Seagate) Beanut** 盘，推荐使用希捷官方的 **Toolkit** 软件。Toolkit 提供图形化同步、备份、镜像等功能，免去命令行操作，对希捷硬盘兼容性更好。

> 两种方案并存：MyBook 走 rsync 脚本，Beanut 走 Toolkit，互不干扰。

---

## 环境信息

| 组件 | 版本/路径 |
|------|-----------|
| macOS | 26.5.2 (ARM64) |
| macFUSE | 5.3.3 |
| ntfs-3g-mac | 2026.7.7 · `/opt/homebrew/bin/ntfs-3g` |
| rsync (GNU) | 3.1.3 · `/opt/anaconda3/bin/rsync` |
