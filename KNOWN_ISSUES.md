# 已知问题与稳定性说明 (KNOWN ISSUES)

> 本工具 = macFUSE + ntfs-3g，免费开源、数据完整性可靠，但**运行在用户空间**（每次读写都经过 macFUSE 桥接层），相比商业驱动（Paragon）或原生格式（exFAT/APFS）有一定不稳定性与额外坑点。
>
> 本文是已知问题的**权威记录**，使用前务必通读。日常同步时的「反向覆盖」警示见 [USAGE.md](USAGE.md) 与 [README.md](README.md)，本文为其完整根因与恢复说明。

---

## 0. 头号问题：第三方同步工具反向覆盖本地（已发生，已部分修复）

### 现象
用希捷 Toolkit（或 FreeFileSync 等）对本工具挂载的 NTFS 盘做 Mirror / 同步时，工具**把挂载盘判定为「源（更新的一方）」，反向把盘内容覆盖回本地 Mac**，导致本地文件被旧/错内容破坏。盘→本地是破坏性覆盖，且这类工具一般无版本历史，难以恢复。

### 根因
同步工具靠 **文件修改时间(mtime) + 大小** 判断哪边更新。ntfs-3g 在 macOS 上读写时间戳时，若与本机时区未统一，盘上文件的 mtime 会被偏移（典型为整段偏移本地时区，如中国 +8 小时），被读成「比本地新」→ 盘被误判为源 → 反向覆盖。

另一个同等常见的诱因：Mirror 任务当初**源/目标设反了**（盘=源、本地=目标），每次都单向推 盘→本地。

### 已修复项
- `mount_ntfs.command` 现在挂载前自动检测系统时区并注入 ntfs-3g（`sudo TZ="<时区>" ntfs-3g ...`），从根上消除时间戳偏移。
- `USAGE.md` / `README.md` 已加「反向覆盖风险」警示。

### 仍需注意（工具内部逻辑不在本 kit 控制内）
即使时区已统一，Toolkit 内部的比较/方向逻辑无法由本工具控制。**每次同步前必须**：
1. 先点「预览/对比」，确认方向是 **本地→盘**（本地为主）；出现 盘→本地 立即取消。
2. 把 Mirror 显式设为**单向（本地为源）**，不要开双向/自动判定。
3. 条件允许时改用按**文件内容(hash)**比较，而非 mtime。

### 恢复手段（一旦已被覆盖）
- 优先从 **Time Machine** 或本地其他备份找回被覆盖文件（Toolkit 无版本历史）。
- 若盘上那份反而是正确的旧版且本地新内容已丢：只能依赖上述外部备份，本工具无法回滚。

---

## 1. 时间戳偏移（mtime skew）
见第 0 节。统一时区后通常消失；若仍有偏差，可手动在挂载项追加 `time_offset`（分钟）校正，或改用按内容(hash)比较的同步方式，彻底绕开 mtime。

## 2. 每次插盘必须手动重新挂载
macOS 插入 NTFS 盘后会用**自带只读驱动**自动挂载。本工具不会常驻，必须每次插盘后先运行 `mount_ntfs.command` 换成 ntfs-3g 读写挂载，否则写入会报 `Read-only file system`。

## 3. 性能偏低
ntfs-3g 用户空间桥接，1GB 大文件写入约 20–30 MB/s（Paragon 约 80–100 MB/s）。定期增量同步、只传变化文件时体感尚可；整盘大文件搬运会明显慢。

## 4. 卸载必须用脚本，不能 Finder 弹出
Finder 弹出可能导致 macFUSE 进程未正常退出、下次挂载异常。务必用 `unmount_ntfs.command`，或 `sudo umount <挂载点>`。

## 5. macOS 升级可能破坏 macFUSE
macOS 大版本/小版本更新后，macFUSE 内核扩展可能失效，需同步升级 macFUSE 与 ntfs-3g 以匹配新系统。升级系统后若挂载失败，先确认两者版本是否支持当前 macOS。

## 6. 权限 / 扩展属性不被 NTFS 支持
NTFS 不存储 macOS 的 POSIX 权限与扩展属性（`com.apple.quarantine`、`FinderInfo` 等），写入时会被拒。同步命令已用 `--no-perms --no-owner --no-group` 规避；用其他工具同步时也要关闭权限/ACL/xattr 同步。

## 7. 异常断开有损坏风险
用户空间驱动对异常断电/硬拔盘更敏感，可能遗留挂载进程或轻微损坏。务必先 `unmount_ntfs.command` 再拔盘；传输大文件期间不要休眠/断电。

---

## 安全使用清单

- [ ] 插盘后先跑 `mount_ntfs.command`，确认 `mount | grep macfuse` 有输出（确为 ntfs-3g 读写挂载，而非 macOS 只读）。
- [ ] 挂载后抽查 `stat` 对比盘与本地同文件 mtime，确认无整段时区偏移。
- [ ] 同步前**先预览方向**，确认 本地→盘；设为单向、本地为源。
- [ ] 优先按文件内容(hash)比较，而非 mtime。
- [ ] 重要数据除 NTFS 盘外，另有 Time Machine 或独立介质备份（NTFS 盘只是镜像，不是唯一副本）。
- [ ] 大文件传输完成后做一次校验（如 `md5`/`shasum` 比对）。
- [ ] 拔盘前先 `unmount_ntfs.command`。

## 故障排查 / 恢复

| 现象 | 排查 / 处理 |
|------|------------|
| 本地被反向覆盖 | 见第 0 节「恢复手段」；依赖外部备份，本工具无法回滚 |
| 写入报 `Operation not permitted` | 确认走的是 ntfs-3g 而非 macOS 只读驱动（`mount \| grep macfuse`）；检查 xattr/权限同步是否已关 |
| 挂载失败 | 查 `mount \| grep macfuse`；重跑 `mount_ntfs.command`；确认 macFUSE/ntfs-3g 版本匹配当前 macOS |
| 卸载卡住 | `lsof \| grep <挂载点>` 查占用进程并关闭；必要时 `sudo umount -f <挂载点>` |
| 传输后文件损坏/大小不符 | 重新传输并 `shasum` 校验；异常断开后先卸载再重新挂载 |
| 系统升级后无法挂载 | 升级 macFUSE 与 ntfs-3g 到支持当前 macOS 的版本 |
