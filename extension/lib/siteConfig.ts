/**
 * 지원 사이트 설정 (WEB-014). 앱 소유 파일이고 기본값은 저장소 루트 `protocol/sites.default.json` (Swift 테스트와 공용).
 * 앱이 `siteConfig` 메시지로 보내 주면 그 설정을 쓰고, 연결 전에는 기본값을 쓴다.
 */
import defaultJson from '../../protocol/sites.default.json';

export type MetaRule = { property: string; pattern: string };

export type Site = {
  id: string;
  label: string;
  domains: string[];
  postingPatterns: string[];
  completePatterns: string[];
  completeTexts: string[];
  company: { jsonLd: boolean; meta: MetaRule[]; selectors: string[] };
  postingText: { selectors: string[]; frames: string[] };
  applyButtons: { selectors: string[]; texts: string[] };
};

export type SiteConfig = { version: number; sites: Site[] };

export const DEFAULT_CONFIG = defaultJson as SiteConfig;

const isStringArray = (value: unknown): value is string[] =>
  Array.isArray(value) && value.every((item) => typeof item === 'string');

const isRegex = (pattern: string) => {
  try {
    new RegExp(pattern);
    return true;
  } catch {
    return false;
  }
};

const DOMAIN = /^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/;

/** 사이트 하나의 문제 목록 (경로: 이유) */
function siteProblems(site: Site, path: string): string[] {
  const problems: string[] = [];
  if (!site.id) problems.push(`${path}.id: 비어 있습니다`);
  if (site.domains.length === 0) problems.push(`${path}.domains: 도메인이 없습니다`);
  site.domains.forEach((domain, index) => {
    if (!DOMAIN.test(domain)) problems.push(`${path}.domains[${index}]: 도메인 형식이 아닙니다`);
  });
  if (site.postingPatterns.length === 0)
    problems.push(`${path}.postingPatterns: 공고 주소 패턴이 없습니다`);
  (['postingPatterns', 'completePatterns'] as const).forEach((field) =>
    site[field].forEach((pattern, index) => {
      if (!isRegex(pattern)) problems.push(`${path}.${field}[${index}]: 정규식이 아닙니다`);
    }),
  );
  return problems;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/** `record[key]`가 객체이고 그 안의 필드가 모두 문자열 배열인가 */
const hasStringArrays = (record: Record<string, unknown>, key: string, fields: string[]) => {
  const inner = record[key];
  return isRecord(inner) && fields.every((field) => isStringArray(inner[field]));
};

function hasShape(site: unknown): site is Site {
  if (!isRecord(site)) return false;
  const company = site.company;
  return (
    typeof site.id === 'string' &&
    typeof site.label === 'string' &&
    ['domains', 'postingPatterns', 'completePatterns', 'completeTexts'].every((field) =>
      isStringArray(site[field]),
    ) &&
    isRecord(company) &&
    typeof company.jsonLd === 'boolean' &&
    Array.isArray(company.meta) &&
    hasStringArrays(site, 'company', ['selectors']) &&
    hasStringArrays(site, 'postingText', ['selectors', 'frames']) &&
    hasStringArrays(site, 'applyButtons', ['selectors', 'texts'])
  );
}

/** 설정 검사. 비어 있으면 쓸 수 있는 설정 */
export function configProblems(value: unknown): string[] {
  if (typeof value !== 'object' || value === null) return ['설정이 객체가 아닙니다'];
  const config = value as { version?: unknown; sites?: unknown };
  if (config.version !== 1) return ['version: 1이어야 합니다'];
  if (!Array.isArray(config.sites) || config.sites.length === 0)
    return ['sites: 사이트가 없습니다'];
  return config.sites.flatMap((site, index) =>
    hasShape(site)
      ? siteProblems(site, `sites[${index}]`)
      : [`sites[${index}]: 항목 모양이 다릅니다`],
  );
}

const onDomain = (host: string, domain: string) => host === domain || host.endsWith(`.${domain}`);

/** 지원 완료 화면은 공고 주소가 아닐 수 있어(지원 팝업 · 완료 페이지) 도메인으로만 사이트를 찾는다 */
export function domainSite(url: string, config: SiteConfig): Site | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (parsed.protocol !== 'https:') return null;
  return (
    config.sites.find((site) => site.domains.some((domain) => onDomain(parsed.hostname, domain))) ??
    null
  );
}

/** 주소가 설정의 공고 페이지면 그 사이트, 아니면 null (URL은 공고 페이지 판단에만 쓴다) */
export function postingSite(url: string, config: SiteConfig): Site | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (parsed.protocol !== 'https:') return null;
  const target = parsed.pathname + parsed.search;
  return (
    config.sites.find(
      (site) =>
        site.domains.some((domain) => onDomain(parsed.hostname, domain)) &&
        site.postingPatterns.some((pattern) => new RegExp(pattern).test(target)),
    ) ?? null
  );
}

/** 설정 도메인의 Chrome 호스트 권한 패턴 (`https://*.도메인/*`는 맨 도메인도 포함) */
export function hostPatterns(config: SiteConfig): string[] {
  return [
    ...new Set(
      config.sites.flatMap((site) => site.domains.map((domain) => `https://*.${domain}/*`)),
    ),
  ];
}
