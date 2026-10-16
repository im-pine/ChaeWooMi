import Foundation
import Testing
@testable import ChaeWooMiCore

@Suite("역할 세션 연결 · 꺼짐 감지")
struct SessionRoleTests {
    @Test("역할은 JOB-ANALYSIS · RESUME · APPLICATION 세 개이고 CAREER-DB는 없다")
    func threeRoles() {
        #expect(SessionRole.allCases.map(\.defaultSessionName) == ["job-analysis", "resume", "application"])
    }

    @Test("역할마다 다른 세션 이름을 지정할 수 있다")
    func perRoleNames() {
        var roster = SessionRoster.defaults
        roster.set("resume-company-a", for: .resume)
        #expect(roster.name(for: .resume) == "resume-company-a")
        #expect(roster.name(for: .jobAnalysis) == "job-analysis")
        #expect(roster.problems.isEmpty)
    }

    @Test("이름이 비었거나 공백이면 그 역할은 설정 안 됨")
    func missingName() {
        var roster = SessionRoster.defaults
        roster.set("  ", for: .application)
        #expect(roster.name(for: .application) == nil)
        #expect(roster.problems == [.missing(.application)])
    }

    @Test("두 역할이 같은 세션을 가리키면 문제로 알린다")
    func duplicatedName() {
        var roster = SessionRoster.defaults
        roster.set("resume", for: .application)
        #expect(roster.problems == [.duplicated("resume", [.resume, .application])])
    }

    @Test("설정은 역할 이름을 키로 한 JSON으로 저장 · 복원된다")
    func codable() throws {
        let data = try JSONEncoder().encode(SessionRoster.defaults)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let names = object?["names"] as? [String: String]
        #expect(names?["resume"] == "resume")
        #expect(try JSONDecoder().decode(SessionRoster.self, from: data) == .defaults)
    }

    @Test("목록에 이름이 있으면 연결됨, 없으면 꺼짐, 설정 없으면 설정 안 됨")
    func availability() {
        var roster = SessionRoster.defaults
        roster.set("", for: .application)
        let listed = ["job-analysis", "other-session"]
        #expect(SessionAvailability.resolve(role: .jobAnalysis, roster: roster, listed: listed)
            == .connected(sessionName: "job-analysis"))
        let resume = SessionAvailability.resolve(role: .resume, roster: roster, listed: listed)
        #expect(resume == .off(sessionName: "resume"))
        #expect(SessionAvailability.resolve(role: .application, roster: roster, listed: listed) == .notConfigured)
    }

    @Test("세션이 꺼져 있으면 요청을 보내지 않고 세션 열기 안내를 돌려준다 (QA-027)")
    func gateRefusesWhenOff() {
        let decision = SessionRequestGate.decide(role: .resume, roster: .defaults, listed: ["job-analysis"])
        #expect(decision == .refuse(guidance: "이력서 (RESUME) 세션이 꺼져 있습니다. 터미널에서 `claude --name resume`로 세션을 여세요"))
    }

    @Test("세션이 열려 있으면 설정한 이름으로 보낸다")
    func gateSendsWhenConnected() {
        let decision = SessionRequestGate.decide(role: .resume, roster: .defaults, listed: ["resume"])
        #expect(decision == .send(sessionName: "resume"))
    }

    @Test("이름 일부만 같은 세션은 연결로 치지 않는다")
    func exactMatch() {
        let decision = SessionRequestGate.decide(role: .resume, roster: .defaults, listed: ["resume-old", "my resume"])
        guard case .refuse = decision else {
            Issue.record("부분 일치 세션에 요청을 보내려 함: \(decision)")
            return
        }
    }
}
