#if DEBUG
import AppKit

/// Debug 빌드 전용 자가 시험: 설정 창 세션 이름 입력칸이 실제 키 입력을 받는지 확인한다.
/// 손쉬운 사용 권한 없이 확인하려고 앱 안에서 키 이벤트를 보낸다 (다른 프로세스에서 키를 보내려면 권한이 필요).
/// 앱 안에서 보낸 키 이벤트는 창을 지정해 가므로 키 창이 아니어도 들어간다. 실제 사용자 키보드는 키 창으로만 가므로
/// **통과 기준은 설정 창이 키 창이고(`settingsIsKey`) 입력값이 저장되는 것**이다 (`passed`).
/// 실행: `ChaeWooMi -selfTestSettingsTyping <결과 JSON 경로>`
@MainActor
enum SettingsTypingSelfTest {
    static let argument = "-selfTestSettingsTyping"
    static let typed = "qa-typed"

    static func runIfRequested(
        open: @escaping @MainActor () -> NSWindow?,
        readName: @escaping @MainActor () -> String?
    ) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count else { return }
        let output = URL(fileURLWithPath: arguments[index + 1])
        Task { @MainActor in
            // 메뉴바에서 설정을 여는 상황처럼 다른 앱(Finder)이 앞에 있는 상태에서 시작한다
            let finder = "com.apple.finder"
            NSApp.yieldActivation(toApplicationWithBundleIdentifier: finder)
            NSRunningApplication.runningApplications(withBundleIdentifier: finder).first?.activate()
            try? await Task.sleep(for: .seconds(1.5))
            let wasActive = NSApp.isActive
            let window = open()
            try? await Task.sleep(for: .seconds(1))
            let field = window.flatMap { focusFirstTextField(in: $0) }
            if let window { type(typed, into: window) }
            try? await Task.sleep(for: .seconds(1))
            let isKey = window?.isKeyWindow ?? false
            write(output, [
                "passed": isKey && readName() == typed,
                "activeBeforeOpen": wasActive,
                "activeAfterOpen": NSApp.isActive,
                "settingsVisible": window?.isVisible ?? false,
                "settingsIsKey": isKey,
                "keyWindow": NSApp.keyWindow?.title ?? "",
                "fieldFound": field != nil,
                "fieldValue": field?.stringValue ?? "",
                "savedJobAnalysisName": readName() ?? ""
            ])
            NSApp.terminate(nil)
        }
    }

    /// 설정 창의 첫 입력칸(공고 분석 세션 이름)을 비우고 포커스
    private static func focusFirstTextField(in window: NSWindow) -> NSTextField? {
        guard let field = editableFields(in: window.contentView).first else { return nil }
        window.makeFirstResponder(field)
        field.currentEditor()?.selectAll(nil)
        field.currentEditor()?.delete(nil)
        return field
    }

    private static func editableFields(in view: NSView?) -> [NSTextField] {
        guard let view else { return [] }
        let own = (view as? NSTextField).flatMap { $0.isEditable ? [$0] : nil } ?? []
        return own + view.subviews.flatMap { editableFields(in: $0) }
    }

    /// 앱 이벤트 큐에 키 이벤트를 넣는다 → 키 창의 입력칸으로 간다
    private static func type(_ text: String, into window: NSWindow) {
        for character in text.map(String.init) {
            for type in [NSEvent.EventType.keyDown, .keyUp] {
                let event = NSEvent.keyEvent(
                    with: type, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, characters: character,
                    charactersIgnoringModifiers: character, isARepeat: false, keyCode: 0
                )
                if let event { NSApp.postEvent(event, atStart: false) }
            }
        }
    }

    private static func write(_ url: URL, _ report: [String: Any]) {
        let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try? data?.write(to: url)
    }
}
#endif
