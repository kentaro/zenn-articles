---
title: "ローカルLLMとClaudeでカメラ監視AIを作った"
emoji: "👁️"
type: "tech"
topics: ["Claude", "ClaudeCode", "ollama", "llava", "自動化"]
published: true
publication_name: pepabo
---

## はじめに

Claude Codeを使っていると、AIに自分の行動を監視させて生産性向上に役立てたいという欲求が湧いてきます。そこで、ローカルで動作するvisionモデル（llava）とClaude CLIを組み合わせて、カメラで自分を監視し、状況を日本語で記録するシステムを作りました。

## 仕組みの概要

```
カメラ (imagesnap)
    ↓ 60秒ごとに撮影
/tmp/watch.jpg
    ↓ ローカルで画像分析
ollama llava:7b (英語で正確に描写)
    ↓ 日本語に翻訳
claude -p (Claude CLI)
    ↓ 記録
Obsidian + macOS通知
    ↓ 自動git commit
GitHub同期
```

## なぜこの構成なのか

### ローカルvisionモデルの選択

最初は**moondream**（1.7GB、軽量）を試しましたが、日本語出力が不安定でした。**llava:7b**（4.7GB）に切り替えたところ、英語での描写精度が向上しました。

しかし、llavaに直接日本語で出力させると：

```
❌ 「頭部を前に持った魚のような人物が裏から吸っている煙物です」
❌ 「この画像には人類があります」
```

このような意味不明な出力になることがありました。

### 英語→日本語の2段階処理

解決策として、llavaは英語で分析させ、Claude CLIで日本語に翻訳する方式を採用しました：

```
✅ llava: "A man wearing glasses sitting at a table in a restaurant"
✅ claude -p: "眼鏡をかけた男性がレストランのテーブルに座っている"
```

これにより、安定した自然な日本語出力が得られます。

### ハルシネーション対策

visionモデルは「何をしているか」を聞くと、見えていないものを推測して答える傾向があります。例えば、何も持っていないのに「タバコを吸っている」と出力されることがありました。

プロンプトを改善して対策：

```diff
- "Describe what the person in this image is doing in one short sentence."
+ "Describe exactly what you see in this image in one sentence. Be accurate, do not assume or hallucinate."
```

## 実装

### 監視スクリプト

`~/.claude/hooks/camera-watch.sh`:

```bash
#!/bin/bash
# Camera monitoring with local LLM + Claude translation

INTERVAL=${1:-60}  # Default 60 seconds
OBSIDIAN_DIR="$HOME/src/github.com/kentaro/obsidian/claude"

notify() {
    osascript -e "display notification \"$1\" with title \"👁️ 監視AI\""
}

analyze() {
    imagesnap -q /tmp/watch.jpg 2>/dev/null

    # Get English analysis from llava (more stable than Japanese)
    english=$(/opt/homebrew/bin/ollama run llava:7b \
        "Describe exactly what you see in this image in one sentence. Be accurate, do not assume or hallucinate." \
        /tmp/watch.jpg 2>&1 | \
        sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | \
        sed 's/\[?[0-9]*[a-zA-Z]//g' | \
        tr -d '\r' | grep -v "^\[" | grep -v "^Added" | \
        tr -d '\n' | sed 's/  */ /g')

    # Translate to Japanese using Claude
    if [ -n "$english" ]; then
        result=$(echo "$english" | \
            /opt/homebrew/bin/claude -p "以下を自然な日本語に翻訳してください。一文で簡潔に。翻訳のみ出力：" 2>/dev/null | \
            tr -d '\n')
        echo "$result"
    fi
}

append_to_obsidian() {
    local timestamp="$1"
    local result="$2"
    local TODAY=$(date +%Y年%-m月%-d日)
    local OUTPUT_FILE="${OBSIDIAN_DIR}/${TODAY}.md"

    if [ ! -f "$OUTPUT_FILE" ]; then
        echo "# ${TODAY} Claudeとの会話" > "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi

    echo "**📷 監視AI** ($timestamp): $result" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    cd "$OBSIDIAN_DIR" && git add "$OUTPUT_FILE" && \
        git commit -m "Camera: ${TODAY} ${timestamp}" 2>/dev/null || true
}

echo "🎥 監視開始 (${INTERVAL}秒間隔)"
notify "監視を開始しました"

while true; do
    result=$(analyze)
    if [ -n "$result" ]; then
        timestamp=$(date +%H:%M:%S)
        echo "[$timestamp] $result"
        notify "$result"
        append_to_obsidian "$timestamp" "$result"
    fi
    sleep $INTERVAL
done
```

### LaunchAgentで常駐化

`~/Library/LaunchAgents/com.claude.camera-watch.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.camera-watch</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/YOUR_USERNAME/.claude/hooks/camera-watch.sh</string>
        <string>60</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/.claude/logs/camera-watch.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/.claude/logs/camera-watch-error.log</string>
</dict>
</plist>
```

### セットアップ

```bash
# 必要なツールをインストール
brew install imagesnap
brew install ollama

# llavaモデルをダウンロード
ollama pull llava:7b

# ログディレクトリ作成
mkdir -p ~/.claude/logs

# LaunchAgent有効化
launchctl load ~/Library/LaunchAgents/com.claude.camera-watch.plist

# 停止する場合
launchctl unload ~/Library/LaunchAgents/com.claude.camera-watch.plist
```

## 出力例

実際の監視ログ：

```
[00:35:06] 眼鏡をかけた男性がテーブルに座っている。
[00:39:43] 眼鏡とデニムジャケットを身につけた人物がレストランに座っている。
[00:40:49] 眼鏡をかけた人物がカメラに向かって微笑んでいる。
```

Obsidianには以下のように記録されます：

```markdown
# 2026年1月10日 Claudeとの会話

**📷 監視AI** (00:35:06): 眼鏡をかけた男性がテーブルに座っている。

**📷 監視AI** (00:39:43): 眼鏡とデニムジャケットを身につけた人物がレストランに座っている。
```

## コスト

- **llava**: 完全ローカル実行（無料）
- **claude -p**: API呼び出し（1回数円程度）
- 60秒間隔で1時間 = 60回 = 数十円/時間

翻訳のみなのでトークン消費は最小限です。

## 今後の改善案

- **生産性アドバイス**: 単なる描写ではなく「SNS見すぎでは？」のようなツッコミを入れる
- **行動分類**: 「集中」「休憩」「サボり」などにカテゴライズ
- **統計**: 1日の行動パターンをグラフ化
- **複数モデル対応**: より高精度なvisionモデルへの切り替え

## まとめ

ローカルLLM（llava）とClaude CLIを組み合わせることで、プライバシーを保ちながら安定した日本語出力のカメラ監視システムを構築できました。

- 画像分析: ローカル（llava）→ プライバシー安心
- 日本語翻訳: Claude CLI → 自然な日本語
- 記録: Obsidian + Git → 永続化・検索可能

Claude Codeと一緒に生産性を追求している方は、ぜひ試してみてください。
