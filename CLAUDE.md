# ChaeWooMi (채우미)

## 작업 원칙
- 코딩 전에 가정을 밝히고, 해석이 여러 가지거나 불분명하면 묻는다. 더 단순한 방법이 있으면 말한다
- 요청한 것만 만든다. 한 번 쓰는 코드에 추상화 · 설정 · 확장성을 넣지 않는다
- 바꿀 것만 바꾼다. 바뀐 모든 줄은 요청으로 거슬러 올라가야 한다. 관련 없는 코드는 고치지 말고 알린다
- 함수 · 컴포넌트 하나는 한 가지 일만 한다. 조회 · 계산 · 저장 · 표시를 섞지 않는다
- 목표를 확인 가능한 검사(테스트 · 빌드 · 스크린샷)로 바꾸고, 통과할 때까지 스스로 확인한다
- "됐다"고 말하지 말고 실행한 명령과 결과를 보인다. 확인 못 한 것은 확인 못 했다고 쓴다
- 오류를 숨기거나 검사를 끄지 말고 근본 원인을 고친다
- 커밋 · 푸시 · 배포 · 데이터 삭제는 요청받았을 때만. 일은 PR 생성까지 (리뷰 · 머지는 리뷰봇, main은 사람)
- 보고는 한국어로, 사실과 판단 필요를 구분하고 판단이 필요한 것만 묻는다. 판단은 작업 중에 묻고 끝낸 뒤 PR을 만든다 (PR에 판단 질문을 남기지 않는다)
- 데이터 구조 · 외부 약속(URL · API) · 기획 · 보안/개인정보 · 돈 · 설계 방향 · 큰 범위 · 지침 충돌에 걸리는 결정은 구현 전에 묻고, PR에 `(사용자 결정: …)`으로 남긴다
- 테스트 · UX · PR 작성은 각 지침 문서를 따른다 (아래 "지침 문서")

## 명령
- Core 테스트: `swift test --package-path app/Core`
- 앱 프로젝트 생성 · 빌드: `cd app && xcodegen generate && xcodebuild -project ChaeWooMi.xcodeproj -scheme ChaeWooMi -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- 확장: `pnpm install` 후 `pnpm typecheck` · `pnpm lint` · `pnpm format` · `pnpm test` · `pnpm --filter chaewoomi-extension build`
- Swift 린트: `swiftlint` (저장소 루트)

## 구조와 경계
- `app/ChaeWooMi` 앱(SwiftUI + AppKit) · `app/Host` Native Messaging 호스트 · `app/Core` 판정 로직 Swift 패키지 · `extension` Chrome 확장(WXT)
- `app/Core`는 UI를 import하지 않는다 (SwiftUI · AppKit 금지). 판정 로직은 여기에 두고 테스트한다
- 확장과 앱은 Native Messaging 메시지로만 주고받는다. 서로의 코드를 참조하지 않는다

## 함정
- `app/ChaeWooMi.xcodeproj`와 `app/ChaeWooMi/Info.plist`는 생성물이다. **`app/project.yml`을 고치고** `xcodegen generate`로 다시 만든다
- Swift 6 언어 모드(엄격한 동시성 검사)다. 경고를 끄지 말고 고친다
- WXT 0.21 · Vite 8 API는 학습 데이터와 다를 수 있다. 확장 코드를 쓰기 전에 WXT 문서를 확인한다
- 세션 연동은 Claude Code **세션 간 메시지**(중계 세션 `claude -p` + `SendMessage`)다. Channels를 쓰지 않는다
- 채우미가 직접 쓰는 볼트 파일은 모달에서 편집 중인 초안 Markdown뿐이다. 12.0 · 공고 · Career DB 파일은 세션 요청으로만 바뀐다
- 실제 지원 기록 · 회사명 · 개인정보를 코드 · 테스트 · 커밋에 넣지 않는다 (공개 저장소). 테스트 데이터는 가상의 회사로 만든다

## 지침 문서
- 개발 공통 · 브랜치 · 커밋 · PR: `~/Documents/Brain_of_Pine/50 Development/50.0 Development 관리/50.0.1 개발 공통 원칙.md`
- UX: `50.0.2 UX 공통 원칙.md` · 테스트: `50.0.5 테스팅 원칙.md` (같은 폴더)
- PR 본문: `~/Documents/Brain_of_Pine/50 Development/50.1 Review Bot/50.1.2 PR 작성 지침.md`
- 요구사항 · 기능명세 · 기술 스택: `~/Documents/Brain_of_Pine/10 Career/10.0 SideProject/10.0.7 ChaeWooMi/`
