-- ==================================================================
-- 00. 시드 데이터 삭제 (재실행용)
--
-- 시드 데이터는 전부 PK 990000 이상을 쓴다. 앱이 만드는 데이터는 identity
-- 시퀀스가 1부터 올라가므로 이 범위와 겹치지 않는다.
-- 그래서 "id >= 990000" 만으로 시드만 안전하게 지울 수 있다.
--
-- 예외: screen_time_setting 은 V13 이 GENERATED AS IDENTITY(= ALWAYS) 로
--       만들어서 id 를 지정할 수 없다. child_id 범위로 지운다.
--
-- 자식 → 부모 순서로 지운다(FK 때문).
-- ==================================================================
SET DEFINE OFF

-- 커뮤니티
DELETE FROM community_post_like            WHERE id      >= 990000;
DELETE FROM community_post_comment         WHERE id      >= 990000;
DELETE FROM community_post_attachment      WHERE post_id >= 990000;
DELETE FROM community_post_link            WHERE post_id >= 990000;
DELETE FROM admin_post_report              WHERE id      >= 990000;
DELETE FROM admin_comment_report           WHERE id      >= 990000;
DELETE FROM admin_community_member_ban     WHERE id      >= 990000;
DELETE FROM community_post                 WHERE id      >= 990000;

-- 1:1 문의 / 공지 (V9 에서 board → inquiry 로 바뀌었다)
DELETE FROM inquiry_answer                 WHERE id         >= 990000;
DELETE FROM inquiry_attachment             WHERE inquiry_id >= 990000;
DELETE FROM inquiry                        WHERE id         >= 990000;
DELETE FROM notice_attachment              WHERE notice_id  >= 990000;
DELETE FROM notice_link                    WHERE notice_id  >= 990000;
DELETE FROM notice                         WHERE id         >= 990000;

-- 알림
DELETE FROM notification_setting_toggle    WHERE notification_setting_id >= 990000;
DELETE FROM notification_setting           WHERE id      >= 990000;
DELETE FROM notification                   WHERE id      >= 990000;
DELETE FROM device_token                   WHERE id      >= 990000;

-- 모니터링 / 기기
DELETE FROM app_usage                      WHERE id      >= 990000;
DELETE FROM screenshot                     WHERE id      >= 990000;
DELETE FROM device_event                   WHERE id      >= 990000;

-- 유해차단 / 앱통제
DELETE FROM block_rule                     WHERE id      >= 990000;
DELETE FROM harmful_keyword                WHERE id      >= 990000;
DELETE FROM installed_app                  WHERE id      >= 990000;
DELETE FROM app_control_rule               WHERE id      >= 990000;
DELETE FROM screen_time_setting            WHERE child_id BETWEEN 990200 AND 990299;

-- 위치
DELETE FROM place_event                    WHERE id      >= 990000;
DELETE FROM place                          WHERE id      >= 990000;
DELETE FROM track_segment                  WHERE id      >= 990000;
DELETE FROM tracking_setting               WHERE id      >= 990000;

-- 결제 / 지갑
DELETE FROM qr_payment                     WHERE id      >= 990000;
DELETE FROM store_terminal                 WHERE id      >= 990000;
DELETE FROM wallet_transaction             WHERE id      >= 990000;
DELETE FROM pg_webhook_event               WHERE id      >= 990000;
DELETE FROM charge_order                   WHERE id      >= 990000;
DELETE FROM card                           WHERE id      >= 990000;
DELETE FROM wallet                         WHERE id      >= 990000;

-- 페어링 / 감사로그 / 인증
DELETE FROM pairing_code                   WHERE id        >= 990000;
DELETE FROM admin_audit_log                WHERE id        >= 990000;
DELETE FROM email_verification             WHERE id        >= 990000;
DELETE FROM refresh_token                  WHERE member_id >= 990000;

-- 회원 (자녀 → 부모 순서, parent_id 자기참조 FK)
DELETE FROM member                         WHERE id BETWEEN 990200 AND 990299;
DELETE FROM member                         WHERE id >= 990000;

COMMIT;
