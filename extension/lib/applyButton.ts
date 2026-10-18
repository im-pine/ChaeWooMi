import type { Site } from './siteConfig';

/** 화면 오른쪽 아래에서 카드가 차지하는 영역 (카드 220×104 + 여백 16, 여유 20) */
export const CARD_ZONE = { width: 256, height: 140 };

export type Rect = { left: number; top: number; right: number; bottom: number };

const normalized = (text: string | null) => (text ?? '').replace(/\s+/g, '');

/** 설정의 선택자 · 글자로 지원 버튼을 찾는다 */
export function applyButtons(doc: Document, site: Site): Element[] {
  const bySelector = site.applyButtons.selectors.flatMap((selector) => [
    ...doc.querySelectorAll(selector),
  ]);
  const texts = site.applyButtons.texts.map(normalized);
  const byText = [...doc.querySelectorAll('button, a')].filter((element) =>
    texts.includes(normalized(element.textContent)),
  );
  return [...new Set([...bySelector, ...byText])];
}

/**
 * 그 공고의 지원 버튼으로 볼 최소 크기. 사람인 공고 오른쪽 추천 목록의 작은 `입사지원`(약 53×22)이 카드 자리에 들어와
 * 카드를 런처로 접던 문제가 있었다 (실측). 공고 본문의 지원 버튼은 이보다 크다 (사람인 185×60)
 */
export const MIN_APPLY_BUTTON = { width: 80, height: 30 };

/** 그 공고의 지원 버튼만큼 큰가 (추천 목록의 작은 버튼 제외) */
export function isMainApplyButton(button: Rect): boolean {
  return (
    button.right - button.left >= MIN_APPLY_BUTTON.width &&
    button.bottom - button.top >= MIN_APPLY_BUTTON.height
  );
}

/** 지원 버튼이 오른쪽 아래 카드 자리와 겹치는가 (겹치면 카드를 런처로 접는다, APP-015) */
export function coversCardZone(button: Rect, viewport: { width: number; height: number }): boolean {
  const zone = {
    left: viewport.width - CARD_ZONE.width,
    top: viewport.height - CARD_ZONE.height,
    right: viewport.width,
    bottom: viewport.height,
  };
  return (
    button.left < zone.right &&
    button.right > zone.left &&
    button.top < zone.bottom &&
    button.bottom > zone.top
  );
}
