# 앱 테스트용 시드 데이터

운영 Oracle 에 기능별 더미 데이터를 넣는 스크립트다. SQL 2,595건 + 채팅(Mongo) 207건.
현재 마이그레이션(V1 ~ V15) 이 적용된 스키마를 기준으로 작성했다.

## 실행

```bash
# 파일을 운영 WAS 인스턴스로 옮긴 뒤 (SSM 세션 안에서)
export NLS_LANG=KOREAN_KOREA.AL32UTF8      # 한글이 ??? 로 들어가는 것 방지
cd seed
sqlplus -S 계정/비밀번호@//호스트:1521/서비스명 @run_all.sql
```

파일 여러 개를 옮기기 번거로우면 **`seed_all_in_one.sql` 하나만** 가져가도 된다.
`00`~`10` 을 그대로 이어 붙인 것이라 내용은 같다.

```bash
sqlplus -S 계정/비밀번호@//호스트:1521/서비스명 @seed_all_in_one.sql
```

- `run_all.sql` 이 `00_cleanup.sql` 부터 순서대로 다 돌린다.
- **몇 번을 실행해도 결과가 같다.** 맨 앞에서 시드(PK 990000 이상)를 지우고 다시 넣는다.
- 도중에 오류가 나면 그 자리에서 멈추고 롤백한다(`WHENEVER SQLERROR`).
- 특정 도메인만 다시 넣고 싶으면 그 파일만 실행해도 된다.
  단, 앞 단계(회원·지갑)가 이미 들어가 있어야 한다.
- 지우기만 하려면 `@00_cleanup.sql`, 건수·정합성을 보려면 `@99_verify.sql`.
- 적용 **전에** `@98_precheck.sql` 로 990000 대가 비어 있는지, Flyway 가 V15 까지
  올라와 있는지 확인할 수 있다(읽기 전용).

파일은 전부 **UTF-8, BOM 없음**이다. `NLS_LANG` 을 지정하지 않으면 한글이 깨져 들어간다.

### 필요한 마이그레이션

이 시드는 **V15 까지 적용된 스키마**를 전제로 한다.

| 마이그레이션 | 없으면 |
| --- | --- |
| `V14__notification_type_chat_screentime` | `09_notification.sql` 의 `CHAT_MESSAGE` / `SCREEN_TIME_LIMIT` 알림이 `ORA-02290` 으로 막힌다 |
| `V15__wallet_transaction_memo` | `02_wallet.sql` 의 `wallet_transaction.memo` 컬럼이 없어 `ORA-00904` 로 막힌다 |

`98_precheck.sql` 마지막 쿼리가 `flyway_schema_history` 를 찍어 준다.

## 파일 구성

| 파일 | 내용 | 건수 |
| --- | --- | --- |
| `00_cleanup.sql` | 시드 삭제 (재실행용) | - |
| `01_member.sql` | 관리자 4 / 부모 45 / 자녀 45 | 94 |
| `02_wallet.sql` | 지갑 90, 원장 231, 충전주문 68, PG웹훅 60 | 449 |
| `03_qrpay.sql` | 매장단말 60, QR결제 72 | 132 |
| `04_location.sql` | 등록공간 62, 출입이벤트 68, 동선 72, 추적설정 45 | 247 |
| `05_monitoring.sql` | 앱사용량 70, 스크린샷 68, 단말이벤트 66 | 204 |
| `06_filtering_appcontrol.sql` | 유해키워드 60, 차단규칙 62, 설치앱 68, 앱통제 66, 스크린타임 45 | 301 |
| `07_community.sql` | 게시글 60, 댓글 72, 좋아요 60, 신고 45+45, 정지 45 (+첨부 12/링크 10) | 349 |
| `08_inquiry_notice.sql` | 문의 60, 답변 45, 공지 60 (+첨부 24/링크 10) | 199 |
| `09_notification.sql` | 알림 113, 알림설정 90, 토글 191, 기기토큰 91 | 485 |
| `10_pairing_audit.sql` | 페어링코드 45, 감사로그 60, 이메일인증 30 | 135 |
| `98_precheck.sql` | 적용 전 안전 점검 (읽기 전용) | - |
| `99_verify.sql` | 건수 + 지갑 정합성 + 부모-자녀 연결 점검 | - |
| `seed_all_in_one.sql` | 위 `00`~`10` 을 이어 붙인 단일 파일 | 2,595 |
| `chat_seed.mongo.js` | 채팅방 45, 메시지 162 (MongoDB) | 207 |

SQL 합계 2,595건.

## 부모-자녀 연결 규칙

이 시드의 가장 중요한 불변식이다. **회원만 있고 딸린 데이터가 없는 계정을 만들지 않는다.**

