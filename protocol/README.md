# 확장 ↔ 앱 메시지 규약

Chrome 확장과 채우미 앱(Native Messaging 호스트 경유)이 주고받는 JSON 메시지 예시입니다.
TypeScript(`extension/lib/protocol.ts`)와 Swift(`app/Core`) 테스트가 **같은 예시 파일**을 읽어 두 언어의 규약이 어긋나지 않게 합니다.

| 파일 | 방향 | 뜻 |
| --- | --- | --- |
| `examples/hello.json` | 확장 → 앱 | 연결 직후 인사 (확장 버전) |
| `examples/job-page.json` | 확장 → 앱 | 지정 사이트 공고 정보 (민감 정보를 걸러 낸 뒤) |
| `examples/ack.json` | 앱 → 확장 | 인사 응답 (앱 버전) |

- 메시지 하나는 JSON 객체 하나이고 `type`으로 구분합니다
- Native Messaging 규격상 한 메시지는 4바이트 길이(호스트 기준 리틀 엔디언) + UTF-8 JSON입니다
