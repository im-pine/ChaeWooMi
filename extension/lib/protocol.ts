/** 확장 ↔ 앱 메시지 규약. 예시는 저장소 루트 `protocol/examples/` (Swift 테스트와 공용). */

export type HelloMessage = { type: 'hello'; extensionVersion: string };

export type JobPageMessage = {
  type: 'jobPage';
  site: string;
  url: string;
  company?: string;
};

export type ExtensionToApp = HelloMessage | JobPageMessage;

export type AckMessage = { type: 'ack'; appVersion: string };

export type AppToExtension = AckMessage;

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
  return isRecord(value) && value.type === 'ack' && typeof value.appVersion === 'string';
}
