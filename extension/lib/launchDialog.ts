import type { LaunchAnswer } from './launchPrompt';

/** 페이지 스타일과 섞이지 않게 shadow DOM 안에 그린다 */
const STYLE = `
:host { all: initial; }
.backdrop {
  position: fixed; inset: 0; z-index: 2147483647;
  display: flex; align-items: center; justify-content: center;
  background: rgba(15, 23, 20, 0.28);
  font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", sans-serif;
}
.dialog {
  width: 340px; box-sizing: border-box; padding: 22px 22px 18px;
  border-radius: 14px; background: #ffffff; color: #1f2622;
  box-shadow: 0 18px 48px rgba(0, 0, 0, 0.22);
}
.brand { display: flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: #3d7a57; }
h2 { margin: 10px 0 6px; font-size: 17px; font-weight: 700; line-height: 1.4; }
p { margin: 0 0 16px; font-size: 13px; line-height: 1.55; color: #5b645f; }
label { display: inline-flex; align-items: center; gap: 7px; font-size: 13px; color: #3c4540; cursor: pointer; user-select: none; }
input { width: 15px; height: 15px; margin: 0; accent-color: #3d7a57; cursor: pointer; }
.actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 18px; }
button {
  min-width: 84px; height: 34px; padding: 0 14px; border-radius: 8px;
  font: inherit; font-size: 13px; font-weight: 600; cursor: pointer; user-select: none;
}
button:focus-visible, input:focus-visible { outline: 2px solid #3d7a57; outline-offset: 2px; }
.secondary { border: 1px solid #d6dbd8; background: #ffffff; color: #3c4540; }
.secondary:hover { background: #f2f4f3; }
.primary { border: 1px solid #3d7a57; background: #3d7a57; color: #ffffff; }
.primary:hover { background: #336a4b; }
@media (prefers-color-scheme: dark) {
  .dialog { background: #23292a; color: #eef1ef; }
  p { color: #aab3ae; }
  label { color: #d5dbd7; }
  .secondary { border-color: #444d4a; background: #23292a; color: #e1e6e3; }
  .secondary:hover { background: #2d3433; }
}
`;

const LEAF =
  '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/></svg>';

/**
 * "채우미 앱을 실행하시겠습니까?" 확인창. 고른 답으로 끝난다.
 * "오늘 하루 묻지 않기"는 기본 체크. Esc는 "열지 않음"과 같다
 */
export function showLaunchDialog(doc: Document): Promise<LaunchAnswer> {
  const host = doc.createElement('chaewoomi-launch-dialog');
  const root = host.attachShadow({ mode: 'open' });
  root.innerHTML = `
    <style>${STYLE}</style>
    <div class="backdrop">
      <div class="dialog" role="dialog" aria-modal="true" aria-labelledby="title" aria-describedby="desc">
        <div class="brand">${LEAF}채우미</div>
        <h2 id="title">채우미 앱을 실행하시겠습니까?</h2>
        <p id="desc">이 공고의 회사에 1년 안에 지원했는지 확인하고, 이력서 · 자기소개서를 바로 요청할 수 있습니다.</p>
        <label><input type="checkbox" checked>오늘 하루 묻지 않기</label>
        <div class="actions">
          <button type="button" class="secondary" data-answer="close">열지 않음</button>
          <button type="button" class="primary" data-answer="open">열기</button>
        </div>
      </div>
    </div>`;
  doc.documentElement.append(host);
  const checkbox = root.querySelector('input')!;
  const openButton = root.querySelector<HTMLButtonElement>('[data-answer="open"]')!;
  const closeButton = root.querySelector<HTMLButtonElement>('[data-answer="close"]')!;
  openButton.focus();

  return new Promise((resolve) => {
    const finish = (open: boolean) => {
      doc.removeEventListener('keydown', onKey, true);
      host.remove();
      resolve({ open, skipToday: checkbox.checked });
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      event.stopPropagation();
      finish(false);
    };
    doc.addEventListener('keydown', onKey, true);
    openButton.addEventListener('click', () => finish(true));
    closeButton.addEventListener('click', () => finish(false));
  });
}
