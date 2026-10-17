import Darwin
import Foundation

public enum UnixSocketError: Error, Equatable {
    case pathTooLong
    case socket(Int32)
    case bind(Int32)
    case listen(Int32)
    case connect(Int32)
}

/// 앱 ↔ 호스트 사이의 Unix 도메인 소켓. 같은 사용자만 접근하도록 파일 권한을 0600으로 둔다.
enum UnixSocket {
    static func listen(path: String) throws(UnixSocketError) -> Int32 {
        var address = try makeAddress(path)
        unlink(path)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw .socket(errno) }
        let bound = withSockaddr(&address) { bind(descriptor, $0, $1) }
        guard bound == 0 else {
            let code = errno
            close(descriptor)
            throw .bind(code)
        }
        chmod(path, 0o600)
        guard Darwin.listen(descriptor, 8) == 0 else {
            let code = errno
            close(descriptor)
            throw .listen(code)
        }
        return descriptor
    }

    static func connect(path: String) throws(UnixSocketError) -> Int32 {
        var address = try makeAddress(path)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw .socket(errno) }
        let connected = withSockaddr(&address) { Darwin.connect(descriptor, $0, $1) }
        guard connected == 0 else {
            let code = errno
            close(descriptor)
            throw .connect(code)
        }
        return descriptor
    }

    private static func makeAddress(_ path: String) throws(UnixSocketError) -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw .pathTooLong }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    private static func withSockaddr<T>(
        _ address: inout sockaddr_un,
        _ body: (UnsafePointer<sockaddr>, socklen_t) -> T
    ) -> T {
        withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }
}
