import { applyButtons, coversCardZone } from './applyButton';
import { isCompletePage } from './completion';
import { extractPosting } from './extract';
import type { JobPageMessage } from './protocol';
import { sanitizeJobPage } from './sanitize';
import { domainSite, postingSite, type SiteConfig } from './siteConfig';

/** 페이지를 한 번 읽은 결과 */
export type PageRead = { kind: 'posting'; page: JobPageMessage } | { kind: 'left' };

/** 콘텐츠 스크립트가 background에 보내는 것 */
export type PageReport =
  PageRead | { kind: 'applyButton'; covering: boolean } | { kind: 'complete' };

/** background → 콘텐츠 스크립트: 지금 페이지를 다시 읽어라 (카드의 "지원 이력 확인" 버튼) */
export const RESCAN = 'chaewoomi-rescan';

/** 회사명이 나타날 때까지 기다리는 최대 시간 (사람인은 본문을 나중에 불러옴) */
export const WAIT_FOR_COMPANY_MS = 5000;

/**
 * 지금 페이지를 한 번 읽는다. 공고가 아니면 left, 공고면 거른 공고 정보.
 * 회사명 후보가 비어도 보낸다 → 앱이 수동 카드 (WEB-007)
 */
export function readPage(doc: Document, url: string, config: SiteConfig): PageRead {
  const site = postingSite(url, config);
  if (!site) return { kind: 'left' };
  const extraction = extractPosting(doc, site);
  const page: JobPageMessage = {
    type: 'jobPage',
    site: site.id,
    url,
    companies: extraction.candidates.map((candidate) => candidate.name),
    ...(extraction.title ? { title: extraction.title } : {}),
    ...(extraction.postingText ? { postingText: extraction.postingText } : {}),
  };
  return { kind: 'posting', page: sanitizeJobPage(page) };
}

/** 보이는 지원 버튼 중 하나라도 카드 자리를 가리는가 */
export function applyButtonCovering(
  doc: Document,
  url: string,
  config: SiteConfig,
  viewport: { width: number; height: number },
) {
  const site = postingSite(url, config);
  if (!site) return false;
  return applyButtons(doc, site).some((button) =>
    coversCardZone(button.getBoundingClientRect(), viewport),
  );
}

/** 설정 사이트의 지원 완료 화면인가 (HIS-017). 공고 주소가 아니어도 도메인이 맞으면 본다 */
export function completeOnPage(doc: Document, url: string, config: SiteConfig): boolean {
  const site = domainSite(url, config);
  return site ? isCompletePage(doc, url, site) : false;
}
