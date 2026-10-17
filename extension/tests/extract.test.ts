// @vitest-environment happy-dom
import { describe, expect, it } from 'vitest';
import saramin from './fixtures/saramin.html?raw';
import jobkorea from './fixtures/jobkorea.html?raw';
import wanted from './fixtures/wanted.html?raw';
import mismatch from './fixtures/mismatch.html?raw';
import noCompany from './fixtures/no-company.html?raw';
import { extractPosting } from '@/lib/extract';
import { readPage } from '@/lib/postingWatch';
import { DEFAULT_CONFIG } from '@/lib/siteConfig';

const parse = (html: string) => new DOMParser().parseFromString(html, 'text/html');
const site = (id: string) => DEFAULT_CONFIG.sites.find((candidate) => candidate.id === id)!;

const SARAMIN_URL =
  'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=12345678&utm_source=mail';
const JOBKOREA_URL = 'https://www.jobkorea.co.kr/Recruit/GI_Read/40000001';
const WANTED_URL = 'https://www.wanted.co.kr/wd/300001';

describe('사이트 어댑터 — 저장한 가상 공고 HTML (WEB-003 · WEB-004 · WEB-016)', () => {
  it('사람인: JSON-LD가 없으면 메타(og:title) → DOM 순으로 법인 표기 회사명을 읽는다', () => {
    const result = extractPosting(parse(saramin), site('saramin'));
    expect(result.candidates).toEqual([{ name: '가상전자(주)', source: 'meta' }]);
  });

  it('잡코리아: 구조화 데이터의 법인명을 먼저 읽는다 (WEB-006)', () => {
    const result = extractPosting(parse(jobkorea), site('jobkorea'));
    expect(result.candidates[0]).toEqual({ name: '(주)테스트랩', source: 'jsonLd' });
    expect(result.candidates).toHaveLength(1);
  });

  it('원티드: JSON-LD 배열 속 JobPosting과 CSS 모듈 클래스 회사명을 읽는다', () => {
    const result = extractPosting(parse(wanted), site('wanted'));
    expect(result.candidates).toEqual([{ name: '가상소프트', source: 'jsonLd' }]);
  });

  it('구조화 데이터와 화면 회사명이 다르면 두 후보를 순서대로 모두 보낸다 (WEB-006 검증 필요)', () => {
    const result = extractPosting(parse(mismatch), site('wanted'));
    expect(result.candidates.map((candidate) => candidate.name)).toEqual([
      '가상소프트',
      '가상소프트 클라우드',
    ]);
    expect(result.candidates.map((candidate) => candidate.source)).toEqual(['jsonLd', 'meta']);
  });

  it('공고 원문을 읽고, 없으면 null로 없음을 알린다 (WEB-011)', () => {
    expect(extractPosting(parse(saramin), site('saramin')).postingText).toContain(
      '담당업무 웹 프론트엔드 개발',
    );
    expect(extractPosting(parse(jobkorea), site('jobkorea')).postingText).toContain(
      '주요업무 React',
    );
    expect(extractPosting(parse(wanted), site('wanted')).postingText).toContain(
      '주요업무 API 서버 개발',
    );
    expect(extractPosting(parse(noCompany), site('saramin')).postingText).toBeNull();
  });
});

describe('보낼 공고 메시지', () => {
  it('공고 주소면 거른 공고 정보: 추적 쿼리 · 이메일 · 토큰은 빠진다 (SEC-002)', () => {
    const read = readPage(parse(saramin), SARAMIN_URL, DEFAULT_CONFIG);
    if (read.kind !== 'posting') throw new Error('공고로 보지 않음');
    expect(read.page.url).toBe(
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=12345678',
    );
    expect(read.page.companies).toEqual(['가상전자(주)']);
    expect(read.page.postingText).not.toContain('recruit@example.com');
    expect(JSON.stringify(read.page)).not.toContain('eyJhbGci');
  });

  it('공고 주소인데 회사명이 없으면 빈 후보로 보내 앱이 수동 카드를 띄운다 (WEB-007)', () => {
    const read = readPage(parse(noCompany), SARAMIN_URL, DEFAULT_CONFIG);
    expect(read).toMatchObject({ kind: 'posting', page: { companies: [] } });
    expect(read.kind === 'posting' && 'postingText' in read.page).toBe(false);
  });

  it('공고 주소가 아니면 내용을 읽지 않고 left', () => {
    expect(
      readPage(
        parse(saramin),
        'https://www.saramin.co.kr/zf_user/jobs/list/domestic',
        DEFAULT_CONFIG,
      ),
    ).toEqual({
      kind: 'left',
    });
    expect(readPage(parse(wanted), 'https://www.example.com/wd/1', DEFAULT_CONFIG)).toEqual({
      kind: 'left',
    });
  });

  it('세 사이트 공고를 각각 그 사이트로 보낸다', () => {
    const ids = [
      readPage(parse(saramin), SARAMIN_URL, DEFAULT_CONFIG),
      readPage(parse(jobkorea), JOBKOREA_URL, DEFAULT_CONFIG),
      readPage(parse(wanted), WANTED_URL, DEFAULT_CONFIG),
    ].map((read) => (read.kind === 'posting' ? read.page.site : null));
    expect(ids).toEqual(['saramin', 'jobkorea', 'wanted']);
  });
});
