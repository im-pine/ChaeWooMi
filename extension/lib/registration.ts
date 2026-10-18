import { hostPatterns, type SiteConfig } from './siteConfig';

export const POSTING_SCRIPT_ID = 'chaewoomi-posting';

/**
 * 설정 도메인 중 권한이 있는 곳과 아직 사용자 승인이 필요한 곳을 나눈다 (WEB-002).
 * 권한이 없는 도메인에는 콘텐츠 스크립트를 등록하지 않아 페이지를 읽지 않는다.
 */
export async function splitByPermission(
  config: SiteConfig,
  hasPermission: (pattern: string) => Promise<boolean>,
): Promise<{ granted: string[]; missing: string[] }> {
  const patterns = hostPatterns(config);
  const allowed = await Promise.all(patterns.map(hasPermission));
  return {
    granted: patterns.filter((_, index) => allowed[index]),
    missing: patterns.filter((_, index) => !allowed[index]),
  };
}
