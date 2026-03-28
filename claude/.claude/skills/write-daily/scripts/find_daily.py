#!/usr/bin/env python3
"""今日の日報NotionページURLを返す"""
import os
import sys
from datetime import datetime, timezone, timedelta
import urllib.request
import urllib.error
import json

NOTION_TOKEN = os.environ.get("NOTION_TOKEN", "")
DWM_DATABASE_ID = os.environ.get("NOTION_DWM_DATABASE_ID", "")
NOTION_API_VERSION = "2022-06-28"

def main():
    if not NOTION_TOKEN:
        print("ERROR: NOTION_TOKEN not set", file=sys.stderr)
        sys.exit(1)

    if not DWM_DATABASE_ID:
        print("ERROR: DWM_DATABASE_ID not set", file=sys.stderr)
        sys.exit(1)

    jst = timezone(timedelta(hours=9))
    today = datetime.now(jst).strftime("%Y-%m-%d")
    tomorrow = (datetime.now(jst) + timedelta(days=1)).strftime("%Y-%m-%d")

    payload = json.dumps({
        "filter": {
            "and": [
                {
                    "property": "Date",
                    "date": {"equals": today}
                },
                {
                    "property": "Period",
                    "select": {"equals": "Dialy"}
                }
            ]
        }
    }).encode()

    req = urllib.request.Request(
        f"https://api.notion.com/v1/databases/{DWM_DATABASE_ID}/query",
        data=payload,
        headers={
            "Authorization": f"Bearer {NOTION_TOKEN}",
            "Notion-Version": NOTION_API_VERSION,
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req) as res:
            data = json.loads(res.read())
    except urllib.error.HTTPError as e:
        print(f"ERROR: Notion API error {e.code}", file=sys.stderr)
        sys.exit(1)

    results = data.get("results", [])
    if not results:
        print(f"NOT_FOUND: {today}", file=sys.stderr)
        sys.exit(1)

    page_id = results[0]["id"]
    url = f"https://www.notion.so/{page_id.replace('-', '')}"
    print(url)

if __name__ == "__main__":
    main()
