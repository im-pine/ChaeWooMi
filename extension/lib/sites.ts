import { DEFAULT_CONFIG, hostPatterns } from './siteConfig';

/** manifest `host_permissions` — 기본 지원 사이트(설정 기본값)만 (SEC-001) */
export const HOST_PERMISSIONS: string[] = hostPatterns(DEFAULT_CONFIG);

/**
 * manifest `optional_host_permissions` — 사이트 추가는 사용자가 승인할 때만 그 도메인 권한을 받는다 (WEB-002).
 * 설치 시점에는 아무 권한도 주지 않는다.
 */
export const OPTIONAL_HOST_PERMISSIONS = ['https://*/*'];
