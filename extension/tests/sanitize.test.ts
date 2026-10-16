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
      company: '가상전자(주)',
      cookie: 'SID=secret',
      password: 'pw',
    } as JobPageMessage;
    expect(sanitizeJobPage(page)).toEqual({
      type: 'jobPage',
      site: 'wanted',
      url: 'https://www.wanted.co.kr/wd/1',
      company: '가상전자(주)',
    });
  });

  it('회사명이 비면 company 필드를 넣지 않는다', () => {
    const page: JobPageMessage = {
      type: 'jobPage',
      site: 'wanted',
      url: 'https://www.wanted.co.kr/wd/1',
      company: ' ',
    };
    expect(sanitizeJobPage(page)).not.toHaveProperty('company');
  });
});
