-- ============================================================
--  몽글몽글 짝꿍 찾기 — Supabase DB 설계
--  Supabase SQL Editor에 전체 복사 후 실행하세요.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 0. 확장 모듈 (uuid 생성용, 기본 활성화 되어 있으나 명시)
-- ────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ────────────────────────────────────────────────────────────
-- 1. users 테이블
--    Supabase Auth(auth.users)와 1:1 연결
--    아이디(username), 이메일은 Auth에서 가져오고
--    여기서는 추가 프로필 정보를 저장
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username    TEXT        NOT NULL UNIQUE,          -- 아이디 (표시용)
  email       TEXT        NOT NULL UNIQUE,          -- 이메일
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.users              IS '앱 사용자 프로필 (Supabase Auth와 1:1 연결)';
COMMENT ON COLUMN public.users.id          IS 'auth.users.id 와 동일한 UUID';
COMMENT ON COLUMN public.users.username    IS '로그인 시 표시되는 아이디';
COMMENT ON COLUMN public.users.email       IS '로그인에 사용하는 이메일';


-- ────────────────────────────────────────────────────────────
-- 2. classes 테이블 — 학년·반 정보
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.classes (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  grade       SMALLINT    NOT NULL CHECK (grade BETWEEN 1 AND 6),   -- 학년 (1~6)
  class_num   SMALLINT    NOT NULL CHECK (class_num BETWEEN 1 AND 20), -- 반
  label       TEXT,                                                  -- 예: "5학년 3반" 별칭
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, grade, class_num)   -- 같은 선생님이 동일 학년·반 중복 등록 방지
);

COMMENT ON TABLE  public.classes           IS '선생님이 담당하는 학년-반';
COMMENT ON COLUMN public.classes.grade     IS '학년 (1~6)';
COMMENT ON COLUMN public.classes.class_num IS '반 번호';


-- ────────────────────────────────────────────────────────────
-- 3. classrooms 테이블 — 교실 배치 구조
--    (몇 행 × 몇 열인지, 줄/모둠 구분)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.classrooms (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id     UUID        NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  section_type TEXT        NOT NULL CHECK (section_type IN ('row', 'group')), -- 줄/모둠
  rows         SMALLINT    NOT NULL CHECK (rows BETWEEN 1 AND 20),
  cols         SMALLINT    NOT NULL CHECK (cols BETWEEN 1 AND 20),
  label        TEXT,                                                -- 예: "기본 교실", "모둠 교실"
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (class_id, section_type)  -- 학급당 줄/모둠 배치 각 1개
);

COMMENT ON TABLE  public.classrooms              IS '교실 책상 배치 구조 (행×열)';
COMMENT ON COLUMN public.classrooms.section_type IS 'row=줄로앉기, group=모둠으로앉기';
COMMENT ON COLUMN public.classrooms.rows         IS '행 수 (앞뒤)';
COMMENT ON COLUMN public.classrooms.cols         IS '열 수 (좌우)';


