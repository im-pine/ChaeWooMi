# 가상 공고 HTML

2026-10-17 사람인 · 잡코리아 · 원티드 공개 공고 페이지의 **구조**(JSON-LD · 메타 · 회사명 · 본문 위치)만 본떠 만든 HTML입니다.
회사 · 공고 내용은 모두 가상이며 실제 페이지 내용을 복사하지 않았습니다.

| 파일              | 본뜬 구조                                                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `saramin.html`    | `view-ajax`로 불러온 본문: `.jv_header .title_inner a.company`, `.basic_info .company_name`, `og:title` `[회사] 제목`, JSON-LD 없음  |
| `jobkorea.html`   | `JobPosting` JSON-LD `hiringOrganization.name`(법인 표기), `og:title` `회사 채용 - 제목`, `#details-section`                         |
| `wanted.html`     | `JobPosting` JSON-LD(법인 표기 없음), CSS 모듈 클래스(`JobHeader__Tools__Company__Link`, `CompanyInfo__name`), 본문 `JobDescription` |
| `mismatch.html`   | 원티드 구조에서 구조화 데이터와 화면 회사명이 다른 경우                                                                              |
| `no-company.html` | 사람인 공고 주소인데 회사명 위치가 없는 경우 (추출 실패)                                                                             |
