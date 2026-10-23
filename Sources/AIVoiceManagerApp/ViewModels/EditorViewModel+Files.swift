import Foundation

/// Export Project / Open Project…: a `.avmproject.zip` with every take, or an older `.json` without takes.
extension EditorViewModel {
    /// The project's name as a file name: letters and digits, the rest `-`.
    var fileStem: String {
        let name = draft.title.replacing(/[^\p{L}\p{N}]+/, with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return name.isEmpty ? "project" : name
    }

    /// Export Project: `<title>.avmproject.zip` — the project folder with every take, saved first.
    func exportArchive(to url: URL) throws {
        guard let store else { throw CocoaError(.fileNoSuchFile) }
        try store.save(project)
        try ProjectArchive.zip(store.folder(of: currentID), to: url)
    }

    /// Open Project…: a `.avmproject.zip` (with its takes) or a `.json` (prototype / older export, no takes).
    @discardableResult
    func open(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard name.hasSuffix(".zip") else {
            return open((try? Data(contentsOf: url)) ?? Data(), fileName: name)
        }
        var reader = ProjectArchive.Reader(url)
        let title = name.replacing("." + ProjectArchive.fileExtension, with: "")
        guard let imported = ProjectArchive.read(&reader, fallbackTitle: title) else {
            notice = Notice(text: localized("openFail"))
            return false
        }
        add(imported.draft)
        for (take, takeID) in imported.takes {   // one WAV in memory at a time; a take that isn't a WAV is left out
            guard let wav = reader.data("Takes/\(takeID)/take.wav"), let seconds = wavDuration(wav) else { continue }
            let saved = Take(id: store?.newTakeID(at: take.created, in: currentID) ?? UUID().uuidString,
                             created: take.created, duration: seconds, draft: take.draft, mock: false)
            guard (try? store?.saveTake(saved, wav: wav, in: currentID)) != nil else { continue }
            project.takes.append(saved)
        }
        return true
    }

    /// A project JSON: anything with `items` (or the older `blocks`) is cleaned field by field into a new project.
    @discardableResult
    func open(_ data: Data, fileName: String) -> Bool {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let object, object["items"] is [Any] || object["blocks"] is [Any] else {
            notice = Notice(text: localized("openFail"))
            return false
        }
        add(clean(imported: object, fallbackTitle: fileName.replacing(/\.(avmproject\.)?json$/, with: "")))
        return true
    }
}
