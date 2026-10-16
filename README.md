# ChaeWooMi (채우미)

> 채용공고를 열면 그 회사에 **1년 안에 지원했는지** 바로 알려 주고, 이력서 · 자기소개서 작성은 **이미 열어 둔 Claude Code 세션**에 맡기는 macOS 플로팅 앱입니다.

> 🚧 **개발 전** — 기획 · 디자인 · 기술 검증을 마치고 개발 환경을 세팅한 단계입니다. 아래 기능은 v1 목표입니다.

## 🚀 Project Overview

채용 플랫폼이 여러 곳이라 지원 이력이 흩어지고, 한 회사가 같은 공고를 여러 플랫폼에 올리기 때문에 같은 회사에 1년 안에 다시 지원하는 실수가 생깁니다. 지원 기록을 메일에서 모아 정리하는 일도 반복됩니다.

채우미는 개인 지식 볼트(Obsidian)의 지원 현황 문서를 읽어, 지금 보고 있는 공고의 회사가 **재지원 주의** 대상인지 플랫폼과 상관없이 회사명으로 판별합니다. 공고 분석 · 이력서 · 자기소개서는 이미 역할별로 열어 둔 Claude Code 세션에 요청하고, 사용자는 초안을 검토 · 수정 · 승인만 합니다. 앱은 별도 DB 없이 볼트 파일을 기준으로 상태를 계산합니다.

## 🔗 결과물

