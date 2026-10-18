/** 확장 ↔ 앱 메시지 규약. 예시는 저장소 루트 `protocol/examples/` (Swift 테스트와 공용). */
import { configProblems, type SiteConfig } from './siteConfig';

export type HelloMessage = { type: 'hello'; extensionVersion: string };

/**
 * 지정 사이트 공고 (WEB-003 · 004 · 016). 회사명 후보는 구조화 데이터 → 메타 → DOM 순.
 * 후보가 비면 추출 실패 → 앱이 수동 카드를 띄운다 (WEB-007). 공고 원문이 없으면 `postingText`를 빼서 없음을 알린다.
 */
export type JobPageMessage = {
  type: 'jobPage';
  site: string;
  url: string;
  companies: string[];
  title?: string;
  postingText?: string;
};

/** 공고가 아닌 페이지로 옮김 · 공고 탭을 벗어남 → 앱은 이전 회사 결과를 지운다 (WEB-015) */
export type PageLeftMessage = { type: 'pageLeft' };

/** 지원 버튼이 카드 자리를 가리는가 (APP-015) */
export type ApplyButtonMessage = { type: 'applyButton'; covering: boolean };

/**
 * 지원 완료 화면 감지 (HIS-017). 완료 화면은 공고 주소가 아닐 수 있어 가장 최근 공고의 회사 정보를 싣는다.
 * 앱이 5초 카운트다운 뒤 12.0 기록을 요청한다. 공고 원문은 싣지 않는다
 */
export type ApplyCompleteMessage = {
  type: 'applyComplete';
  site: string;
  url: string;
  companies: string[];
  title?: string;
};

export type ExtensionToApp =
  HelloMessage | JobPageMessage | PageLeftMessage | ApplyButtonMessage | ApplyCompleteMessage;

export type AckMessage = { type: 'ack'; appVersion: string };

/** 앱 소유 지원 사이트 설정 (WEB-014) */
export type SiteConfigMessage = { type: 'siteConfig'; config: SiteConfig };

/** 지금 보고 있는 탭을 다시 읽어 달라 (카드의 "지원 이력 확인" 버튼) */
export type RescanMessage = { type: 'rescan' };

export type AppToExtension = AckMessage | SiteConfigMessage | RescanMessage;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isOptionalString(value: unknown): boolean {
  return value === undefined || typeof value === 'string';
}

const isStrings = (value: unknown) =>
  Array.isArray(value) && value.every((item) => typeof item === 'string');

function isJobPage(value: Record<string, unknown>): boolean {
  return (
    typeof value.site === 'string' &&
    typeof value.url === 'string' &&
    isStrings(value.companies) &&
    isOptionalString(value.title) &&
    isOptionalString(value.postingText)
  );
}

/** 앱으로 보내는 메시지 모양 검사 */
export function isExtensionToApp(value: unknown): value is ExtensionToApp {
  if (!isRecord(value)) return false;
  switch (value.type) {
    case 'hello':
      return typeof value.extensionVersion === 'string';
    case 'jobPage':
      return isJobPage(value);
    case 'pageLeft':
      return true;
    case 'applyButton':
      return typeof value.covering === 'boolean';
    case 'applyComplete':
      return (
        typeof value.site === 'string' &&
        typeof value.url === 'string' &&
        isStrings(value.companies) &&
        isOptionalString(value.title)
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
  if (value.type === 'rescan') return true;
  return false;
}
