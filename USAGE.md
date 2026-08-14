# 使用方式

## 准备

将 `macfuse-ntfs3g-kit/` 下的三个 `.command` 文件拖到桌面（可选，方便双击）。

## 三步流程

插上硬盘后，按顺序双击：

```
mount_ntfs.command    →   同步（见下方建议）    →   unmount_ntfs.command
   （挂载）                 （同步）                    （卸载）
```

### 1. mount_ntfs.command — 挂载

自动识别所有外接 NTFS 盘，卸载 macOS 的只读挂载，用 ntfs-3g 重新读写挂载到 `/Volumes/<盘名>`。

- 需要输入管理员密码
- 支持同时挂载多个盘

### 2. 同步 — 方案优先级

> ⚠️ 数据备份请务必按以下优先级选择工具，**不要直接使用命令行同步脚本**。详细说明见 [BACKUP_SOLUTIONS.md](BACKUP_SOLUTIONS.md)。

| 优先级 | 方案 | 说明 |
|--------|------|------|
| **首选** | 希捷官方 **Toolkit**（或 WD 配套的第三方同步软件） | 图形化、增量对比、冲突处理、版本历史，功能完整可靠 |
| **其次** | 希捷 Toolkit + 第三方同步工具组合（如 FreeFileSync） | 多盘场景下各取所长，互为补充 |
| **谨慎** | `sync_mirror.command` 命令行脚本 | ⚠️ **风险很大**：无图形界面、无版本历史、无冲突处理，误操作（如 `--delete`）可能造成数据不可逆丢失，仅在明确了解后果时使用 |

> 日常备份推荐首选或其次方案；`sync_mirror.command` 仅作个人数据临时归档的兜底手段。

### 3. unmount_ntfs.command — 卸载

卸载所有 ntfs-3g 挂载的盘，安全拔出。

- 需要输入管理员密码
- 不要用 Finder 弹出（可能导致 macFUSE 进程未正常退出）

## 验证挂载状态

```bash
mount | grep macfuse
# 应显示类似: /dev/disk4s2 on /Volumes/<盘名> (macfuse, local, synchronous)
```

## 注意事项

- `brew install` 可能因清华镜像 git 排队而超时，已设 `HOMEBREW_NO_AUTO_UPDATE=1` 跳过自动更新
- 需要手动更新 brew：`brew update`
- 清华镜像高峰期避开国内白天时段