-- ────────────────────────────────────────────────────────────
-- 4. students 테이블 — 학생 명단
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.students (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id    UUID        NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL,
  gender      TEXT        NOT NULL CHECK (gender IN ('남', '여')),
  number      SMALLINT,                   -- 출석 번호 (선택)
  avatar      TEXT,                       -- 이모지 아바타 (선택)
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE,  -- 전학 등 비활성화 처리
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.students          IS '학급 학생 명단';
COMMENT ON COLUMN public.students.gender   IS '남 또는 여';
COMMENT ON COLUMN public.students.number   IS '출석 번호';
COMMENT ON COLUMN public.students.avatar   IS '프론트에서 사용하는 이모지';
COMMENT ON COLUMN public.students.is_active IS '재적 여부 (false=전학/제적)';


-- ────────────────────────────────────────────────────────────
-- 5. seat_histories 테이블 — 히스토리 목록
--    배치를 저장할 때마다 1건씩 생성
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.seat_histories (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  classroom_id UUID        NOT NULL REFERENCES public.classrooms(id) ON DELETE CASCADE,
  label        TEXT,                                -- 예: "2025-04-16 배치"
  mode         TEXT        NOT NULL,               -- 배치 방식: random / number / friend / group / ladder / teacher
  memo         TEXT,                               -- 선생님 메모
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.seat_histories        IS '자리 배치 히스토리 목록';
COMMENT ON COLUMN public.seat_histories.mode   IS '배치 방식 (random, number, friend, group, ladder, teacher)';
COMMENT ON COLUMN public.seat_histories.label  IS '저장 시 자동 생성되는 날짜 레이블';


-- ────────────────────────────────────────────────────────────
-- 6. seat_assignments 테이블 — 히스토리별 개별 좌석 배치
--    history 1건 = student N개의 (행, 열) 좌석 정보
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.seat_assignments (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  history_id  UUID        NOT NULL REFERENCES public.seat_histories(id) ON DELETE CASCADE,
  student_id  UUID        NOT NULL REFERENCES public.students(id)       ON DELETE CASCADE,
  seat_row    SMALLINT    NOT NULL,   -- 0-based 행 인덱스
  seat_col    SMALLINT    NOT NULL,   -- 0-based 열 인덱스
  is_locked   BOOLEAN     NOT NULL DEFAULT FALSE,  -- 고정석 여부
  has_desk    BOOLEAN     NOT NULL DEFAULT TRUE,   -- 책상 존재 여부
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (history_id, seat_row, seat_col),         -- 같은 히스토리에서 좌석 중복 방지
  UNIQUE (history_id, student_id)                  -- 같은 히스토리에서 학생 중복 방지
);

COMMENT ON TABLE  public.seat_assignments            IS '히스토리별 학생 좌석 배치 상세';
COMMENT ON COLUMN public.seat_assignments.seat_row   IS '행 인덱스 (0부터 시작)';
COMMENT ON COLUMN public.seat_assignments.seat_col   IS '열 인덱스 (0부터 시작)';
COMMENT ON COLUMN public.seat_assignments.is_locked  IS '고정석 여부 (true=이동 불가)';
COMMENT ON COLUMN public.seat_assignments.has_desk   IS '해당 위치에 책상 존재 여부';


-- ============================================================
--  RLS (Row Level Security) 설정
--  모든 테이블: 자기 데이터만 읽기·쓰기 가능
-- ============================================================

-- RLS 활성화
ALTER TABLE public.users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classrooms       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seat_histories   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seat_assignments ENABLE ROW LEVEL SECURITY;


-- ────────────────────────────────────────────────────────────
-- users 정책
-- ────────────────────────────────────────────────────────────
CREATE POLICY "users: 본인 조회"  ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "users: 본인 등록"  ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "users: 본인 수정"  ON public.users
  FOR UPDATE USING (auth.uid() = id);


-- ────────────────────────────────────────────────────────────
-- classes 정책
-- ────────────────────────────────────────────────────────────
CREATE POLICY "classes: 본인 조회" ON public.classes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "classes: 본인 등록" ON public.classes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "classes: 본인 수정" ON public.classes
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "classes: 본인 삭제" ON public.classes
  FOR DELETE USING (auth.uid() = user_id);


-- ────────────────────────────────────────────────────────────
-- classrooms 정책 (수정됨: classroom -> classrooms)
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "classrooms: 본인 조회" ON public.classrooms;
CREATE POLICY "classrooms: 본인 조회" ON public.classrooms
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id = public.classrooms.class_id AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "classrooms: 본인 등록" ON public.classrooms;
CREATE POLICY "classrooms: 본인 등록" ON public.classrooms
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id = class_id AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "classrooms: 본인 수정" ON public.classrooms;
CREATE POLICY "classrooms: 본인 수정" ON public.classrooms
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id = public.classrooms.class_id AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "classrooms: 본인 삭제" ON public.classrooms;
CREATE POLICY "classrooms: 본인 삭제" ON public.classrooms
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id = public.classrooms.class_id AND c.user_id = auth.uid()
    )
  );


