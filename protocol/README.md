# 확장 ↔ 앱 메시지 규약

Chrome 확장과 채우미 앱(Native Messaging 호스트 경유)이 주고받는 JSON 메시지 예시입니다.
TypeScript(`extension/lib/protocol.ts`)와 Swift(`app/Core`) 테스트가 **같은 예시 파일**을 읽어 두 언어의 규약이 어긋나지 않게 합니다.

| 파일 | 방향 | 뜻 |
| --- | --- | --- |
| `examples/hello.json` | 확장 → 앱 | 연결 직후 인사 (확장 버전). 확장이 스스로 다시 연결할 때는 `"quiet": true` → 호스트가 꺼진 앱을 실행하지 않는다 |
| `examples/job-page.json` | 확장 → 앱 | 지정 사이트 공고: 회사명 후보(구조화 데이터 → 메타 → DOM 순, 비면 추출 실패) · 제목 · 공고 원문(없으면 필드 없음). 민감 정보를 걸러 낸 뒤 |
| `examples/page-left.json` | 확장 → 앱 | 공고가 아닌 페이지 · 다른 탭으로 옮김 (이전 회사 결과 지우기) |
| `examples/apply-button.json` | 확장 → 앱 | 지원 버튼이 화면 오른쪽 아래 카드 자리를 가리는지 (바뀔 때만) |
| `examples/apply-complete.json` | 확장 → 앱 | 지원 완료 화면 감지 (HIS-017): 가장 최근 공고의 사이트 · 주소 · 회사명 후보 · 제목. 앱이 5초 카운트다운 뒤 기록을 요청한다 |
| `examples/rescan.json` | 앱 → 확장 | 지금 보고 있는 탭을 다시 읽어 달라 (카드의 "지원 이력 확인" 버튼). 콘텐츠 스크립트가 응답하지 않으면 확장이 그 탭에 다시 넣는다 |
| `examples/rescan-reload.json` | 앱 → 확장 | 다시 읽어도 회사명이 없을 때 지금 탭을 새로고침 (지정 사이트 탭만) |
| `examples/ack.json` | 앱 → 확장 | 인사 응답 (앱 버전) |
| `sites.default.json` | 앱 → 확장 (`{"type":"siteConfig","config":…}`) | 지원 사이트 설정 기본값 (WEB-014). 앱은 `~/Library/Application Support/ChaeWooMi/sites.json`을 쓰고, 없으면 이 값으로 만든다 |

- 메시지 하나는 JSON 객체 하나이고 `type`으로 구분합니다
- Native Messaging 규격상 한 메시지는 4바이트 길이(호스트 기준 리틀 엔디언) + UTF-8 JSON입니다

## 지원 사이트 설정 (`sites.default.json`)

| 항목 | 뜻 |
| --- | --- |
| `domains` | 이 도메인과 하위 도메인에서만 동작 |
| `postingPatterns` | `경로 + 쿼리`에 맞춰 보는 정규식. 맞으면 공고 페이지 |
| `company.jsonLd` → `company.meta` → `company.selectors` | 회사명을 읽는 순서 (구조화 데이터의 법인명 우선) |
| `postingText` | 공고 원문을 읽는 곳 (`frames`는 같은 사이트 iframe) |
| `applyButtons` | 지원 버튼 (카드가 가리면 런처로 접음) |
| `completePatterns` | 지원 완료 화면 주소 (`경로 + 쿼리` 정규식) |
| `completeTexts` | 지원 완료 화면 문구. 보이는 글자에 들어 있으면 완료 화면 (공백 무시, `script` · `style` 안 글자는 보지 않음) |

- 정규식은 Swift `NSRegularExpression`과 JavaScript `RegExp`가 같이 읽는 기본 문법만 씁니다
- Core 앱 번들의 `app/Core/Sources/ChaeWooMiCore/Sites/Resources/sites.default.json`은 이 파일의 복사본이고, 두 파일이 같은지 Swift 테스트가 검사합니다
