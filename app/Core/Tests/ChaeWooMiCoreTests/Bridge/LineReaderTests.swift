import Foundation
import Testing
@testable import ChaeWooMiCore

@Suite("줄 읽기")
struct LineReaderTests {
    @Test("상대가 닫지 않아도 짧은 줄을 바로 넘긴다")
    func shortLineWithoutEOF() async throws {
        let pipe = Pipe()
        let lines = LineReader.lines(from: pipe.fileHandleForReading)
        try pipe.fileHandleForWriting.write(contentsOf: Data("a\n".utf8))

        var iterator = lines.makeAsyncIterator()
        #expect(await iterator.next() == "a")
        try pipe.fileHandleForWriting.close()
    }

    @Test("여러 번 나눠 온 글자를 줄로 모으고, 닫히면 끝난다")
    func splitChunksAndEOF() async throws {
        let pipe = Pipe()
        let lines = LineReader.lines(from: pipe.fileHandleForReading)
        try pipe.fileHandleForWriting.write(contentsOf: Data("가상".utf8))
        try pipe.fileHandleForWriting.write(contentsOf: Data("전자\n둘째\n".utf8))
        try pipe.fileHandleForWriting.close()

        var received: [String] = []
        for await line in lines { received.append(line) }
        #expect(received == ["가상전자", "둘째"])
    }
}
