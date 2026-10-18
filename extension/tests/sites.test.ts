import { describe, expect, it } from 'vitest';
import { HOST_PERMISSIONS, OPTIONAL_HOST_PERMISSIONS } from '@/lib/sites';
import { DEFAULT_CONFIG, postingSite } from '@/lib/siteConfig';

const siteOf = (url: string) => postingSite(url, DEFAULT_CONFIG)?.id ?? null;

describe('지정 도메인 한정 (SEC-001 · WEB-002)', () => {
  it('기본 권한은 설정 기본값의 사람인 · 잡코리아 · 원티드 세 도메인뿐이다', () => {
    expect(HOST_PERMISSIONS).toEqual([
      'https://*.saramin.co.kr/*',
      'https://*.jobkorea.co.kr/*',
      'https://*.wanted.co.kr/*',
    ]);
  });

  it('사이트 추가용 권한은 선택 권한으로만 둔다', () => {
    expect(OPTIONAL_HOST_PERMISSIONS).toEqual(['https://*/*']);
    expect(HOST_PERMISSIONS).not.toContain('https://*/*');
  });
});

describe('공고 페이지 판별 (WEB-014 · APP-011)', () => {
  it('세 사이트의 공고 상세 주소는 그 사이트로 본다', () => {
    expect(siteOf('https://www.saramin.co.kr/zf_user/jobs/view?rec_idx=1')).toBe('saramin');
    expect(
      siteOf('https://www.saramin.co.kr/zf_user/jobs/relay/view?view_type=list&rec_idx=2'),
    ).toBe('saramin');
    expect(siteOf('https://www.jobkorea.co.kr/Recruit/GI_Read/1')).toBe('jobkorea');
    expect(siteOf('https://www.wanted.co.kr/wd/1')).toBe('wanted');
  });

  it('같은 사이트라도 목록 · 검색 페이지는 공고가 아니다', () => {
    expect(siteOf('https://www.saramin.co.kr/zf_user/jobs/list/domestic')).toBeNull();
    expect(siteOf('https://www.jobkorea.co.kr/Search/?stext=개발')).toBeNull();
    expect(siteOf('https://www.wanted.co.kr/wdlist/518')).toBeNull();
  });

  it('지정 외 사이트 · 비슷한 이름 · http · 깨진 주소는 공고가 아니다', () => {
    expect(siteOf('https://www.example.com/wd/1')).toBeNull();
    expect(siteOf('https://saramin.co.kr.example.com/zf_user/jobs/view?rec_idx=1')).toBeNull();
    expect(siteOf('https://notwanted.co.kr/wd/1')).toBeNull();
    expect(siteOf('http://www.wanted.co.kr/wd/1')).toBeNull();
    expect(siteOf('not a url')).toBeNull();
  });
});
