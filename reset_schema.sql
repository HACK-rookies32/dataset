-- ==================================================================
-- 스키마 완전 초기화 (Flyway V1 재적용용)
--
--   sqlplus -S 계정@//호스트:1521/ORCL @reset_schema.sql
--
-- ⚠️ 이 스크립트는 현재 접속 계정의 모든 오브젝트를 삭제한다.
--    되돌릴 수 없다. 실행 전 RDS 수동 스냅샷 필수.
--    실행 전 애플리케이션(kidhack)을 반드시 중지할 것.
--
-- 배경
--   V1__init 이 중간에 실패해 flyway_schema_history 에 success=0 으로
--   남았다. Flyway 12 는 기동 시 validate 에서 이를 감지하고 예외를
--   던지므로 V2~V15 가 영원히 적용되지 않는다.
--   반쯤 만들어진 오브젝트와 이력을 모두 지워 V1 부터 다시 태운다.
-- ==================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200

PROMPT
PROMPT ===== 삭제 전 현황 =====
SELECT object_type, COUNT(*) AS cnt
FROM   user_objects
GROUP  BY object_type
ORDER  BY object_type;

PROMPT
PROMPT ===== 삭제 실행 =====
DECLARE
  v_cnt PLS_INTEGER := 0;
  PROCEDURE drop_it(p_sql VARCHAR2, p_label VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE('dropped  '||p_label);
    v_cnt := v_cnt + 1;
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SKIP     '||p_label||'  ('||SQLERRM||')');
  END;
BEGIN
  -- 1) 머티리얼라이즈드 뷰 (컨테이너 테이블보다 먼저)
  FOR o IN (SELECT mview_name n FROM user_mviews) LOOP
    drop_it('DROP MATERIALIZED VIEW "'||o.n||'"', 'MVIEW '||o.n);
  END LOOP;

  -- 2) 뷰
  FOR o IN (SELECT view_name n FROM user_views) LOOP
    drop_it('DROP VIEW "'||o.n||'"', 'VIEW '||o.n);
  END LOOP;

  -- 3) 테이블 (FK/인덱스/트리거/제약 동반 삭제, 휴지통 경유 안 함)
  FOR o IN (SELECT table_name n FROM user_tables
            WHERE nested = 'NO' AND secondary = 'N') LOOP
    drop_it('DROP TABLE "'||o.n||'" CASCADE CONSTRAINTS PURGE', 'TABLE '||o.n);
  END LOOP;

  -- 4) 시퀀스
  FOR o IN (SELECT sequence_name n FROM user_sequences) LOOP
    drop_it('DROP SEQUENCE "'||o.n||'"', 'SEQUENCE '||o.n);
  END LOOP;

  -- 5) 프로시저/함수/패키지/시노님/트리거
  FOR o IN (SELECT object_name n, object_type t FROM user_objects
            WHERE object_type IN ('PROCEDURE','FUNCTION','PACKAGE','SYNONYM','TRIGGER')) LOOP
    drop_it('DROP '||o.t||' "'||o.n||'"', o.t||' '||o.n);
  END LOOP;

  -- 6) 타입 (의존관계 때문에 FORCE)
  FOR o IN (SELECT type_name n FROM user_types) LOOP
    drop_it('DROP TYPE "'||o.n||'" FORCE', 'TYPE '||o.n);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('--- 총 '||v_cnt||' 개 삭제 ---');
END;
/

PURGE RECYCLEBIN;

PROMPT
PROMPT ===== 삭제 후 잔여 (아무것도 없어야 정상) =====
SELECT object_type, COUNT(*) AS cnt
FROM   user_objects
GROUP  BY object_type
ORDER  BY object_type;

PROMPT
PROMPT ===== flyway_schema_history 확인 (0 이어야 정상) =====
SELECT COUNT(*) AS flyway_left
FROM   user_tables
WHERE  LOWER(table_name) = 'flyway_schema_history';

EXIT;
