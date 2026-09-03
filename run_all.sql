-- ==================================================================
-- 시드 데이터 일괄 적용 (sqlplus 전용)
--
--   sqlplus -S 계정/비밀번호@//호스트:1521/서비스명 @run_all.sql
--
-- 00_cleanup 이 먼저 돌기 때문에 몇 번을 실행해도 결과가 같다(멱등).
-- 도중에 오류가 나면 그 자리에서 멈추고 롤백한 뒤 종료한다.
--
-- ⚠️ 파일 순서를 바꾸지 말 것. FK 와 논리 참조가 이 순서를 전제로 한다.
--    (회원 → 지갑 → 결제 → 위치/모니터링 → 커뮤니티/문의 → 알림)
-- ==================================================================
SET DEFINE OFF
SET ECHO OFF
SET FEEDBACK OFF   -- INSERT 2595건마다 "1 row created" 가 찍히면 로그만 길어진다
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == 00. 기존 시드 삭제 ==
@@00_cleanup.sql
PROMPT == 01. 회원 ==
@@01_member.sql
PROMPT == 02. 지갑/충전/웹훅 ==
@@02_wallet.sql
PROMPT == 03. QR 결제 ==
@@03_qrpay.sql
PROMPT == 04. 위치 ==
@@04_location.sql
PROMPT == 05. 모니터링 ==
@@05_monitoring.sql
PROMPT == 06. 유해차단/앱통제 ==
@@06_filtering_appcontrol.sql
PROMPT == 07. 커뮤니티 ==
@@07_community.sql
PROMPT == 08. 문의/공지 ==
@@08_inquiry_notice.sql
PROMPT == 09. 알림 ==
@@09_notification.sql
PROMPT == 10. 페어링/감사로그/이메일인증 ==
@@10_pairing_audit.sql

PROMPT
PROMPT == 적용 결과 ==
@@99_verify.sql

PROMPT
PROMPT 시드 적용 완료.
EXIT