-- ────────────────────────────────────────────────────────────
-- students 정책
-- ────────────────────────────────────────────────────────────
CREATE POLICY "students: 본인 조회" ON public.students
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id = students.class_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "students: 본인 등록" ON public.students
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id = class_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "students: 본인 수정" ON public.students
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id = students.class_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "students: 본인 삭제" ON public.students
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id = students.class_id AND c.user_id = auth.uid()
    )
  );


-- ────────────────────────────────────────────────────────────
-- seat_histories 정책
-- ────────────────────────────────────────────────────────────
CREATE POLICY "seat_histories: 본인 조회" ON public.seat_histories
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.classrooms cr
      JOIN public.classes c ON c.id = cr.class_id
      WHERE cr.id = seat_histories.classroom_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "seat_histories: 본인 등록" ON public.seat_histories
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.classrooms cr
      JOIN public.classes c ON c.id = cr.class_id
      WHERE cr.id = classroom_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "seat_histories: 본인 수정" ON public.seat_histories
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.classrooms cr
      JOIN public.classes c ON c.id = cr.class_id
      WHERE cr.id = seat_histories.classroom_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "seat_histories: 본인 삭제" ON public.seat_histories
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.classrooms cr
      JOIN public.classes c ON c.id = cr.class_id
      WHERE cr.id = seat_histories.classroom_id AND c.user_id = auth.uid()
    )
  );


-- ────────────────────────────────────────────────────────────
-- seat_assignments 정책
-- ────────────────────────────────────────────────────────────
CREATE POLICY "seat_assignments: 본인 조회" ON public.seat_assignments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.seat_histories sh
      JOIN public.classrooms cr ON cr.id = sh.classroom_id
      JOIN public.classes c     ON c.id  = cr.class_id
      WHERE sh.id = seat_assignments.history_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "seat_assignments: 본인 등록" ON public.seat_assignments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.seat_histories sh
      JOIN public.classrooms cr ON cr.id = sh.classroom_id
      JOIN public.classes c     ON c.id  = cr.class_id
      WHERE sh.id = history_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "seat_assignments: 본인 수정" ON public.seat_assignments
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.seat_histories sh
      JOIN public.classrooms cr ON cr.id = sh.classroom_id
      JOIN public.classes c     ON c.id  = cr.class_id
      WHERE sh.id = seat_assignments.history_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "seat_assignments: 본인 삭제" ON public.seat_assignments
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.seat_histories sh
      JOIN public.classrooms cr ON cr.id = sh.classroom_id
      JOIN public.classes c     ON c.id  = cr.class_id
      WHERE sh.id = seat_assignments.history_id AND c.user_id = auth.uid()
    )
  );


-- ============================================================
--  Auth Trigger: 회원가입 시 users 테이블 자동 생성
--  Supabase Auth로 가입하면 public.users에 자동 삽입됩니다.
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.users (id, username, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
--  인덱스 (조회 성능 최적화)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_classes_user_id          ON public.classes(user_id);
CREATE INDEX IF NOT EXISTS idx_classrooms_class_id      ON public.classrooms(class_id);
CREATE INDEX IF NOT EXISTS idx_students_class_id        ON public.students(class_id);
CREATE INDEX IF NOT EXISTS idx_seat_histories_classroom ON public.seat_histories(classroom_id);
CREATE INDEX IF NOT EXISTS idx_seat_assignments_history ON public.seat_assignments(history_id);
CREATE INDEX IF NOT EXISTS idx_seat_assignments_student ON public.seat_assignments(student_id);


-- ============================================================
--  완료 확인 메시지
-- ============================================================
DO $$ BEGIN
  RAISE NOTICE '✅ 몽글몽글 짝꿍 찾기 DB 설계 완료!';
  RAISE NOTICE '   테이블: users, classes, classrooms, students, seat_histories, seat_assignments';
  RAISE NOTICE '   RLS: 모든 테이블 활성화 및 본인 데이터만 접근 가능';
  RAISE NOTICE '   트리거: 회원가입 시 users 테이블 자동 생성';
END $$;
