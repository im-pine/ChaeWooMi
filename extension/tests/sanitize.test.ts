import { describe, expect, it } from 'vitest';
import { redactSensitive, sanitizeJobPage, sanitizeUrl } from '@/lib/sanitize';
import type { JobPageMessage } from '@/lib/protocol';

describe('민감 글자 · 주소 거르기 (SEC-002)', () => {
  it('공고 식별 쿼리만 남기고 토큰 · 추적 쿼리 · 해시 · 계정 정보를 지운다', () => {
    const url =
      'https://user:pw@www.saramin.co.kr/zf_user/jobs/view?rec_idx=123&token=abc&utm_source=x#apply';
    expect(sanitizeUrl(url)).toBe('https://www.saramin.co.kr/zf_user/jobs/view?rec_idx=123');
  });

  it('JWT · 이메일 · 휴대전화 · 긴 키 모양을 가린다', () => {
    const text =
      '가상전자 eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl tester@example.com 010-1234-5678 ' +
      'a'.repeat(40);
    expect(redactSensitive(text)).toBe('가상전자 [제외] [제외] [제외] [제외]');
  });

  it('회사명 같은 보통 글자는 그대로 둔다', () => {
    expect(redactSensitive('(주)테스트랩 2026 채용')).toBe('(주)테스트랩 2026 채용');
  });
});

describe('공고 메시지 거르기 (SEC-002)', () => {
  it('정해진 필드만 옮겨 페이지에서 딸려 온 값을 버린다', () => {
    const page = {
      type: 'jobPage',
      site: 'wanted',
      url: 'https://www.wanted.co.kr/wd/1?session=s',
      companies: ['가상전자(주)'],
      cookie: 'SID=secret',
      password: 'pw',
    } as unknown as JobPageMessage;
    expect(sanitizeJobPage(page)).toEqual({
      type: 'jobPage',
      site: 'wanted',
      url: 'https://www.wanted.co.kr/wd/1',
      companies: ['가상전자(주)'],
    });
  });

  it('빈 회사명은 빼고, 후보는 5개 · 원문은 2만 자까지만 보낸다', () => {
    const page: JobPageMessage = {
      type: 'jobPage',
      site: 'wanted',
      url: 'https://www.wanted.co.kr/wd/1',
      companies: [' ', '가1', '가2', '가3', '가4', '가5', '가6'],
      postingText: '가'.repeat(30_000),
    };
    const result = sanitizeJobPage(page);
    expect(result.companies).toEqual(['가1', '가2', '가3', '가4', '가5']);
    expect(result.postingText).toHaveLength(20_000);
  });
});

describe('공고 원문 거르기 (SEC-002)', () => {
  it('공고 원문의 이메일 · 전화번호 · 토큰을 가리고, 원문이 없으면 필드를 넣지 않는다', () => {
    const page: JobPageMessage = {
      type: 'jobPage',
      site: 'wanted',
      url: 'https://www.wanted.co.kr/wd/1',
      companies: ['가상전자'],
      postingText: '문의 recruit@example.com 010-1234-5678',
    };
    expect(sanitizeJobPage(page).postingText).toBe('문의 [제외] [제외]');
    expect(sanitizeJobPage({ ...page, postingText: undefined })).not.toHaveProperty('postingText');
  });
});
