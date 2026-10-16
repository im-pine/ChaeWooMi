import { describe, expect, it } from 'vitest';
import { HOST_PERMISSIONS, OPTIONAL_HOST_PERMISSIONS, siteFor } from '@/lib/sites';

describe('지정 도메인 한정 (SEC-001)', () => {
  it('기본 권한은 사람인 · 잡코리아 · 원티드 세 도메인뿐이다', () => {
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

  it('지정 사이트 주소는 사이트 id를 돌려준다', () => {
    expect(siteFor('https://www.saramin.co.kr/zf_user/jobs/view?rec_idx=1')).toBe('saramin');
    expect(siteFor('https://www.jobkorea.co.kr/Recruit/GI_Read/1')).toBe('jobkorea');
    expect(siteFor('https://www.wanted.co.kr/wd/1')).toBe('wanted');
  });

  it('지정 외 사이트 · 비슷한 이름 · http · 깨진 주소는 null이다', () => {
    expect(siteFor('https://www.example.com/jobs/1')).toBeNull();
    expect(siteFor('https://saramin.co.kr.example.com/')).toBeNull();
    expect(siteFor('https://notwanted.co.kr/wd/1')).toBeNull();
    expect(siteFor('http://www.wanted.co.kr/wd/1')).toBeNull();
    expect(siteFor('not a url')).toBeNull();
  });
});
