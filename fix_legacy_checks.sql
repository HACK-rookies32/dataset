-- ==================================================================
-- 마이그레이션이 남긴 구버전 CHECK 제약(SYS_C%) 정리
--
--   sqlplus -S 계정@//호스트:1521/ORCL @fix_legacy_checks.sql
--
-- 배경
--   CK_* 라는 이름으로 넓혀진 CHECK 제약을 추가하면서, 그 이전에
--   인라인으로 걸려 있던 익명 제약(SYS_C######)을 드롭하지 않아
--   두 제약이 동시에 살아 있다. CHECK 는 전부 통과해야 하므로
--   좁은 쪽(구버전)이 INSERT 를 막는다. → ORA-02290
--
-- 이 스크립트가 지우는 것
--   - constraint_type = 'C'
--   - 이름이 SYS_C 로 시작 (익명 = 마이그레이션 이전 잔재)
--   - 조건식에 IS NOT NULL 이 없음 (NOT NULL 제약은 절대 건드리지 않음)
--   - 같은 테이블에 이름 있는 CHECK 제약(CK_*)이 존재  ← 대체제가 있을 때만
--
-- 마지막 조건 때문에, 대체제가 없는 정상 익명 CHECK 는 남는다.
-- ==================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200

PROMPT
PROMPT ===== 삭제 대상 미리보기 =====
COLUMN table_name      FORMAT A28
COLUMN constraint_name FORMAT A16
COLUMN cond            FORMAT A110

SELECT uc.table_name,
       uc.constraint_name,
       uc.search_condition_vc AS cond
FROM   user_constraints uc
WHERE  uc.constraint_type = 'C'
AND    uc.constraint_name LIKE 'SYS\_C%' ESCAPE '\'
AND    NVL(UPPER(uc.search_condition_vc), 'X') NOT LIKE '%IS NOT NULL%'
AND    EXISTS (SELECT 1
               FROM   user_constraints ck
               WHERE  ck.table_name      = uc.table_name
               AND    ck.constraint_type = 'C'
               AND    ck.constraint_name NOT LIKE 'SYS\_C%' ESCAPE '\')
ORDER  BY uc.table_name, uc.constraint_name;

PROMPT
PROMPT ===== 삭제 실행 =====
DECLARE
  v_cnt PLS_INTEGER := 0;
BEGIN
  FOR c IN (
    SELECT uc.table_name, uc.constraint_name
    FROM   user_constraints uc
    WHERE  uc.constraint_type = 'C'
    AND    uc.constraint_name LIKE 'SYS\_C%' ESCAPE '\'
    AND    NVL(UPPER(uc.search_condition_vc), 'X') NOT LIKE '%IS NOT NULL%'
    AND    EXISTS (SELECT 1
                   FROM   user_constraints ck
                   WHERE  ck.table_name      = uc.table_name
                   AND    ck.constraint_type = 'C'
                   AND    ck.constraint_name NOT LIKE 'SYS\_C%' ESCAPE '\')
  ) LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE "'||c.table_name||'" DROP CONSTRAINT "'||c.constraint_name||'"';
    DBMS_OUTPUT.PUT_LINE('dropped  '||RPAD(c.table_name, 28)||c.constraint_name);
    v_cnt := v_cnt + 1;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('--- 총 '||v_cnt||' 건 삭제 ---');
END;
/

PROMPT
PROMPT ===== 남은 익명 CHECK (NOT NULL 제외) =====
SELECT table_name, constraint_name, search_condition_vc AS cond
FROM   user_constraints
WHERE  constraint_type = 'C'
AND    constraint_name LIKE 'SYS\_C%' ESCAPE '\'
AND    NVL(UPPER(search_condition_vc), 'X') NOT LIKE '%IS NOT NULL%'
ORDER  BY table_name;

EXIT;