- [Figma 디자인](https://www.figma.com/design/SpgiYJtfH7M43NYAjScXI7)
- [FigJam 사용자 · 시스템 플로우](https://www.figma.com/board/dX4iTL91bLhw1wFU42lLVt)

## ✨ 주요 기능 (v1 목표)

- 지정 사이트(사람인 · 잡코리아 · 원티드) 공고에 들어가면 앱이 자동으로 실행되고 플로팅 카드 표시
- 회사명(정규화 + 별칭)으로 1년 이내 지원 여부를 판별해 `재지원 주의` 표시
- 공고 분석 · 이력서 · 자기소개서를 역할별 Claude Code 세션에 요청 (한 번에 문서 하나)
- 세션이 만든 Markdown 초안을 직접 편집하거나 수정 요청 → 승인하면 PDF 생성
- 지원 완료 화면을 감지하면 5초 뒤 지원 현황에 기록 (취소 가능)
- 지정 외 사이트에서는 표시하지 않고, Dock 아이콘 우클릭으로만 수동 활성화

## 🛠 Core Stack

| 영역 | 기술 | 선택 이유 |
| --- | --- | --- |
| macOS 앱 | Swift 6 · SwiftUI + AppKit (macOS 14+) | 비활성 플로팅 패널 · 메뉴바 · Dock 메뉴 · 파일 감시를 모두 Apple 기본 API로 구현 |
| 판정 로직 | Swift Package (`ChaeWooMiCore`) | UI와 분리해 회사명 · 재지원 판정을 테스트로 검증 |
| 세션 연동 | Claude Code 세션 간 메시지 (`claude -p` 중계 세션 + `SendMessage`) | 이미 열린 세션에 플래그 없이 요청 · 회신 |
| 브라우저 확장 | Chrome MV3 · TypeScript · WXT | 지정 도메인에만 권한, 페이지 이벤트 기반 감지 |
| 확장 ↔ 앱 | Chrome Native Messaging | 공식 통로, 확장이 연결하면 Chrome이 호스트를 실행해 앱 자동 실행 |
| 프로젝트 생성 | XcodeGen | Xcode 프로젝트를 텍스트(`project.yml`)로 관리해 리뷰 · 병렬 작업 충돌 방지 |
| 테스트 | Swift Testing · Vitest | 판정 로직 · 확장 로직 단위 테스트 |
| 품질 · CI | SwiftLint · ESLint · Prettier · GitHub Actions | 함수 길이 · 복잡도 신호, PR마다 자동 검사 |

## 🧠 Technical Highlights

### 회사명 기준 재지원 판별

한 회사가 같은 공고를 여러 플랫폼에 여러 번 올리기 때문에 공고 ID · URL로 판별하면 중복을 놓칩니다. 법인 표기(`(주)` · `주식회사` 등)를 정규화하고 지원 현황 문서의 별칭 열과 대조해 회사 단위로만 판별합니다. 판별에 실패하면 "라벨 없음"과 구분되는 `조회 불가` 상태를 보여 안전한 것처럼 보이지 않게 합니다.

### DB 없이 볼트 파일로 상태 계산

지원 기록 · 공고 분석 · 초안 · PDF가 이미 볼트의 정해진 위치에 저장되므로, 앱은 별도 저장소 없이 그 파일들을 읽고 변경을 감지(FSEvents)해 아이콘 상태를 계산합니다. 세션을 직접 써서 만든 결과도 그대로 반영됩니다.

### 열린 세션에 요청하는 리모컨

앱이 직접 AI를 호출하지 않고, 사용자가 역할별로 열어 둔 세션(공고 분석 · 이력서 · 자기소개서)에 요청만 전달합니다. 앱이 띄운 중계 세션이 Claude Code 세션 간 메시지로 요청을 보내고 회신 · 작업 종료 알림을 받습니다. 개발 전 검증에서 요청부터 회신까지 약 15초, 요청 문구는 그대로 전달됐습니다.

## 📁 프로젝트 구조

```text
.
├── app/
│   ├── project.yml        # XcodeGen 설정 (Xcode 프로젝트는 생성물)
│   ├── ChaeWooMi/         # macOS 앱 (SwiftUI + AppKit)
│   ├── Host/              # Chrome Native Messaging 호스트 (앱 번들에 포함)
│   └── Core/              # 판정 로직 Swift 패키지 + 테스트
├── extension/             # Chrome 확장 (WXT · TypeScript)
└── .github/               # CI · PR 템플릿
```

## 🔄 주요 동작 흐름

```text
지정 사이트 공고 진입
    ↓  Chrome 확장 → Native Messaging → 채우미 실행
회사명 정규화 · 별칭 대조 → 지원 현황 조회
    ↓
재지원 주의 표시 · 볼트 파일로 아이콘 상태 계산
    ↓  아이콘 클릭
중계 세션 → 세션 간 메시지 → 역할 세션이 초안 작성
    ↓
초안 검토 · 수정 → 승인 → 세션이 PDF 생성
```

## ⚙️ Getting Started

### Requirements

- macOS 14 이상, Xcode 16 이상
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), [SwiftLint](https://github.com/realm/SwiftLint)
- Node.js 22 이상, pnpm 10
- Google Chrome
- Claude Code (세션 간 메시지 지원 버전 v2.1.224 이상)

### Installation

```bash
git clone https://github.com/im-pine/ChaeWooMi.git
cd ChaeWooMi
brew install xcodegen swiftlint
pnpm install
```

### macOS 앱

```bash
cd app
xcodegen generate
open ChaeWooMi.xcodeproj
```

### Chrome 확장

```bash
pnpm --filter chaewoomi-extension dev     # 개발 모드
pnpm --filter chaewoomi-extension build   # extension/.output/chrome-mv3
```

`chrome://extensions` → 개발자 모드 → **압축해제된 확장 프로그램 로드**로 `extension/.output/chrome-mv3` 폴더를 불러옵니다.

### Test

```bash
swift test --package-path app/Core
pnpm test
```

## 📜 Scripts

| Command | Description |
| --- | --- |
| `pnpm typecheck` | 확장 TypeScript 타입 검사 |
| `pnpm lint` | ESLint |
| `pnpm format` | Prettier 검사 |
| `pnpm test` | Vitest |
| `swift test --package-path app/Core` | Core 테스트 |
| `swiftlint` | Swift 린트 |

## 📐 Development Guide

- 브랜치: `main`(배포) ← `dev`(통합) ← `<feat|fix|docs>/<영역>-<기능>`, squash merge
- 커밋 · PR 제목: `<gitmoji> <type>(<scope>): <요약>` (예: `✨ feat(core): 회사명 정규화 추가`)
- PR 본문은 `.github/pull_request_template.md`의 What · Scope · Review · Test · How to test를 채웁니다
- 테스트는 기능과 같은 PR에 넣습니다
