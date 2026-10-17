// @vitest-environment happy-dom
import { describe, expect, it } from 'vitest';
import { isCompletePage, visibleText } from '@/lib/completion';
import { completeOnPage } from '@/lib/postingWatch';
import { DEFAULT_CONFIG, domainSite, type SiteConfig } from '@/lib/siteConfig';
import { TabPages } from '@/lib/tabPages';

const parse = (html: string) => new DOMParser().parseFromString(html, 'text/html');
const wanted = DEFAULT_CONFIG.sites.find((site) => site.id === 'wanted')!;

describe('지원 완료 화면 감지 (HIS-017)', () => {
  it('보이는 글자에 완료 문구가 있으면 완료 화면 (줄바꿈 · 띄어쓰기 달라도)', () => {
    const doc = parse('<body><div role="dialog"><h2>지원이\n  완료 되었습니다</h2></div></body>');
    expect(isCompletePage(doc, 'https://www.wanted.co.kr/wd/300001', wanted)).toBe(true);
  });

  it('script · style 안의 문구(번들 번역 문구 등)는 보지 않는다', () => {
    const doc = parse(
      '<body><h1>프론트엔드 개발자</h1><script>const t = "지원이 완료되었습니다"</script>' +
        '<style>/* 지원이 완료되었습니다 */</style></body>',
    );
    expect(visibleText(doc)).toBe('프론트엔드개발자');
    expect(isCompletePage(doc, 'https://www.wanted.co.kr/wd/300001', wanted)).toBe(false);
  });

  it('공고 화면의 "지원하기" · "지원 완료" 배지만으로는 완료로 보지 않는다', () => {
    const doc = parse('<body><button>지원하기</button><span>지원 완료</span></body>');
    expect(isCompletePage(doc, 'https://www.wanted.co.kr/wd/300001', wanted)).toBe(false);
  });
});

describe('지원 완료 화면 감지 — 주소 · 도메인 · 설정 (HIS-017)', () => {
  it('주소가 completePatterns에 맞으면 문구 없이도 완료 화면', () => {
    const site = { ...wanted, completePatterns: ['^/apply/complete'], completeTexts: [] };
    expect(
      isCompletePage(parse('<body></body>'), 'https://www.wanted.co.kr/apply/complete?id=1', site),
    ).toBe(true);
    expect(isCompletePage(parse('<body></body>'), 'https://www.wanted.co.kr/wd/1', site)).toBe(
      false,
    );
  });

  it('완료 화면은 공고 주소가 아니어도(지원 팝업 등) 설정 도메인이면 본다, 다른 도메인 · http는 보지 않는다', () => {
    const done = parse('<body><p>입사지원이 완료되었습니다.</p></body>');
    expect(domainSite('https://www.saramin.co.kr/zf_user/apply/popup', DEFAULT_CONFIG)?.id).toBe(
      'saramin',
    );
    expect(
      completeOnPage(done, 'https://www.saramin.co.kr/zf_user/apply/popup', DEFAULT_CONFIG),
    ).toBe(true);
    expect(completeOnPage(done, 'https://example.com/done', DEFAULT_CONFIG)).toBe(false);
    expect(completeOnPage(done, 'http://www.saramin.co.kr/done', DEFAULT_CONFIG)).toBe(false);
  });

  it('설정의 completePatterns 정규식 오류는 경로와 함께 알린다', async () => {
    const { configProblems } = await import('@/lib/siteConfig');
    const config: SiteConfig = {
      version: 1,
      sites: [{ ...wanted, completePatterns: ['('] }],
    };
    expect(configProblems(config)).toEqual(['sites[0].completePatterns[0]: 정규식이 아닙니다']);
    expect(
      configProblems({ version: 1, sites: [{ ...wanted, completeTexts: undefined }] }),
    ).toEqual(['sites[0]: 항목 모양이 다릅니다']);
  });
});

describe('지원 완료 메시지는 가장 최근 공고의 회사로 보낸다', () => {
  const page = {
    type: 'jobPage' as const,
    site: 'saramin',
    url: 'https://www.saramin.co.kr/zf_user/jobs/view?rec_idx=1',
    companies: ['가상전자(주)'],
    title: '[가상전자(주)] 프론트엔드',
    postingText: '공고 원문',
  };

  it('공고 탭에서 지원 팝업(다른 탭)으로 옮겨도 그 공고 회사로, 공고 원문은 빼고 보낸다', () => {
    const tabs = new TabPages();
    tabs.activate(1);
    tabs.posting(1, page);
    tabs.activate(2);
    tabs.navigating(1);
    expect(tabs.complete()).toEqual({
      type: 'applyComplete',
      site: 'saramin',
      url: page.url,
      companies: ['가상전자(주)'],
      title: '[가상전자(주)] 프론트엔드',
    });
  });

  it('본 공고가 없으면 보내지 않는다', () => {
    expect(new TabPages().complete()).toBeNull();
  });
});
