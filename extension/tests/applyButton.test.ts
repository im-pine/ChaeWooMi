// @vitest-environment happy-dom
import { describe, expect, it } from 'vitest';
import saramin from './fixtures/saramin.html?raw';
import jobkorea from './fixtures/jobkorea.html?raw';
import wanted from './fixtures/wanted.html?raw';
import { applyButtons, CARD_ZONE, coversCardZone, isMainApplyButton } from '@/lib/applyButton';
import { DEFAULT_CONFIG } from '@/lib/siteConfig';

const parse = (html: string) => new DOMParser().parseFromString(html, 'text/html');
const site = (id: string) => DEFAULT_CONFIG.sites.find((candidate) => candidate.id === id)!;
const viewport = { width: 1440, height: 900 };

describe('지원 버튼과 카드 자리 (APP-015)', () => {
  it('설정의 선택자 · 글자로 세 사이트의 지원 버튼을 찾는다', () => {
    expect(
      applyButtons(parse(saramin), site('saramin')).map((button) => button.textContent),
    ).toEqual(['즉시지원']);
    expect(
      applyButtons(parse(jobkorea), site('jobkorea')).map((button) => button.textContent),
    ).toEqual(['즉시 지원']);
    expect(applyButtons(parse(wanted), site('wanted')).map((button) => button.textContent)).toEqual(
      ['지원하기'],
    );
  });

  it('버튼이 화면 오른쪽 아래 카드 자리와 겹치면 가린다고 본다', () => {
    const bottomRight = { left: 1300, top: 820, right: 1420, bottom: 870 };
    expect(coversCardZone(bottomRight, viewport)).toBe(true);
  });

  it('카드 자리 바로 바깥(왼쪽 · 위)은 가리지 않는다', () => {
    const left = viewport.width - CARD_ZONE.width;
    const top = viewport.height - CARD_ZONE.height;
    expect(coversCardZone({ left: 0, top: 820, right: left, bottom: 870 }, viewport)).toBe(false);
    expect(coversCardZone({ left: 1300, top: 0, right: 1420, bottom: top }, viewport)).toBe(false);
  });
});

describe('카드를 접게 하는 것은 그 공고의 큰 지원 버튼만 (실측 버그)', () => {
  it('추천 목록의 작은 입사지원 버튼(약 53×22)은 카드 자리에 있어도 접지 않는다', () => {
    const small = { left: 1300, top: 820, right: 1353, bottom: 842 };
    expect(coversCardZone(small, viewport)).toBe(true);
    expect(isMainApplyButton(small)).toBe(false);
  });

  it('공고 본문의 지원 버튼(185×60)은 그 공고의 지원 버튼으로 본다', () => {
    expect(isMainApplyButton({ left: 792, top: 150, right: 977, bottom: 210 })).toBe(true);
  });
});
