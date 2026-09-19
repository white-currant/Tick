import Foundation
import CoreGraphics

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

/// Дополнительное значение пункта: пункт может нести несколько команд или ответов.
struct SubItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var text = ""
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
    /// Подпункты: ещё значения под тем же названием, после основного `detail`.
    var subitems: [SubItem] = []

    init(id: UUID = UUID(), text: String = "", detail: String = "", isDone: Bool = false,
         isSection: Bool = false, subitems: [SubItem] = []) {
        self.id = id
        self.text = text
        self.detail = detail
        self.isDone = isDone
        self.isSection = isSection
        self.subitems = subitems
    }

    /// Подпункты с текстом: пустые заготовки в правке не показываем и не копируем.
    var filledSubitems: [SubItem] { subitems.filter { !$0.text.isEmpty } }

    /// Весь пункт для копирования: название и все значения, каждое с новой строки.
    var wholeText: String {
        ([text] + (detail.isEmpty ? [] : [detail]) + filledSubitems.map(\.text)).joined(separator: "\n")
    }

    private enum CodingKeys: String, CodingKey { case id, text, detail, isDone, isSection, subitems }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        isSection = try c.decodeIfPresent(Bool.self, forKey: .isSection) ?? false
        subitems = try c.decodeIfPresent([SubItem].self, forKey: .subitems) ?? []
    }
}

struct Checklist: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String = ""
    var kind: ListKind = .checklist
    var folderID: UUID?
    var items: [ChecklistItem] = []
    var createdAt = Date()
    /// Встроенный лист приложения (инструкция, горячие клавиши) — его нельзя удалить.
    var isBuiltIn = false
    /// Какой именно встроенный лист это: не зависит от названия, которое можно поменять.
    var templateKey: String?

    init(id: UUID = UUID(), title: String = "", kind: ListKind = .checklist, folderID: UUID? = nil,
         items: [ChecklistItem] = [], createdAt: Date = Date(), isBuiltIn: Bool = false,
         templateKey: String? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.folderID = folderID
        self.items = items
        self.createdAt = createdAt
        self.isBuiltIn = isBuiltIn
        self.templateKey = templateKey
    }

    private enum CodingKeys: String, CodingKey { case id, title, kind, folderID, items, createdAt, isBuiltIn, templateKey }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        kind = try c.decodeIfPresent(ListKind.self, forKey: .kind) ?? .checklist
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        items = try c.decodeIfPresent([ChecklistItem].self, forKey: .items) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        templateKey = try c.decodeIfPresent(String.self, forKey: .templateKey)
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? "Без названия" : title
    }

    var actionItems: [ChecklistItem] { items.filter { !$0.isSection } }
    var doneCount: Int { actionItems.filter(\.isDone).count }
    var progress: Double { actionItems.isEmpty ? 0 : Double(doneCount) / Double(actionItems.count) }
    var isComplete: Bool { kind == .checklist && !actionItems.isEmpty && doneCount == actionItems.count }

    /// Нумерация: разделы 1, 2, 3; пункт — номер раздела и свой (2.1); без разделов — 01, 02.
    /// Подпункты добавляют ещё один номер (2.1.1); основное значение при них — первое.
    var numbering: Numbering {
        var labels: [UUID: String] = [:]
        let hasSections = items.contains { $0.isSection }
        var section = 0
        var count = 0
        var longest = 2
        for item in items {
            if item.isSection {
                section += 1
                count = 0
                labels[item.id] = "\(section)"
                continue
            }
            count += 1
            let label = !hasSections ? String(format: "%02d", count)
                : section == 0 ? "\(count)" : "\(section).\(count)"
            labels[item.id] = label
            longest = max(longest, label.count)
            let subs = item.filledSubitems.count
            if subs > 0 {
                let last = (item.detail.isEmpty ? 0 : 1) + subs
                longest = max(longest, label.count + 1 + String(last).count)
            }
        }
        return Numbering(labels: labels, width: max(20, CGFloat(longest) * 6.8 + 2))
    }

    struct Numbering {
        var labels: [UUID: String]
        /// Ширина колонки номеров: по самому длинному номеру листа.
        var width: CGFloat
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        if title.localizedStandardContains(q) { return true }
        return items.contains {
            $0.text.localizedStandardContains(q) || $0.detail.localizedStandardContains(q)
                || $0.subitems.contains { $0.text.localizedStandardContains(q) }
        }
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
            for sub in item.filledSubitems { lines.append("    ↳ " + sub.text) }
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
