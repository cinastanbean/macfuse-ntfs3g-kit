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
| [BACKUP_SOLUTIONS.md](BACKUP_SOLUTIONS.md) | 工作备份方案建议 |

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

## ⚠️ 第三方同步工具的反向覆盖风险

`mount_ntfs.command` 挂载后，盘上文件由 ntfs-3g 管理。若 macOS 与 ntfs-3g 时区未统一，盘上文件的修改时间(mtime)会被偏移（典型为整段偏移本地时区，如中国 +8 小时）。

希捷 Toolkit、FreeFileSync 等同步工具靠 mtime 判断哪边"更新"。一旦盘上文件被读成"比本地新"，工具会判定**盘为源**，把盘内容**反向覆盖回本地**，导致本地文件被旧/错内容破坏（一般无版本历史，难恢复）。

应对：

1. 同步前先"预览/对比"，确认方向是 **本地→盘**（本地为主）；出现 盘→本地 立即取消。
2. 将 Mirror 设为**单向（本地为源）**，不要开双向/自动判定。
3. 优先用按**文件内容(hash)**比较，而非 mtime。
4. `mount_ntfs.command` 已注入系统时区（`TZ`）尽量消除偏移；但工具内部逻辑不在本 kit 控制范围内，方向仍需人工确认。

---

## 数据备份与同步建议

> ⚠️ **重要**：`sync_mirror.command` 基于 rsync，风险较大（无图形界面、无版本历史、无冲突处理），**仅适用于个人数据临时归档，不推荐用于日常工作备份**。

备份与同步工具的选择（希捷 Toolkit、第三方软件、rsync 的风险对比等），详见专题文档 [BACKUP_SOLUTIONS.md](BACKUP_SOLUTIONS.md)。

---

## 环境信息

| 组件 | 版本/路径 |
|------|-----------|
| macOS | 26.5.2 (ARM64) |
| macFUSE | 5.3.3 |
| ntfs-3g-mac | 2026.7.7 · `/opt/homebrew/bin/ntfs-3g` |
| rsync (GNU) | 3.1.3 · `/opt/anaconda3/bin/rsync` |
