import Foundation
import Testing
@testable import ChaeWooMiCore

@Suite("역할 세션 연결 · 꺼짐 감지")
struct SessionRoleTests {
    @Test("역할은 JOB-ANALYSIS · RESUME · APPLICATION 세 개이고 CAREER-DB는 없다")
    func threeRoles() {
        let names = SessionRole.allCases.map(\.defaultSessionName)
        #expect(names == ["Brain_of_Pine/JobAnalysis", "Brain_of_Pine/Resume", "Brain_of_Pine/Application"])
    }

    @Test("역할마다 다른 세션 이름을 지정할 수 있다")
    func perRoleNames() {
        var roster = SessionRoster.defaults
        roster.set("resume-company-a", for: .resume)
        #expect(roster.name(for: .resume) == "resume-company-a")
        #expect(roster.name(for: .jobAnalysis) == "Brain_of_Pine/JobAnalysis")
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
        roster.set("Brain_of_Pine/Resume", for: .application)
        #expect(roster.problems == [.duplicated("Brain_of_Pine/Resume", [.resume, .application])])
    }

    @Test("설정은 역할 이름을 키로 한 JSON으로 저장 · 복원된다")
    func codable() throws {
        let data = try JSONEncoder().encode(SessionRoster.defaults)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let names = object?["names"] as? [String: String]
        #expect(names?["resume"] == "Brain_of_Pine/Resume")
        #expect(try JSONDecoder().decode(SessionRoster.self, from: data) == .defaults)
    }

    @Test("목록에 이름이 있으면 연결됨, 없으면 꺼짐, 설정 없으면 설정 안 됨")
    func availability() {
        var roster = SessionRoster.defaults
        roster.set("", for: .application)
        let listed = ["Brain_of_Pine/JobAnalysis", "other-session"]
        #expect(SessionAvailability.resolve(role: .jobAnalysis, roster: roster, listed: listed)
            == .connected(sessionName: "Brain_of_Pine/JobAnalysis"))
        let resume = SessionAvailability.resolve(role: .resume, roster: roster, listed: listed)
        #expect(resume == .off(sessionName: "Brain_of_Pine/Resume"))
        #expect(SessionAvailability.resolve(role: .application, roster: roster, listed: listed) == .notConfigured)
    }

    @Test("세션이 꺼져 있으면 요청을 보내지 않고 세션 열기 안내를 돌려준다 (QA-027)")
    func gateRefusesWhenOff() {
        let decision = SessionRequestGate.decide(
            role: .resume,
            roster: .defaults,
            listed: ["Brain_of_Pine/JobAnalysis"]
        )
        let guidance = "이력서 (RESUME) 세션이 꺼져 있습니다. 터미널에서 `claude --name Brain_of_Pine/Resume`로 세션을 여세요"
        #expect(decision == .refuse(guidance: guidance))
    }

    @Test("세션이 열려 있으면 설정한 이름으로 보낸다")
    func gateSendsWhenConnected() {
        let decision = SessionRequestGate.decide(role: .resume, roster: .defaults, listed: ["Brain_of_Pine/Resume"])
        #expect(decision == .send(sessionName: "Brain_of_Pine/Resume"))
    }

    @Test("이름 일부만 같은 세션은 연결로 치지 않는다")
    func exactMatch() {
        let listed = ["Brain_of_Pine/Resume-old", "Brain_of_Pine"]
        let decision = SessionRequestGate.decide(role: .resume, roster: .defaults, listed: listed)
        guard case .refuse = decision else {
            Issue.record("부분 일치 세션에 요청을 보내려 함: \(decision)")
            return
        }
    }
}

@Suite("세션 이름 기본값 옮기기")
struct SessionRosterMigrationTests {
    @Test("기본 이름은 Brain_of_Pine/역할 형식이다")
    func defaults() {
        #expect(SessionRoster.defaults.name(for: .jobAnalysis) == "Brain_of_Pine/JobAnalysis")
        #expect(SessionRoster.defaults.name(for: .resume) == "Brain_of_Pine/Resume")
        #expect(SessionRoster.defaults.name(for: .application) == "Brain_of_Pine/Application")
    }

    @Test("옛 기본 이름 그대로인 역할만 새 기본 이름으로 옮기고 직접 바꾼 이름은 둔다")
    func migratesOnlyLegacyDefaults() {
        let stored = SessionRoster(names: [
            .jobAnalysis: "job-analysis", .resume: "my-resume", .application: "application"
        ])
        let migrated = stored.migratingLegacyDefaults()
        #expect(migrated.name(for: .jobAnalysis) == "Brain_of_Pine/JobAnalysis")
        #expect(migrated.name(for: .resume) == "my-resume")
        #expect(migrated.name(for: .application) == "Brain_of_Pine/Application")
    }
}