- 부모 45명 · 자녀 45명 **전원**이 지갑 / 원장 / 알림설정 / 기기토큰 / 알림을 갖는다.
- 자녀 45명 **전원**이 추적설정 / 등록공간 / 출입이벤트 / 동선 / 앱사용량 / 스크린샷 /
  단말이벤트 / 차단규칙 / 설치앱 / 앱통제 / 스크린타임 / QR결제 / 채팅방을 갖는다.
- 자녀가 있는 부모 42명 **전원**이 자기 자녀에게 용돈을 이체한 이력이 있다
  (`TRANSFER_OUT` ↔ `TRANSFER_IN` 이 반드시 짝을 이룬다).
- 지갑 잔액은 **원장에서 역산**한다. 마지막 `balance_after` 와 `wallet.balance` 가 항상 같고,
  중간에 잔액이 음수가 되는 구간이 없다.
- `place_event.place_id` 는 같은 자녀의 공간만 가리킨다.
  `ARRIVED` 는 `DESTINATION` 공간에만, `ENTER`/`EXIT` 는 `GEOFENCE` 공간에만 붙는다.
- `app_control_rule` 은 그 자녀의 `installed_app` 에 있는 패키지만 통제한다.
- `notification.child_id` 는 수신자의 자녀만 가리킨다. 자녀 본인이 받는 알림은 `NULL` 이다.
- `qr_payment` 의 `PAID`/`CANCELLED` 는 `PAYMENT`/`PAYMENT_CANCEL` 원장과 1:1,
  `charge_order` 의 `PAID`/`REFUNDED` 는 `CHARGE` 원장과 1:1 이다.

`99_verify.sql` 의 마지막 블록이 위 항목을 전부 센다. **전부 0 이어야 정상이다.**

> 이전 버전(838건)에서는 지갑 90개 중 3개에만 원장이 있었고, 부모-자녀 20쌍 중 18쌍은
> 지갑 흐름이 끊겨 있었다. 자녀 45명은 알림 설정이 아예 없었다. 이번에 전부 메웠다.

## 테스트 계정

비밀번호는 **전부 `Test1234!`** (서비스가 비밀번호를 평문 비교한다).

| 구분 | 로그인 ID | 비고 |
| --- | --- | --- |
| 슈퍼관리자 | `superadmin` | 관리자 화면 전체 |
| 일반관리자 | `genadmin` | 자금/회원 |
| 커뮤니티관리자 | `commadmin` | 신고·정지 |
| 문의관리자 | `inqadmin` | 1:1 문의 답변 |
| 부모 | `parent01` ~ `parent45` | 데이터는 `parent01` 에 몰려 있다 |
| 자녀 | `child01` ~ `child45` | 데이터는 `child01` 에 몰려 있다 |

부모-자녀 매핑

- `parent01` → `child01`, `child02`, `child03` (다자녀 3명)
- `parent21` → `child21`, `child22` (다자녀 2명)
- `parent02` → `child04` … `parent18` → `child20` (1:1, 17쌍)
- `parent22` → `child23` … `parent44` → `child45` (1:1, 23쌍)
- `parent19`, `parent20`, `parent45` → 자녀 없음 (빈 목록 확인용)

`child01` 이외의 자녀도 화면이 비지 않는다. 다만 건수가 1~3건으로 얕다.
목록 페이징·정렬을 보려면 `parent01` / `child01` 을 쓰는 편이 낫다.

## 어디를 보면 데이터가 보이나

| 화면 | 계정 | 기대 |
| --- | --- | --- |
| 자녀 목록 / 대시보드 | parent01 | 자녀 3명, 등록공간 16, 최근 알림 20건 |
| 지갑 내역 | parent01 | 원장 25건 (충전·이체·환불·조정) |
| 충전 내역 | parent01 | 24건 (PAID 11 / REFUNDED 1 / CANCELLED 4 / FAILED 4 / EXPIRED 3 / READY 1) |
| 자녀 지갑 / 결제 내역 | child01 | 원장 25건, QR 결제 25건 |
| 위치 동선 | child01 | 최근 100분, 5분 간격 20건 |
| 앱 사용량 | child01 | 최근 6일 20건 |
| 스크린샷 | child01 | 20건 (SCHEDULED 14 / MANUAL 6) |
| 앱 통제 | child01 | 설치앱 20, 통제규칙 20 |
| 유해 차단 | child01 | 차단규칙 14 (전역 키워드 60) |
| 커뮤니티 | 아무 부모 | 글 60, 댓글 72, 좋아요 60 |
| 마이페이지 활동내역 | parent01 | 글 5 / 댓글 8 / 좋아요 10 |
| 1:1 문의 | parent01 | 본인 문의 5건 (전체 60, 답변완료 45) |
| 공지사항 | 아무 계정 | 60건 |
| 알림 | parent01 | 20건 (안 읽음 8) |
| 채팅 | parent01 | 자녀 3명과 각각 방, room01 은 안 읽음 있음 |
| 관리자 고객관리 | superadmin | PARENT+CHILD 90명 |
| 관리자 자금 통계 | superadmin | 일자별/매장별 집계 (매장 60곳) |
| 관리자 신고 관리 | commadmin | 게시글 45, 댓글 45, 정지 45 (활성 12) |
| 관리자 감사로그 | superadmin | 60건 |

