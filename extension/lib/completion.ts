import type { Site } from './siteConfig';

/** 화면에 보이지 않는 글자를 담는 태그 (번들 안 번역 문구 등에 잘못 걸리지 않게) */
const HIDDEN = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE']);

const compact = (text: string) => text.replace(/\s+/g, '');

/** 본문 글자 (공백 없이). `script` · `style` 안은 뺀다 */
export function visibleText(doc: Document): string {
  if (!doc.body) return '';
  const walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT);
  const parts: string[] = [];
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    if (!HIDDEN.has(node.parentElement?.tagName ?? '')) parts.push(node.textContent ?? '');
  }
  return compact(parts.join(''));
}

/**
 * 지원 완료 화면인가 (HIS-017): 주소가 `completePatterns`에 맞거나, 보이는 글자에 `completeTexts` 문구가 있으면.
 * 자동 제출 · 클릭은 하지 않고 화면을 읽기만 한다 (HIS-001).
 */
export function isCompletePage(doc: Document, url: string, site: Site): boolean {
  let target: string;
  try {
    const parsed = new URL(url);
    target = parsed.pathname + parsed.search;
  } catch {
    return false;
  }
  if (site.completePatterns.some((pattern) => new RegExp(pattern).test(target))) return true;
  if (site.completeTexts.length === 0) return false;
  const text = visibleText(doc);
  return site.completeTexts.some((phrase) => text.includes(compact(phrase)));
}
