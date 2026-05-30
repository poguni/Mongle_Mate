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
# 핵심: Babel은 <head>에서 먼저 로드 → <body> 파싱 완료 후
#       Babel이 <script type="text/babel"> 을 자동으로 찾아 변환·실행
html = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>몽글몽글 짝꿍 찾기</title>
  <style>
{css}
  </style>

  <!-- 1) 환경변수 (가장 먼저) -->
  <script>
    window.ENV = {{
      SUPABASE_URL: "{supabase_url}",
      SUPABASE_KEY: "{supabase_key}"
    }};
  </script>

  <!-- 2) 외부 라이브러리 -->
  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/react/18.2.0/umd/react.production.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/react-dom/18.2.0/umd/react-dom.production.min.js"></script>

  <!-- 3) Babel standalone: data-presets 로 최신 preset 명시 -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/babel-standalone/7.23.2/babel.min.js"></script>
</head>
<body>
  <div id="root"></div>

  <!-- 4) 앱 코드: Babel이 head에서 로드된 뒤 이 블록을 변환·실행 -->
  <script type="text/babel" data-presets="react">
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
