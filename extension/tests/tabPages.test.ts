import { describe, expect, it } from 'vitest';
import type { JobPageMessage } from '@/lib/protocol';
import { sanitizeJobPage } from '@/lib/sanitize';
import { sameDocument, TabPages } from '@/lib/tabPages';

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

  it('같은 공고에서 해시가 붙는 loading은 공고를 지우지 않는다 (사람인 #seq=0 실측 버그)', () => {
    const tabs = new TabPages();
    tabs.activate(1);
    // 실제 흐름처럼 콘텐츠 스크립트가 거른 공고 (view_type 등은 지워짐)
    const raw = 'https://www.saramin.co.kr/zf_user/jobs/relay/view?view_type=list&rec_idx=12345678';
    const posting = sanitizeJobPage({
      type: 'jobPage',
      site: 'saramin',
      url: raw,
      companies: ['가상전자(주)'],
    });
    tabs.posting(1, posting);
    expect(tabs.navigating(1, `${raw}#seq=0`)).toBeNull();
    expect(tabs.navigating(1, raw)).toBeNull();
    expect(tabs.current()).toEqual(posting);
    expect(
      tabs.navigating(
        1,
        'https://www.saramin.co.kr/zf_user/jobs/relay/view?view_type=list&rec_idx=99',
      ),
    ).toEqual({ type: 'pageLeft' });
  });

  it('같은 공고 주소 판단: 허용 쿼리 · 경로가 같으면 같고, 공고 번호가 다르면 다르다', () => {
    const base = 'https://www.saramin.co.kr/zf_user/jobs/view?rec_idx=1';
    expect(sameDocument(base, `${base}&view_type=list#seq=0`)).toBe(true);
    expect(sameDocument(base, 'https://www.saramin.co.kr/zf_user/jobs/view?rec_idx=2')).toBe(false);
    expect(sameDocument(base, 'not a url')).toBe(false);
  });
});

describe('service worker 재시작에도 탭별 공고를 잃지 않는다 (백그라운드 탭 실측 버그)', () => {
  it('저장한 상태로 되살리면 이전에 연 뒤 탭으로 옮길 때 그 공고를 보낸다', () => {
    const before = new TabPages();
    before.activate(1);
    before.posting(2, page('가상전자'));
    before.posting(3, page('가상물산'));
    const restored = TabPages.restore(JSON.parse(JSON.stringify(before.state())));
    expect(restored.activate(3)).toEqual(page('가상물산'));
    expect(restored.complete()?.companies).toEqual(['가상물산']);
  });

  it('저장한 상태가 없으면 빈 상태', () => {
    expect(TabPages.restore(undefined).current()).toEqual({ type: 'pageLeft' });
  });
});
