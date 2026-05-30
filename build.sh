#!/bin/bash
# ============================================================
#  build.sh — Vercel 빌드 스크립트
#  1) env.js 생성 (환경변수 주입)
#  2) app.js 내용을 index.html 안에 인라인으로 삽입한
#     dist/index.html 을 최종 배포 파일로 만든다
# ============================================================
set -e   # 에러 발생 시 즉시 중단

# ── 1. dist 폴더 준비 ────────────────────────────────────
mkdir -p dist
cp style.css dist/style.css

# ── 2. app.js 내용 읽기 ──────────────────────────────────
APP_JS=$(cat app.js)

# ── 3. index.html 의 <script type="text/babel" src="app.js">
#       를 인라인 스크립트 블록으로 교체하여 dist/index.html 생성
# sed 로 해당 태그 한 줄을 제거하고, </body> 직전에 인라인 삽입 ──
sed '/<script[^>]*text\/babel[^>]*src="app\.js"[^>]*>/d' index.html \
  | sed "s|</body>|<script type=\"text/babel\">\n${APP_JS}\n</script>\n</body>|" \
  > dist/index.html

# ── 4. env.js 는 dist/ 에 생성 (index.html 이 참조) ──────
cat > dist/env.js << EOF
window.ENV = {
  SUPABASE_URL: "${SUPABASE_URL}",
  SUPABASE_KEY: "${SUPABASE_KEY}"
};
EOF

echo "✅ build complete → dist/"
echo "   - dist/index.html (app.js inlined)"
echo "   - dist/style.css"
echo "   - dist/env.js (env vars injected)"
