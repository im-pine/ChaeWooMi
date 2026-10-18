import { describe, expect, it } from 'vitest';
import { AutoRescan } from '@/lib/autoRescan';

const url = 'https://www.saramin.co.kr/zf_user/jobs/view?rec_idx=1';

describe('탭에 들어갈 때 자동 다시 읽기 ("지원 이력 확인" 자동화)', () => {
  it('지정 사이트 공고인데 공고를 모르면 다시 읽는다', () => {
    expect(new AutoRescan().shouldTry(1, url, true, false)).toBe(true);
  });

  it('공고를 이미 알거나 · 공고 주소가 아니거나 · 주소가 없으면 하지 않는다', () => {
    const auto = new AutoRescan();
    expect(auto.shouldTry(1, url, true, true)).toBe(false);
    expect(auto.shouldTry(1, 'https://example.com', false, false)).toBe(false);
    expect(auto.shouldTry(1, undefined, true, false)).toBe(false);
  });

  it('같은 탭 · 같은 공고는 한 번만 (해시가 달라도 같은 공고), 다른 공고로 옮기면 다시', () => {
    const auto = new AutoRescan();
    expect(auto.shouldTry(1, url, true, false)).toBe(true);
    expect(auto.shouldTry(1, `${url}#seq=0`, true, false)).toBe(false);
    expect(auto.shouldTry(1, url.replace('rec_idx=1', 'rec_idx=2'), true, false)).toBe(true);
    expect(auto.shouldTry(2, url, true, false)).toBe(true);
  });

  it('탭을 닫으면 잊어서 같은 번호의 새 탭은 다시 시도한다', () => {
    const auto = new AutoRescan();
    auto.shouldTry(1, url, true, false);
    auto.forget(1);
    expect(auto.shouldTry(1, url, true, false)).toBe(true);
  });
});
