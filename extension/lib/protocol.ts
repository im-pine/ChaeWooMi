/** 확장 ↔ 앱 메시지 규약. 예시는 저장소 루트 `protocol/examples/` (Swift 테스트와 공용). */
import { configProblems, type SiteConfig } from './siteConfig';

export type HelloMessage = { type: 'hello'; extensionVersion: string };

export type JobPageMessage = {
  type: 'jobPage';
  site: string;
  url: string;
  company?: string;
};

export type ExtensionToApp = HelloMessage | JobPageMessage;

export type AckMessage = { type: 'ack'; appVersion: string };

/** 앱 소유 지원 사이트 설정 (WEB-014) */
export type SiteConfigMessage = { type: 'siteConfig'; config: SiteConfig };

export type AppToExtension = AckMessage | SiteConfigMessage;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isOptionalString(value: unknown): boolean {
  return value === undefined || typeof value === 'string';
}

/** 앱으로 보내는 메시지 모양 검사 */
export function isExtensionToApp(value: unknown): value is ExtensionToApp {
  if (!isRecord(value)) return false;
  switch (value.type) {
    case 'hello':
      return typeof value.extensionVersion === 'string';
    case 'jobPage':
      return (
        typeof value.site === 'string' &&
        typeof value.url === 'string' &&
        isOptionalString(value.company)
      );
    default:
      return false;
  }
}

/** 앱이 보낸 메시지 모양 검사. 모르는 메시지는 버린다 */
export function isAppToExtension(value: unknown): value is AppToExtension {
  if (!isRecord(value)) return false;
  if (value.type === 'ack') return typeof value.appVersion === 'string';
  // 틀린 설정은 받지 않고 지금 설정을 그대로 쓴다
  if (value.type === 'siteConfig') return configProblems(value.config).length === 0;
  return false;
}
