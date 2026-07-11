#!/bin/bash
# 服务器监控脚本 — 定时采集指标并上报
# 依赖: curl jq
# 用法: chmod +x start.sh && ./start.sh

set -e

# === 配置 ===
INTERVAL=60          # 采集间隔(秒)
WEBHOOK_URL=""       # 通知地址 (Telegram/DingTalk)
NOTIFY_TYPE="echo"   # echo | telegram | dingtalk

# === 采集 ===
collect() {
  local cpu mem disk
  cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
  mem=$(free -m | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
  disk=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

  cat <<JSON
{"cpu":$cpu,"memory":$mem,"disk":$disk,"time":"$(date -Iseconds)"}
JSON
}

# === 通知 ===
notify() {
  local data=$1
  case $NOTIFY_TYPE in
    telegram)
      [ -n "$WEBHOOK_URL" ] && curl -s -X POST "$WEBHOOK_URL" -d "{\"text\":\"$data\"}" -H "Content-Type: application/json"
      ;;
    dingtalk)
      [ -n "$WEBHOOK_URL" ] && curl -s -X POST "$WEBHOOK_URL" -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"$data\"}}" -H "Content-Type: application/json"
      ;;
    *)
      echo "$data"
      ;;
  esac
}

# === 主循环 ===
echo "监控脚本启动，间隔: ${INTERVAL}s"
while true; do
  data=$(collect)
  notify "$data"
  sleep "$INTERVAL"
done
