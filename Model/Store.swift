import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class Store {
    var folders: [Folder] = []
    var checklists: [Checklist] = []

    /// Папка с данными: контейнер приложения или выбранная пользователем.
    private(set) var directory: URL
    private(set) var usesCustomFolder = false

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var scopedURL: URL?

    static let fileName = "checklists.json"
    private static let bookmarkKey = "dataFolderBookmark"

    private struct Document: Codable {
        var folders: [Folder]
        var checklists: [Checklist]
    }

    static var defaultDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Tick", isDirectory: true)
    }

    var fileURL: URL { directory.appendingPathComponent(Self.fileName) }

    init() {
        directory = Self.defaultDirectory
        if let custom = resolveBookmark() {
            directory = custom
            usesCustomFolder = true
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
        observeChanges()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let document = try? JSONDecoder.tick.decode(Document.self, from: data)
        else {
            seed()
            return
        }
        folders = document.folders
        checklists = document.checklists
        ensureBuiltIn()
    }

    private func seed() {
        let work = addFolder(named: "Работа")
        checklists = [
            Checklist(
                title: "Перед публикацией",
                kind: .checklist,
                folderID: work.id,
                items: [
                    ChecklistItem(text: "Сборка", isSection: true),
                    ChecklistItem(text: "Тесты", detail: "зелёные"),
                    ChecklistItem(text: "Версия и changelog", detail: "обновлены"),
                    ChecklistItem(text: "Проверка", isSection: true),
                    ChecklistItem(text: "Свежая установка", detail: "запускается"),
                    ChecklistItem(text: "Скриншоты", detail: "актуальны"),
                    ChecklistItem(text: "Тег в git", detail: "поставлен"),
                ]
            ),
            Checklist(
                title: "Терминал",
                kind: .reference,
                folderID: work.id,
                items: [
                    ChecklistItem(text: "Занятые порты", detail: "lsof -i -P | grep LISTEN"),
                    ChecklistItem(text: "Размер папок", detail: "du -sh * | sort -h"),
                    ChecklistItem(text: "Кто держит файл", detail: "lsof +D ."),
                    ChecklistItem(text: "Убить процесс по имени", detail: "pkill -x Имя"),
                ]
            ),
            Self.hotkeysChecklist(),
        ]
    }

    static let hotkeysTitle = "Горячие клавиши Tick"

    static func hotkeysChecklist() -> Checklist {
        Checklist(
            title: hotkeysTitle,
            kind: .reference,
            items: [
                ChecklistItem(text: "Просмотр / правка", detail: "⌘E"),
                ChecklistItem(text: "Новый чеклист", detail: "⌘N"),
                ChecklistItem(text: "Новая памятка", detail: "⌘⌥N"),
                ChecklistItem(text: "Новая папка", detail: "⌘⇧N"),
                ChecklistItem(text: "Поиск", detail: "⌘F"),
                ChecklistItem(text: "Скопировать весь лист", detail: "⌘⇧C"),
                ChecklistItem(text: "Сбросить отметки", detail: "⌘⇧R"),
                ChecklistItem(text: "Удалить лист", detail: "⌘⌫"),
                ChecklistItem(text: "В просмотре", isSection: true),
                ChecklistItem(text: "Копировать значение пункта", detail: "клик по пункту"),
                ChecklistItem(text: "Другой лист", detail: "☰ или ⌘F"),
                ChecklistItem(text: "В правке", isSection: true),
                ChecklistItem(text: "Новый пункт", detail: "↩"),
                ChecklistItem(text: "Перенос строки в пункте", detail: "⌥↩"),
                ChecklistItem(text: "Удалить пустой пункт", detail: "⌫"),
                ChecklistItem(text: "Из текста к значению и обратно", detail: "⇥ / ⇧⇥"),
                ChecklistItem(text: "Переставить пункт", detail: "тащить за ≡"),
            ],
            isBuiltIn: true
        )
    }

    /// Встроенный лист с горячими клавишами должен быть всегда: помечаем
    /// существующий по названию или добавляем заново.
    private func ensureBuiltIn() {
        if checklists.contains(where: \.isBuiltIn) { return }
        if let index = checklists.firstIndex(where: { $0.title == Self.hotkeysTitle }) {
            checklists[index].isBuiltIn = true
        } else {
            checklists.append(Self.hotkeysChecklist())
        }
        save()
    }

    private func observeChanges() {
        withObservationTracking {
            _ = folders
            _ = checklists
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scheduleSave()
                self.observeChanges()
            }
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func save() {
        let document = Document(folders: folders, checklists: checklists)
        guard let data = try? JSONEncoder.tick.encode(document) else { return }
        backupIfNeeded()
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Раз в день откладывает копию файла в `backups/`, хранит последние десять.
    private func backupIfNeeded() {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else { return }
        let backups = directory.appendingPathComponent("backups", isDirectory: true)
        try? manager.createDirectory(at: backups, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let target = backups.appendingPathComponent("checklists-\(formatter.string(from: Date())).json")
        guard !manager.fileExists(atPath: target.path) else { return }
        try? manager.copyItem(at: fileURL, to: target)

        let old = ((try? manager.contentsOfDirectory(atPath: backups.path)) ?? [])
            .filter { $0.hasPrefix("checklists-") }
            .sorted()
            .dropLast(10)
        for name in old {
            try? manager.removeItem(at: backups.appendingPathComponent(name))
        }
    }

    // MARK: Папка с данными

    func revealDataInFinder() {
        save()
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    func hasData(in folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(Self.fileName).path)
    }

    /// Переносит хранилище в выбранную папку. `adoptExisting` — открыть файл,
    /// который там уже лежит, вместо того чтобы заменить его текущими данными.
    func useFolder(_ url: URL, adoptExisting: Bool) throws {
        saveTask?.cancel()
        save()
        let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
        releaseScope()
        _ = url.startAccessingSecurityScopedResource()
        scopedURL = url
        directory = url
        usesCustomFolder = true
        if adoptExisting {
            load()
        } else {
            save()
        }
    }

    func useDefaultFolder() {
        saveTask?.cancel()
        save()
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        releaseScope()
        directory = Self.defaultDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        usesCustomFolder = false
        save()
    }

    private func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource()
        else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
        }
        scopedURL = url
        return url
    }

    private func releaseScope() {
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }

    // MARK: Folders

    @discardableResult
    func addFolder(named name: String) -> Folder {
        let folder = Folder(name: name.isEmpty ? "Новая папка" : name)
        folders.append(folder)
        return folder
    }

    func renameFolder(_ id: UUID, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        folders[index].name = trimmed.isEmpty ? folders[index].name : trimmed
    }

    func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        for index in checklists.indices where checklists[index].folderID == id {
            checklists[index].folderID = nil
        }
    }

    func folder(_ id: UUID?) -> Folder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    // MARK: Checklists

    @discardableResult
    func addChecklist(in folderID: UUID?, kind: ListKind = .checklist) -> Checklist {
        let checklist = Checklist(kind: kind, folderID: folderID, items: [ChecklistItem()])
        checklists.insert(checklist, at: 0)
        return checklist
    }

    func deleteChecklist(_ id: UUID) {
        checklists.removeAll { $0.id == id && !$0.isBuiltIn }
    }

    func canDelete(_ id: UUID) -> Bool {
        !(checklists.first { $0.id == id }?.isBuiltIn ?? false)
    }

    @discardableResult
    func duplicateChecklist(_ id: UUID) -> Checklist? {
        guard let index = checklists.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = checklists[index]
        copy.id = UUID()
        copy.title = copy.displayTitle + " (копия)"
        copy.items = copy.items.map { ChecklistItem(text: $0.text, detail: $0.detail, isSection: $0.isSection) }
        copy.createdAt = Date()
        checklists.insert(copy, at: index + 1)
        return copy
    }

    func move(_ id: UUID, to folderID: UUID?) {
        guard let index = checklists.firstIndex(where: { $0.id == id }) else { return }
        checklists[index].folderID = folderID
    }

    func resetChecklist(_ id: UUID) {
        guard let index = checklists.firstIndex(where: { $0.id == id }) else { return }
        for i in checklists[index].items.indices {
            checklists[index].items[i].isDone = false
        }
    }

    func checklists(in selection: FolderSelection) -> [Checklist] {
        switch selection {
        case .all: return checklists
        case .folder(let id): return checklists.filter { $0.folderID == id }
        }
    }

    func contains(_ id: UUID) -> Bool {
        checklists.contains { $0.id == id }
    }

    /// Привязка к чеклисту по id. Если чеклист удалён, запись игнорируется.
    func binding(for id: UUID) -> Binding<Checklist>? {
        guard let index = checklists.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in
                guard let self, index < self.checklists.count, self.checklists[index].id == id else {
                    return self?.checklists.first { $0.id == id } ?? Checklist()
                }
                return self.checklists[index]
            },
            set: { [weak self] value in
                guard let self, let i = self.checklists.firstIndex(where: { $0.id == id }) else { return }
                self.checklists[i] = value
            }
        )
    }
}

extension JSONEncoder {
    static var tick: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var tick: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// Диалоги выбора папки с данными.
@MainActor
enum DataFolderPicker {
    static func choose(for store: Store) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Выбрать"
        panel.message = "Папка, где Tick будет хранить checklists.json и ежедневные копии."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var adopt = false
        if store.hasData(in: url) {
            let alert = NSAlert()
            alert.messageText = "В папке уже есть checklists.json"
            alert.informativeText = "Открыть эти данные или заменить их текущими листами? Прежний файл в старой папке останется на месте."
            alert.addButton(withTitle: "Открыть существующие")
            alert.addButton(withTitle: "Заменить текущими")
            alert.addButton(withTitle: "Отмена")
            switch alert.runModal() {
            case .alertFirstButtonReturn: adopt = true
            case .alertSecondButtonReturn: adopt = false
            default: return
            }
        }
        do {
            try store.useFolder(url, adoptExisting: adopt)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    static func useDefault(_ store: Store) {
        store.useDefaultFolder()
    }
}
