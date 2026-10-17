import Darwin
import Foundation

/// 소켓 · 파이프에서 줄 단위로 읽는다.
///
/// 막히는 `read`를 전용 스레드에서 한다. `FileHandle.bytes`로 읽으면 기다리는 동안 Swift 동시성 스레드 풀을 붙잡고,
/// `FileHandle.read(upToCount:)`는 요청한 크기가 다 찰 때까지 돌아오지 않아 짧은 줄이 전달되지 않는다.
/// 시스템 `read`는 온 만큼 바로 돌려준다.
enum LineReader {
    static func lines(from handle: FileHandle) -> AsyncStream<String> {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        Thread.detachNewThread {
            // 스레드가 끝날 때까지 handle을 붙잡아 파일 기술자가 먼저 닫히지 않게 한다
            withExtendedLifetime(handle) {
                readLines(descriptor: handle.fileDescriptor) { continuation.yield($0) }
            }
            continuation.finish()
        }
        return stream
    }

    private static func readLines(descriptor: Int32, emit: (String) -> Void) {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(descriptor, &chunk, chunk.count)
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { return }
            buffer.append(contentsOf: chunk[0..<count])
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                if let line = String(bytes: buffer[buffer.startIndex..<newline], encoding: .utf8) {
                    emit(line)
                }
                buffer.removeSubrange(buffer.startIndex...newline)
            }
        }
    }
}
