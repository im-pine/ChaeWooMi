import Testing
@testable import ChaeWooMiCore

@Suite("종류별 문서 작업 잠금 (AGT-009)")
struct DocumentJobLockTests {
    private let resume = DocumentJob(company: "가상전자(주)", kind: .resume)
    private let coverLetter = DocumentJob(company: "가상전자(주)", kind: .coverLetter)

    @Test("이력서 작업 중에도 자소서 작업을 함께 시작한다")
    func resumeAndCoverLetterTogether() async {
        let lock = DocumentJobLock()
        #expect(await lock.acquire(resume) == .granted)
        #expect(await lock.acquire(coverLetter) == .granted)
    }

    @Test("같은 종류는 회사가 달라도 하나씩만")
    func blocksSameKind() async {
        let lock = DocumentJobLock()
        let other = DocumentJob(company: "가상서점", kind: .resume)
        _ = await lock.acquire(resume)
        #expect(await lock.acquire(other) == .busy(resume))
    }

    @Test("같은 작업을 다시 누르면 중복 실행으로 알린다")
    func duplicateClick() async {
        let lock = DocumentJobLock()
        _ = await lock.acquire(resume)
        #expect(await lock.acquire(resume) == .alreadyRunning)
    }

    @Test("동시에 여러 번 눌러도 종류마다 한 작업만 잡힌다")
    func concurrentAcquire() async {
        let lock = DocumentJobLock()
        let jobs = (0..<20).map { index in
            DocumentJob(company: "가상회사\(index % 5)", kind: index.isMultiple(of: 2) ? .resume : .coverLetter)
        }
        let granted = await withTaskGroup(of: Bool.self) { group in
            for job in jobs { group.addTask { await lock.acquire(job) == .granted } }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(granted == 2)
    }

    @Test("잠금을 풀면 같은 종류의 다른 회사 문서를 시작할 수 있다")
    func releaseThenAcquire() async {
        let lock = DocumentJobLock()
        let other = DocumentJob(company: "가상서점", kind: .resume)
        _ = await lock.acquire(resume)
        #expect(await lock.release(resume))
        #expect(await lock.acquire(other) == .granted)
    }

    @Test("잡고 있지 않은 작업 이름으로는 잠금이 풀리지 않는다")
    func wrongRelease() async {
        let lock = DocumentJobLock()
        _ = await lock.acquire(resume)
        #expect(await lock.release(coverLetter) == false)
        #expect(await lock.current[.resume] == resume)
    }
}