## 시간이 지나면 다시 넣어야 하는 것

배치가 오래된 데이터를 지우거나 상태를 바꾼다. 아래는 **해당 파일만 다시 실행**하면 된다.

| 데이터 | 배치 | 다시 실행할 파일 |
| --- | --- | --- |
| 동선(track_segment) | 매일 03시, 3일 경과분 삭제 | `04_location.sql` |
| 앱 사용량(app_usage) | 매일 04시, 7일 경과분 삭제 | `05_monitoring.sql` |
| QR 결제대기 3건 | 발급 후 5/10/30분에 만료 | `03_qrpay.sql` |
| 충전주문 READY 1건 | 10분마다, 30분 경과분 EXPIRED | `02_wallet.sql` |

페어링 코드는 실제 TTL 이 5분이지만, 테스트 중에 사라지지 않도록 만료를 미래(+1~45일)로 잡아 뒀다.
`PairingCodeCleanupScheduler` 가 만료된 코드를 1분마다 지우기 때문이다.

## SQL 로 넣지 않은 것

- **카드(`card`)** — 카드번호·비밀번호앞2자리·생년월일·소유자명이
  `EncryptedStringConverter`(AES-256-GCM)로 암호화 저장된다. 키가 앱 안에 있어
  SQL 로는 올바른 암호문을 만들 수 없다. `POST /api/wallet/cards` 로 등록할 것.
- **채팅** — Mongo(DocumentDB)에 있다. `chat_seed.mongo.js` 를 mongosh 로 실행한다.
  ```bash
  mongosh "mongodb://<user>:<pw>@<host>:27017/kidhack_chat?tls=true&tlsCAFile=/opt/certs/global-bundle.pem&retryWrites=false" --file chat_seed.mongo.js
  ```
- **탈퇴 회원** — `WithdrawnMemberCleanupScheduler` 가 탈퇴 후 10분 지난 계정을
  물리 삭제한다. 넣어 두면 곧 사라지거나 FK 때문에 삭제가 실패해 에러 로그만 쌓인다.
  탈퇴 흐름은 API 로 확인할 것.
- **리프레시 토큰** — 로그인할 때 발급되므로 미리 넣을 이유가 없다.

## 기존 마이그레이션과의 관계

이 폴더는 **Flyway 와 무관하다.**

- `seed/` 는 프로젝트 루트에 있어 클래스패스(`classpath:db/migration`) 밖이다.
  Flyway 가 스캔하지 않고, jar 에도 들어가지 않는다.
- 파일명이 `V*`/`R*`/`U*` 규칙에 걸리지 않는다.
- **DDL 이 한 줄도 없다.** 순수 INSERT/DELETE 라 스키마도, `flyway_schema_history`
  의 체크섬도 건드리지 않는다.
- `00_cleanup.sql` 의 DELETE 는 전부 990000 대 한정이라 기존 데이터를 지우지 않는다.

즉 `V1__init.sql` 부터 `V15__wallet_transaction_memo.sql` 까지가 만들어 놓은 스키마
위에 데이터만 얹는다. 스키마를 바꿔야 하면 시드가 아니라 V16 을 새로 추가해야 한다.

## ID 규칙

시드는 전부 **PK 990000 이상**을 쓴다. 앱이 만드는 데이터는 identity 시퀀스가
1부터 올라가므로 이 범위와 겹치지 않고, 그래서 `id >= 990000` 만으로 시드만
정확히 지울 수 있다.

- 회원: 관리자 `990001~990004`, 부모 `990101~990145`, 자녀 `990201~990245`
- 그 외 테이블: `990001` 부터 순서대로

예외가 하나 있다. **`screen_time_setting`** 은 V13 이 `GENERATED AS IDENTITY`
(= `GENERATED ALWAYS`)로 만들어서 id 를 직접 지정하면 `ORA-32795` 가 난다.
그래서 이 테이블만 id 없이 INSERT 하고, 삭제도 `child_id BETWEEN 990200 AND 990299`
로 한다.

## 데이터 생성 방식

이 SQL 들은 손으로 쓴 것이 아니라 **파이썬 생성기가 찍어 낸 결과물**이다.
잔액·이체 짝·QR 토큰·주문 상태처럼 서로 맞물리는 값을 손으로 관리하면 반드시 어긋나서다.

- 생성기는 저장소에 두지 않는다(일회성 도구). 값을 바꿔야 하면 SQL 을 직접 고치면 된다.
- 대신 **결과물을 검증하는 쪽을 `99_verify.sql` 에 남겼다.** 손으로 고친 뒤에도
  같은 검사를 돌릴 수 있다.
