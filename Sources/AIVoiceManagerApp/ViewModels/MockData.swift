import Foundation

/// The prototype's demo projects (`seedTakes()` / `seedProjects()`): one project per demo, each owning its mock take.
/// Phase 2 runs on these only — no files yet. Screenshots come from here, never from real scripts.
enum MockData {
    static func projects(now: Date = .now) -> [Project] {
        let day = 86_400.0
        let demos = [Demo(id: "t3", age: 3600, duration: 52, draft: swiftUISkills),
                     Demo(id: "t2", age: day + 5000, duration: 31, draft: hostsManager),
                     Demo(id: "t1", age: 4 * day, duration: 44, draft: gitExclude)]
        return demos.map { demo in
            let created = now.addingTimeInterval(-demo.age)
            let take = Take(id: demo.id, created: created, duration: demo.duration, draft: demo.draft, mock: true)
            return Project(id: "p" + demo.id, opened: created, draft: demo.draft, takes: [take], selection: nil)
        }
    }

    private struct Demo { let id: String, age: TimeInterval, duration: Double, draft: ProjectDraft }

    private static let ramiMali: [SpeakerID: Speaker] = [.s1: Speaker(name: "Rami", voice: "Sulafat"),
                                                         .s2: Speaker(name: "Mali", voice: "Kore")]

    static let swiftUISkills = ProjectDraft(
        title: "SwiftUI Mac Skills Pro", model: ModelCatalog.standard.id, speakers: ramiMali,
        items: splitIntoItems("อยากใส่ AI ในแอป Mac แต่ละเจ้าต่างกันหมด ทั้งการ stream ความคิดของโมเดล และการเก็บ key\n<breath>",
                              speaker: .s1, style: "Friendly")
            + splitIntoItems("SwiftUI Mac Skills Pro รวมส่วนที่ยากที่สุดจากแอปจริง ทำเป็น skill สำหรับผู้สนับสนุน\n<breath>",
                             speaker: .s1, style: "Friendly"))

    static let hostsManager = ProjectDraft(
        title: "Hosts Manager v1.1.4 intro", model: ModelCatalog.standard.id, speakers: ramiMali,
        items: splitIntoItems("Still editing /etc/hosts in vim? <short pause> Hosts Manager does it in one click.",
                              speaker: .s1, style: "Excited"))

    static let gitExclude = ProjectDraft(
        title: "Git Exclude Manager — two voices", model: ModelCatalog.standard.id,
        speakers: [.s1: Speaker(name: "Joe", voice: "Puck"), .s2: Speaker(name: "Jane", voice: "Kore")],
        items: splitIntoItems("How's it going today Jane?", speaker: .s1, style: "Cheerful and friendly")
            + splitIntoItems("Not too bad. Ready to hide some files from git?",
                             speaker: .s2, style: "Calm and relaxed"))
}
