#!/usr/bin/env python3
"""Notionの日報ページにMarkdownコンテンツを書き込む"""
import os
import sys
import json
import urllib.request
import urllib.error

NOTION_TOKEN = os.environ.get("NOTION_TOKEN", "")
NOTION_API_VERSION = "2022-06-28"


def parse_markdown_to_blocks(markdown: str) -> list:
    """簡易MarkdownをNotionブロックに変換する"""
    blocks = []
    for line in markdown.split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("### "):
            blocks.append({
                "object": "block",
                "type": "heading_3",
                "heading_3": {
                    "rich_text": [{"type": "text", "text": {"content": stripped[4:]}}]
                },
            })
        elif stripped.startswith("## "):
            blocks.append({
                "object": "block",
                "type": "heading_2",
                "heading_2": {
                    "rich_text": [{"type": "text", "text": {"content": stripped[3:]}}]
                },
            })
        elif stripped.startswith("# "):
            blocks.append({
                "object": "block",
                "type": "heading_1",
                "heading_1": {
                    "rich_text": [{"type": "text", "text": {"content": stripped[2:]}}]
                },
            })
        elif stripped.startswith("- "):
            blocks.append({
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {
                    "rich_text": [{"type": "text", "text": {"content": stripped[2:]}}]
                },
            })
        else:
            blocks.append({
                "object": "block",
                "type": "paragraph",
                "paragraph": {
                    "rich_text": [{"type": "text", "text": {"content": stripped}}]
                },
            })
    return blocks


def get_existing_blocks(page_id: str) -> list:
    """ページの既存ブロックIDを取得する"""
    req = urllib.request.Request(
        f"https://api.notion.com/v1/blocks/{page_id}/children?page_size=100",
        headers={
            "Authorization": f"Bearer {NOTION_TOKEN}",
            "Notion-Version": NOTION_API_VERSION,
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req) as res:
            data = json.loads(res.read())
        return data.get("results", [])
    except urllib.error.HTTPError:
        return []


def delete_block(block_id: str):
    """ブロックを削除する"""
    req = urllib.request.Request(
        f"https://api.notion.com/v1/blocks/{block_id}",
        headers={
            "Authorization": f"Bearer {NOTION_TOKEN}",
            "Notion-Version": NOTION_API_VERSION,
        },
        method="DELETE",
    )
    urllib.request.urlopen(req)


def append_blocks(page_id: str, blocks: list):
    """ページにブロックを追加する(100件ずつ)"""
    for i in range(0, len(blocks), 100):
        chunk = blocks[i : i + 100]
        payload = json.dumps({"children": chunk}).encode()
        req = urllib.request.Request(
            f"https://api.notion.com/v1/blocks/{page_id}/children",
            data=payload,
            headers={
                "Authorization": f"Bearer {NOTION_TOKEN}",
                "Notion-Version": NOTION_API_VERSION,
                "Content-Type": "application/json",
            },
            method="PATCH",
        )
        urllib.request.urlopen(req)


def main():
    if not NOTION_TOKEN:
        print("ERROR: NOTION_TOKEN not set", file=sys.stderr)
        sys.exit(1)

    if len(sys.argv) < 2:
        print("Usage: write_daily.py <page_url_or_id> [--replace]", file=sys.stderr)
        print("  Reads markdown from stdin", file=sys.stderr)
        sys.exit(1)

    raw_id = sys.argv[1]
    replace = "--replace" in sys.argv

    # URLからIDを抽出
    page_id = raw_id.split("/")[-1].split("?")[0].replace("-", "")
    if len(page_id) == 32:
        page_id = f"{page_id[:8]}-{page_id[8:12]}-{page_id[12:16]}-{page_id[16:20]}-{page_id[20:]}"

    markdown = sys.stdin.read().strip()
    if not markdown:
        print("ERROR: No content provided via stdin", file=sys.stderr)
        sys.exit(1)

    blocks = parse_markdown_to_blocks(markdown)

    if replace:
        existing = get_existing_blocks(page_id)
        for block in existing:
            try:
                delete_block(block["id"])
            except urllib.error.HTTPError:
                pass

    try:
        append_blocks(page_id, blocks)
        print(f"OK: {len(blocks)} blocks written")
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ""
        print(f"ERROR: Notion API error {e.code}: {body}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
