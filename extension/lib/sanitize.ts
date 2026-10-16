import type { JobPageMessage } from './protocol';

/** 공고를 식별하는 데 필요한 주소 쿼리만 남긴다. 나머지(세션 · 추적 · 토큰)는 지운다 */
const ALLOWED_QUERY_KEYS = new Set(['rec_idx', 'gno', 'GI_No']);

const SENSITIVE_PATTERNS: RegExp[] = [
  /\beyJ[\w-]+\.[\w-]+\.[\w-]+/g, // JWT
  /[\w.+-]+@[\w-]+(\.[\w-]+)+/g, // 이메일
  /\b01[016789][-\s]?\d{3,4}[-\s]?\d{4}\b/g, // 휴대전화
  /\b[A-Za-z0-9_-]{32,}\b/g, // 긴 토큰 · 키
];

const MAX_COMPANY_LENGTH = 100;

/** 주소에서 허용한 쿼리만 남기고 계정 정보 · 해시를 지운다 */
export function sanitizeUrl(raw: string): string {
  const url = new URL(raw);
  url.username = '';
  url.password = '';
  url.hash = '';
  for (const key of [...url.searchParams.keys()]) {
    if (!ALLOWED_QUERY_KEYS.has(key)) url.searchParams.delete(key);
  }
  return url.toString();
}

/** 글자에서 토큰 · 이메일 · 전화번호 모양을 가린다 */
export function redactSensitive(text: string): string {
  return SENSITIVE_PATTERNS.reduce((result, pattern) => result.replace(pattern, '[제외]'), text);
}

/**
 * 공고 메시지를 앱으로 보내기 전에 거른다 (SEC-002).
 * 정해진 필드만 새 객체로 옮기므로 페이지에서 딸려 온 다른 값(쿠키 · 폼 값 등)은 남지 않는다.
 */
export function sanitizeJobPage(message: JobPageMessage): JobPageMessage {
  const company = message.company
    ? redactSensitive(message.company).trim().slice(0, MAX_COMPANY_LENGTH)
    : undefined;
  return {
    type: 'jobPage',
    site: message.site,
    url: sanitizeUrl(message.url),
    ...(company ? { company } : {}),
  };
}
