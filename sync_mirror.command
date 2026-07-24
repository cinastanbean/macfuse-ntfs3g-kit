#!/bin/bash
# ============================================================
# Mirror 目录同步脚本 (rsync 增量版，适配 NTFS)
# 将电脑本地 Mirror 同步到外接 NTFS 移动硬盘
# 双击 .command 文件即可运行
# ============================================================

# ---- 配置区域（按你的实际情况修改） ----
SRC="/path/to/your/local/mirror"
DST="/Volumes/<你的NTFS硬盘名>/<目标目录>"
# ----------------------------------------

RSYNC="/opt/anaconda3/bin/rsync"
DST_VOL=$(echo "$DST" | cut -d'/' -f3)

clear

echo "========================================="
echo "   Mirror 增量同步"
echo "========================================="
echo ""

echo "检查目标硬盘是否已挂载..."
if ! mount | grep -q "/Volumes/$DST_VOL"; then
    echo ""
    echo "目标硬盘未挂载，请先插入硬盘并运行 mount_ntfs.command"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

echo "检查读写权限..."
if ! touch "$DST/.write_test" 2>/dev/null; then
    echo ""
    echo "目标硬盘为只读模式，请先运行 mount_ntfs.command 重新挂载"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi
rm -f "$DST/.write_test"

echo "源目录: $SRC"
echo "目标目录: $DST"

SRC_SIZE=$(du -sh "$SRC" 2>/dev/null | cut -f1)
SRC_FILES=$(find "$SRC" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "源文件: ${SRC_FILES} 个, 总大小约 ${SRC_SIZE}"
echo ""

echo "分析差异..."
CHANGED=$("$RSYNC" -an --no-perms --no-owner --no-group --no-times --delete \
    --exclude '.DS_Store' --exclude '__pycache__/' --exclude '*.pyc' \
    --exclude '.pytest_cache/' --exclude 'node_modules/' --exclude '.codebuddy/' \
    --exclude '*.log' --exclude '.svn/' --exclude '.git/' \
    "$SRC"/ "$DST"/ 2>/dev/null | grep -v "^sending\|^sent\|^total\|^$" | wc -l | tr -d ' ')
echo "需要同步: ${CHANGED} 个变更"
echo ""

echo "开始同步..."
echo "----------------------------------------"

"$RSYNC" -av --no-perms --no-owner --no-group --no-times --delete \
    --progress \
    --exclude '.DS_Store' --exclude '__pycache__/' --exclude '*.pyc' \
    --exclude '.pytest_cache/' --exclude 'node_modules/' --exclude '.codebuddy/' \
    --exclude '*.log' --exclude '.svn/' --exclude '.git/' \
    "$SRC"/ "$DST"/

EXIT_CODE=$?

echo "----------------------------------------"

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "同步完成，无报错！"
else
    echo ""
    echo "同步完成，但有些错误 (退出码: $EXIT_CODE)"
fi

echo "   源: $SRC"
echo "   目标: $DST"

echo ""
read -p "按回车键退出..."
echo "窗口将在 3 秒后自动关闭..."
sleep 3
osascript -e 'tell app "Terminal" to close front window' 2>/dev/null &
