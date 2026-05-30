#!/bin/bash
# ============================================================
#  build.sh — 환경변수를 주입한 완성형 단일 HTML을 dist/ 에 생성
# ============================================================
set -e

mkdir -p dist

python3 - << PYEOF
import os, re

supabase_url = os.environ.get("SUPABASE_URL", "")
supabase_key = os.environ.get("SUPABASE_KEY", "")

# style.css 읽기
with open("style.css", "r", encoding="utf-8") as f:
    css = f.read()

# app.js 읽기
with open("app.js", "r", encoding="utf-8") as f:
    app_js = f.read()

# 최종 HTML 조립
html = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>몽글몽글 짝꿍 찾기</title>
  <style>
{css}
  </style>
  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/react/18.2.0/umd/react.production.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/react-dom/18.2.0/umd/react-dom.production.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/babel-standalone/7.23.2/babel.min.js"></script>
  <script>
    window.ENV = {{
      SUPABASE_URL: "{supabase_url}",
      SUPABASE_KEY: "{supabase_key}"
    }};
  </script>
</head>
<body>
  <div id="root"></div>
  <script type="text/babel">
{app_js}
  </script>
</body>
</html>"""

with open("dist/index.html", "w", encoding="utf-8") as f:
    f.write(html)

print("✅ dist/index.html built successfully")
print(f"   SUPABASE_URL: {supabase_url[:30]}...")
PYEOF

echo "✅ build complete"
