import { describeState, type ConnectionState } from '@/lib/native';

/** 확장 아이콘 팝업: 앱 연결 상태와, 설정에 추가된 사이트의 권한 승인 (WEB-002 · SET-005) */
async function render() {
  const { connection, missingOrigins } = await browser.storage.session.get([
    'connection',
    'missingOrigins',
  ]);
  const state = (connection as ConnectionState | undefined) ?? { kind: 'connecting' };
  document.querySelector('#connection')!.textContent = describeState(state);

  const missing = (missingOrigins as string[] | undefined) ?? [];
  const section = document.querySelector<HTMLElement>('#permissions')!;
  section.hidden = missing.length === 0;
  document
    .querySelector('#origins')!
    .replaceChildren(
      ...missing.map((origin) =>
        Object.assign(document.createElement('li'), { textContent: origin }),
      ),
    );
  // 권한 요청은 사용자 클릭 안에서만 할 수 있다. 승인하면 background가 콘텐츠 스크립트를 다시 등록한다
  document.querySelector<HTMLButtonElement>('#grant')!.onclick = async () => {
    await browser.permissions.request({ origins: missing });
    await render();
  };
}

void render();
