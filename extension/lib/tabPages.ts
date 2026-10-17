import type { ApplyButtonMessage, ExtensionToApp, JobPageMessage } from './protocol';

/**
 * 탭마다 마지막 공고 상태를 기억하고, **보고 있는 탭**의 상태만 앱에 보낸다 (WEB-015).
 * 다른 탭으로 옮기면 그 탭의 공고를 보내거나, 공고가 아니면 pageLeft를 보낸다.
 */
export class TabPages {
  private pages = new Map<number, JobPageMessage>();
  private active: number | null = null;

  /** 탭의 공고가 바뀜. 보고 있는 탭이면 앱에 보낼 메시지 */
  posting(tabId: number, page: JobPageMessage): ExtensionToApp | null {
    this.pages.set(tabId, page);
    return tabId === this.active ? page : null;
  }

  /** 탭이 공고가 아닌 페이지로 옮김 */
  left(tabId: number): ExtensionToApp | null {
    const had = this.pages.delete(tabId);
    return tabId === this.active && had ? { type: 'pageLeft' } : null;
  }

  applyButton(tabId: number, covering: boolean): ApplyButtonMessage | null {
    return tabId === this.active ? { type: 'applyButton', covering } : null;
  }

  /** 다른 탭을 보기 시작함 */
  activate(tabId: number): ExtensionToApp {
    this.active = tabId;
    return this.pages.get(tabId) ?? { type: 'pageLeft' };
  }

  /** 보고 있는 탭의 지금 상태 (다시 연결했을 때 보냄) */
  current(): ExtensionToApp {
    return (this.active !== null && this.pages.get(this.active)) || { type: 'pageLeft' };
  }

  /** 탭을 닫음 */
  closed(tabId: number): ExtensionToApp | null {
    return this.left(tabId);
  }
}
