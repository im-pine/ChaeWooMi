import Foundation

/// Chrome Native Messaging 틀: 4바이트 길이(리틀 엔디언) + UTF-8 JSON.
public enum NativeMessageFraming {
    /// 호스트 → Chrome 메시지 최대 크기 (Chrome 규격 1MB)
    public static let maxOutgoingBytes = 1_048_576

    public enum FramingError: Error, Equatable {
        case tooLarge(Int)
    }

    public static func frame(_ json: Data) throws(FramingError) -> Data {
        guard json.count <= maxOutgoingBytes else { throw .tooLarge(json.count) }
        var length = UInt32(json.count).littleEndian
        var framed = Data(bytes: &length, count: 4)
        framed.append(json)
        return framed
    }

    /// 버퍼 앞의 완성된 메시지 하나를 꺼낸다. 아직 덜 왔으면 nil이고 버퍼는 그대로다.
    public static func takeMessage(from buffer: inout Data) -> Data? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.prefix(4).enumerated().reduce(0) { sum, byte in
            sum | Int(byte.element) << (8 * byte.offset)
        }
        guard buffer.count >= 4 + length else { return nil }
        let start = buffer.startIndex + 4
        let message = buffer[start..<start + length]
        buffer = Data(buffer[(start + length)...])
        return Data(message)
    }

    /// 표준 입력 등에서 메시지 하나를 읽는다. 끝(EOF)이면 nil
    public static func readMessage(from handle: FileHandle) -> Data? {
        guard let header = try? handle.read(upToCount: 4), header.count == 4 else { return nil }
        var buffer = header
        let length = header.enumerated().reduce(0) { $0 | Int($1.element) << (8 * $1.offset) }
        while buffer.count < 4 + length {
            guard let chunk = try? handle.read(upToCount: 4 + length - buffer.count), !chunk.isEmpty else { return nil }
            buffer.append(chunk)
        }
        return takeMessage(from: &buffer)
    }
}
