import CoreServices
import Foundation

/// 볼트 폴더 변경 감시 (FSEvents, 폴링 없음). 12.0 · 공고.md · 산출물이 바뀌면 다시 계산한다.
@MainActor
final class VaultWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: @MainActor () -> Void

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    /// 여러 폴더를 한 스트림으로 감시한다 (지원 현황 · 공고 분석 · 산출물 폴더가 따로 있을 수 있음)
    func watch(_ folders: [URL]) {
        stop()
        guard !folders.isEmpty else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<VaultWatcher>.fromOpaque(info).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.onChange() }
        }
        // 0.5초 안에 몰려온 변경은 한 번으로 묶는다
        stream = FSEventStreamCreate(
            nil, callback, &context, folders.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        )
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
