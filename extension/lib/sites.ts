/** 기본 지원 사이트. 확장 권한은 이 도메인으로만 한정한다 (SEC-001). */
export const DEFAULT_SITES = [
  { id: 'saramin', label: '사람인', matches: ['https://*.saramin.co.kr/*'] },
  { id: 'jobkorea', label: '잡코리아', matches: ['https://*.jobkorea.co.kr/*'] },
  { id: 'wanted', label: '원티드', matches: ['https://*.wanted.co.kr/*'] },
] as const;

export type SiteId = (typeof DEFAULT_SITES)[number]['id'];

/** manifest `host_permissions` — 기본 지원 사이트만 */
export const HOST_PERMISSIONS: string[] = DEFAULT_SITES.flatMap((site) => [...site.matches]);

/**
 * manifest `optional_host_permissions` — 사이트 추가는 사용자가 승인할 때만 그 도메인 권한을 받는다.
 * 설치 시점에는 아무 권한도 주지 않는다.
 */
export const OPTIONAL_HOST_PERMISSIONS = ['https://*/*'];

/** 주소가 기본 지원 사이트면 그 사이트 id, 아니면 null */
export function siteFor(url: string): SiteId | null {
  let host: string;
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:') return null;
    host = parsed.hostname;
  } catch {
    return null;
  }
  const site = DEFAULT_SITES.find((candidate) => {
    const domain = candidate.matches[0].replace('https://*.', '').replace('/*', '');
    return host === domain || host.endsWith(`.${domain}`);
  });
  return site?.id ?? null;
}
