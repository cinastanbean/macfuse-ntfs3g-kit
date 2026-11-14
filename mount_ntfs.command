#!/bin/bash
# ============================================================
# NTFS 读写挂载脚本（通用版）
# 自动识别所有 NTFS 外接盘，逐个读写挂载
# 双击 .command 文件即可运行
# ============================================================

NTFS_BIN="/opt/homebrew/bin/ntfs-3g"

clear

echo "========================================="
echo "   NTFS 读写挂载"
echo "========================================="
echo ""

# ============================================================
# 时区统一（关键）
# ntfs-3g 在 macOS 上读写文件时间戳(mtime)时，若与本机时区不一致，
# 盘上文件的修改时间会被偏移（典型为整段偏移本地时区，如中国 +8 小时）。
# 第三方同步工具（希捷 Toolkit / FreeFileSync 等）靠 mtime 判断哪边"更新"，
# 一旦盘上文件被读成"比本地新"，就会把盘误判为源，反向 盘→本地 覆盖，
# 造成本地文件被旧/错内容破坏。注入系统时区可尽量消除该偏移。
# ============================================================
TZ_NAME=$(sudo systemsetup -gettimezone 2>/dev/null | sed 's/^Time Zone: //')
if [ -n "$TZ_NAME" ]; then
    echo "系统时区: $TZ_NAME（已注入 ntfs-3g，统一时间戳）"
else
    TZ_NAME="$(date +%Z)"
    echo "系统时区(回退): $TZ_NAME（已注入 ntfs-3g，统一时间戳）"
fi

# 查找所有 NTFS 外接硬盘 (兼容 Windows_NTFS 和 Microsoft Basic Data 两种标签)
FOUND=0
while IFS= read -r line; do
    DEV_ID=$(echo "$line" | awk '{print $NF}')
    DISK_NAME=$(diskutil info "$DEV_ID" 2>/dev/null | grep "Volume Name" | sed 's/.*Volume Name:[[:space:]]*//')
    DEV_PATH="/dev/$DEV_ID"
    MOUNT_POINT="/Volumes/$DISK_NAME"

    echo "发现: $DISK_NAME ($DEV_PATH)"
    
    # 卸载已有的只读挂载 (macOS 自动挂载的，或之前的残留)
    echo "  卸载现有挂载..."
    sudo diskutil unmount "$DEV_PATH" 2>/dev/null || sudo diskutil unmount force "$DEV_PATH" 2>/dev/null || true

    # 读写挂载
    echo "  读写挂载中 -> $MOUNT_POINT ..."
    sudo mkdir -p "$MOUNT_POINT"
    NTFS_ERR=$(sudo TZ="$TZ_NAME" "$NTFS_BIN" "$DEV_PATH" "$MOUNT_POINT" -o allow_other,auto_xattr,local 2>&1)
    NTFS_RC=$?

    sleep 1
    if mount | grep "$MOUNT_POINT" | grep -q macfuse; then
        echo "  挂载成功"
        FOUND=$((FOUND + 1))
    else
        echo "  挂载失败"
        [ -n "$NTFS_ERR" ] && echo "  错误信息: $NTFS_ERR"
    fi
    echo ""
done < <(diskutil list 2>/dev/null | grep -E "Windows_NTFS|Microsoft Basic Data")

if [ $FOUND -eq 0 ]; then
    echo "未找到任何 NTFS 外接硬盘，请确认磁盘已接入"
fi

echo ""
read -p "按回车键退出..."
echo "窗口将在 3 秒后自动关闭..."
sleep 3
osascript -e 'tell app "Terminal" to close front window' 2>/dev/null &
