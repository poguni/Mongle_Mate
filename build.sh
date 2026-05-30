#!/bin/bash
# ============================================================
#  build.sh — Vercel 빌드 시 env.js 자동 생성
#  Vercel 대시보드 > Settings > Environment Variables 에서
#  SUPABASE_URL, SUPABASE_KEY 두 값을 등록해 두면
#  빌드할 때마다 이 스크립트가 env.js 를 만들어 줍니다.
# ============================================================

echo "window.ENV = {
  SUPABASE_URL: \"${SUPABASE_URL}\",
  SUPABASE_KEY: \"${SUPABASE_KEY}\"
};" > env.js

echo "✅ env.js generated"
