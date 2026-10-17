import { describe, expect, it } from 'vitest';
import type { JobPageMessage } from '@/lib/protocol';
import { TabPages } from '@/lib/tabPages';

const page = (company: string): JobPageMessage => ({
  type: 'jobPage',
  site: 'wanted',
  url: `https://www.wanted.co.kr/wd/${company.length}`,
  companies: [company],
});

describe('보고 있는 탭의 공고만 앱에 보낸다 (WEB-015)', () => {
  it('보고 있는 탭의 공고는 보내고, 뒤 탭의 공고는 기억만 한다', () => {
    const tabs = new TabPages();
    tabs.activate(1);
    expect(tabs.posting(1, page('가상전자'))).toEqual(page('가상전자'));
    expect(tabs.posting(2, page('가상물산'))).toBeNull();
  });

  it('다른 탭으로 옮기면 그 탭의 공고를, 공고가 없으면 pageLeft를 보낸다', () => {
    const tabs = new TabPages();
    tabs.activate(1);
    tabs.posting(1, page('가상전자'));
    tabs.posting(2, page('가상물산'));
    expect(tabs.activate(2)).toEqual(page('가상물산'));
    expect(tabs.activate(3)).toEqual({ type: 'pageLeft' });
  });

  it('A 공고에서 B 공고로 옮기면 B만 남고, 공고가 아닌 페이지로 가면 pageLeft (QA-020)', () => {
    const tabs = new TabPages();
    tabs.activate(1);
    tabs.posting(1, page('가상전자'));
    expect(tabs.posting(1, page('가상물산'))).toEqual(page('가상물산'));
    expect(tabs.left(1)).toEqual({ type: 'pageLeft' });
    expect(tabs.current()).toEqual({ type: 'pageLeft' });
  });

  it('보고 있는 공고 탭을 닫으면 pageLeft, 뒤 탭을 닫으면 아무것도 보내지 않는다', () => {
    const tabs = new TabPages();
    tabs.activate(1);
    tabs.posting(1, page('가상전자'));
    tabs.posting(2, page('가상물산'));
    expect(tabs.closed(2)).toBeNull();
    expect(tabs.closed(1)).toEqual({ type: 'pageLeft' });
  });

  it('지원 버튼 알림도 보고 있는 탭 것만 보낸다', () => {
    const tabs = new TabPages();
    tabs.activate(1);
    expect(tabs.applyButton(1, true)).toEqual({ type: 'applyButton', covering: true });
    expect(tabs.applyButton(2, true)).toBeNull();
  });
});

describe('등록 도메인 밖으로 이동', () => {
  it('보고 있는 공고 탭이 새 페이지를 불러오기 시작하면 pageLeft, 공고가 없던 탭은 아무것도 보내지 않는다', () => {
    const tabs = new TabPages();
    tabs.activate(1);
    tabs.posting(1, page('가상전자'));
    expect(tabs.navigating(1)).toEqual({ type: 'pageLeft' });
    expect(tabs.navigating(1)).toBeNull();
    expect(tabs.current()).toEqual({ type: 'pageLeft' });
  });
});
