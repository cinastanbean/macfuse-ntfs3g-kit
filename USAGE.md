# 使用方式

## 准备

将 `macfuse-ntfs3g-kit/` 下的三个 `.command` 文件拖到桌面（可选，方便双击）。

## 三步流程

插上硬盘后，按顺序双击：

```
mount_ntfs.command    →   sync_mirror.command / 其他工具   →   unmount_ntfs.command
   （挂载）                 （同步）                                （卸载）
```

### 1. mount_ntfs.command — 挂载

自动识别所有外接 NTFS 盘，卸载 macOS 的只读挂载，用 ntfs-3g 重新读写挂载到 `/Volumes/<盘名>`。

- 需要输入管理员密码
- 支持同时挂载多个盘

### 2. sync_mirror.command — 增量同步

将本地 `Mirror` 目录增量同步到外接 NTFS 移动硬盘。

- 第一次全量复制约 23G，后续只传输变化文件
- 源目录删掉的文件，目标也会同步删除
- 不需要密码

> 如需同步到其他盘，编辑 `sync_mirror.command` 中的 `DST` 变量。

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
