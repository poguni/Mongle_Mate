#!/bin/bash
# ============================================================
#  build.sh — Vercel 빌드 스크립트
#  sed 대신 Python3 로 app.js 인라인 삽입 (특수문자 안전)
# ============================================================
set -e

# ── 1. dist 폴더 준비 ────────────────────────────────────
mkdir -p dist
cp style.css dist/style.css

# ── 2. env.js 생성 ───────────────────────────────────────
cat > dist/env.js << EOF
window.ENV = {
  SUPABASE_URL: "${SUPABASE_URL}",
  SUPABASE_KEY: "${SUPABASE_KEY}"
};
EOF

# ── 3. Python3 로 index.html + app.js 합치기 ─────────────
#   · <script type="text/babel" src="app.js"> 태그 제거
#   · </body> 직전에 app.js 내용을 인라인으로 삽입
python3 - << 'PYEOF'
import re

with open("index.html", "r", encoding="utf-8") as f:
    html = f.read()

with open("app.js", "r", encoding="utf-8") as f:
    app_js = f.read()

# src="app.js" 외부 스크립트 태그 제거 (한 줄 또는 여러 줄 형태 모두 대응)
html = re.sub(
    r'<script[^>]+type=["\']text/babel["\'][^>]+src=["\']app\.js["\'][^>]*>\s*</script>',
    '',
    html,
    flags=re.IGNORECASE | re.DOTALL
)

# </body> 직전에 인라인 스크립트 삽입
inline = f'\n<script type="text/babel">\n{app_js}\n</script>\n'
html = html.replace("</body>", inline + "</body>")

with open("dist/index.html", "w", encoding="utf-8") as f:
    f.write(html)

print("✅ dist/index.html generated (app.js inlined)")
PYEOF

echo "✅ build complete → dist/"
echo "   - dist/index.html (app.js inlined)"
echo "   - dist/style.css"
echo "   - dist/env.js (env vars injected)"
