import Foundation

/// Trust boundary (constraints.md): a project file comes from outside. Rebuild it from known shapes only — scene
/// types, speakers S1/S2, expressions, model and voice from the catalogs, strings capped, fresh ids — the prototype's
/// `cleanScript`. Reads both the timeline (`items`) and the older `blocks` format. Never throws: junk → defaults.
func clean(imported object: Any?, fallbackTitle: String) -> ProjectDraft {
    let file = object as? [String: Any] ?? [:]
    func text(_ value: Any?, _ max: Int) -> String { (value as? String).map { String($0.prefix(max)) } ?? "" }
    func speakerID(_ value: Any?) -> SpeakerID { value as? String == "S2" ? .s2 : .s1 }

    let given = file["speakers"] as? [String: Any] ?? [:]
    var speakers: [SpeakerID: Speaker] = [:]
    for (id, defaultName) in zip(SpeakerID.allCases, ["Rami", "Mali"]) {
        let entry = given[id.rawValue] as? [String: Any] ?? [:]
        let voice = entry["voice"] as? String ?? ""
        speakers[id] = Speaker(name: text(entry["name"], 40).isEmpty ? defaultName : text(entry["name"], 40),
                               voice: VoiceCatalog.contains(voice) ? voice : VoiceCatalog.all[0].name)
    }

    var items: [TimelineItem]
    if let list = file["items"] as? [Any] {
        items = list.prefix(1000).map { raw in
            let item = raw as? [String: Any] ?? [:]
            let muted = item["muted"] as? Bool == true
            if item["type"] as? String == "expr" {
                let tag = ExpressionTag(rawValue: item["tag"] as? String ?? "") ?? .breath
                // times: the init clamps to 1…10
                return .expr(ExpressionScene(tag: tag, muted: muted, times: item["times"] as? Int ?? 1))
            }
            return .script(ScriptScene(speaker: speakerID(item["speaker"]), style: text(item["style"], 200),
                                       text: text(item["text"], 10_000), muted: muted))
        }
    } else {
        items = (file["blocks"] as? [Any] ?? []).prefix(500).flatMap { raw in
            let block = raw as? [String: Any] ?? [:]
            return splitIntoItems(text(block["text"], 10_000), speaker: speakerID(block["speaker"]),
                                  style: text(block["style"], 200))
        }
    }
    let model = file["model"] as? String ?? ""
    return ProjectDraft(title: text(file["title"], 200).isEmpty ? fallbackTitle : text(file["title"], 200),
                        model: ModelCatalog.all.contains { $0.id == model } ? model : ModelCatalog.standard.id,
                        speakers: speakers,
                        items: items.isEmpty ? [.script(ScriptScene())] : items)
}
