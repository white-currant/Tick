import Foundation

struct Folder: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
}

/// Тип листа: чеклист с отметками или памятка-справочник (команды, тезисы).
enum ListKind: String, Codable, CaseIterable, Identifiable {
    case checklist
    case reference

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checklist: "Чеклист"
        case .reference: "Памятка"
        }
    }

    var symbol: String {
        switch self {
        case .checklist: "checklist"
        case .reference: "terminal"
        }
    }
}

struct ChecklistItem: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Что проверить (challenge) или тезис.
    var text: String = ""
    /// Ответ, значение или команда (response). Показывается через точечный лидер.
    var detail: String = ""
    var isDone = false
    /// Заголовок раздела внутри листа — не отмечается, не нумеруется.
    var isSection = false

    init(id: UUID = UUID(), text: String = "", detail: String = "", isDone: Bool = false, isSection: Bool = false) {
        self.id = id
        self.text = text
        self.detail = detail
        self.isDone = isDone
        self.isSection = isSection
    }

    private enum CodingKeys: String, CodingKey { case id, text, detail, isDone, isSection }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        isSection = try c.decodeIfPresent(Bool.self, forKey: .isSection) ?? false
    }
}

struct Checklist: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String = ""
    var kind: ListKind = .checklist
    var folderID: UUID?
    var items: [ChecklistItem] = []
    var createdAt = Date()
    /// Встроенный лист приложения (горячие клавиши) — его нельзя удалить.
    var isBuiltIn = false

    init(id: UUID = UUID(), title: String = "", kind: ListKind = .checklist, folderID: UUID? = nil,
         items: [ChecklistItem] = [], createdAt: Date = Date(), isBuiltIn: Bool = false) {
        self.id = id
        self.title = title
        self.kind = kind
        self.folderID = folderID
        self.items = items
        self.createdAt = createdAt
        self.isBuiltIn = isBuiltIn
    }

    private enum CodingKeys: String, CodingKey { case id, title, kind, folderID, items, createdAt, isBuiltIn }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        kind = try c.decodeIfPresent(ListKind.self, forKey: .kind) ?? .checklist
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        items = try c.decodeIfPresent([ChecklistItem].self, forKey: .items) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? "Без названия" : title
    }

    var actionItems: [ChecklistItem] { items.filter { !$0.isSection } }
    var doneCount: Int { actionItems.filter(\.isDone).count }
    var progress: Double { actionItems.isEmpty ? 0 : Double(doneCount) / Double(actionItems.count) }
    var isComplete: Bool { kind == .checklist && !actionItems.isEmpty && doneCount == actionItems.count }

    /// Порядковый номер пункта без учёта заголовков разделов.
    func number(of item: ChecklistItem) -> Int? {
        guard !item.isSection else { return nil }
        var n = 0
        for i in items {
            if i.isSection { continue }
            n += 1
            if i.id == item.id { return n }
        }
        return nil
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        if title.localizedStandardContains(q) { return true }
        return items.contains { $0.text.localizedStandardContains(q) || $0.detail.localizedStandardContains(q) }
    }

    /// Текстовое представление для буфера обмена.
    var plainText: String {
        var lines: [String] = [displayTitle.uppercased(), ""]
        for item in items {
            if item.isSection {
                lines.append("")
                lines.append(item.text.uppercased())
                continue
            }
            var line = kind == .checklist ? (item.isDone ? "☑ " : "☐ ") : "• "
            line += item.text
            if !item.detail.isEmpty { line += " — " + item.detail }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}

enum FolderSelection: Hashable {
    case all
    case folder(UUID)

    var folderID: UUID? {
        if case .folder(let id) = self { return id }
        return nil
    }
}

enum Mode: String {
    case view
    case edit
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Как в системе"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var next: AppTheme {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }
}
