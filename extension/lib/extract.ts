import type { MetaRule, Site } from './siteConfig';

/** 회사명 후보 하나와 읽은 곳 */
export type CompanyCandidate = { name: string; source: 'jsonLd' | 'meta' | 'dom' };

/** 공고 페이지에서 읽은 것 (보내기 전 거르기는 sanitize) */
export type Extraction = {
  candidates: CompanyCandidate[];
  title: string | null;
  /** 공고 원문 (담당업무 · 자격요건 등). 못 찾으면 null — 없음을 명시 (WEB-011) */
  postingText: string | null;
};

const clean = (text: string | null | undefined) => (text ?? '').replace(/\s+/g, ' ').trim();

function jobPostings(value: unknown): Record<string, unknown>[] {
  if (Array.isArray(value)) return value.flatMap(jobPostings);
  if (typeof value !== 'object' || value === null) return [];
  const record = value as Record<string, unknown>;
  const own = record['@type'] === 'JobPosting' ? [record] : [];
  return [...own, ...jobPostings(record['@graph'])];
}

/** JobPosting JSON-LD의 hiringOrganization 이름 (법인명 우선, WEB-006) */
export function jsonLdCompanies(doc: Document): string[] {
  return [...doc.querySelectorAll('script[type="application/ld+json"]')].flatMap((script) => {
    let parsed: unknown;
    try {
      parsed = JSON.parse(script.textContent ?? '');
    } catch {
      return [];
    }
    return jobPostings(parsed).map((posting) => {
      const organization = posting.hiringOrganization;
      if (typeof organization === 'string') return clean(organization);
      const name = (organization as { name?: unknown } | undefined)?.name;
      return typeof name === 'string' ? clean(name) : '';
    });
  });
}

/** 메타 태그 값에서 정규식 첫 묶음 */
export function metaCompanies(doc: Document, rules: MetaRule[]): string[] {
  return rules.map((rule) => {
    const content = doc.querySelector(
      `meta[property="${rule.property}"], meta[name="${rule.property}"]`,
    );
    const match = new RegExp(rule.pattern).exec(content?.getAttribute('content') ?? '');
    return clean(match?.[1]);
  });
}

export function domCompanies(doc: Document, selectors: string[]): string[] {
  return selectors.map((selector) => clean(doc.querySelector(selector)?.textContent));
}

/** 구조화 데이터 → 메타 → DOM 순으로 후보를 모은다. 빈 값 · 같은 글자는 한 번만 */
export function companyCandidates(doc: Document, site: Site): CompanyCandidate[] {
  const ordered: CompanyCandidate[] = [
    ...(site.company.jsonLd ? jsonLdCompanies(doc) : []).map((name) => ({
      name,
      source: 'jsonLd' as const,
    })),
    ...metaCompanies(doc, site.company.meta).map((name) => ({ name, source: 'meta' as const })),
    ...domCompanies(doc, site.company.selectors).map((name) => ({ name, source: 'dom' as const })),
  ];
  const seen = new Set<string>();
  return ordered.filter(
    (candidate) => candidate.name && !seen.has(candidate.name) && seen.add(candidate.name),
  );
}

function frameText(doc: Document, selector: string): string {
  const frame = doc.querySelector<HTMLIFrameElement>(selector);
  try {
    // 같은 사이트 iframe만 읽힌다. 다른 사이트면 contentDocument가 null이거나 예외
    return clean(frame?.contentDocument?.body?.textContent);
  } catch {
    return '';
  }
}

export function postingText(doc: Document, site: Site): string | null {
  const parts = [
    ...site.postingText.selectors.map((selector) =>
      clean(doc.querySelector(selector)?.textContent),
    ),
    ...site.postingText.frames.map((selector) => frameText(doc, selector)),
  ].filter(Boolean);
  return parts.length > 0 ? parts.join('\n\n') : null;
}

export function extractPosting(doc: Document, site: Site): Extraction {
  const ogTitle = doc.querySelector('meta[property="og:title"]')?.getAttribute('content');
  return {
    candidates: companyCandidates(doc, site),
    title: clean(ogTitle ?? doc.title) || null,
    postingText: postingText(doc, site),
  };
}
