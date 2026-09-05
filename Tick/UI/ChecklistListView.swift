import SwiftUI

struct ChecklistListView: View {
    @Environment(Store.self) private var store
    var folder: FolderSelection
    @Binding var selection: UUID?
    @Binding var search: String
    var searchFocused: FocusState<Bool>.Binding
    var onCreate: () -> Void
    var autofocus = false

    private var visible: [Checklist] {
        groups.flatMap(\.items)
    }

    private struct FolderGroup: Identifiable {
        var id: String
        var title: String?
        var items: [Checklist]
    }

    /// В «Все чеклисты» листы группируются по папкам; в конкретной папке — плоский список.
    private var groups: [FolderGroup] {
        let query = search.trimmingCharacters(in: .whitespaces)
        // Совпадение по имени папки показывает все её листы.
        let matching = store.checklists(in: folder).filter {
            $0.matches(query) || (store.folder($0.folderID)?.name.localizedStandardContains(query) ?? false)
        }
        guard folder == .all, !store.folders.isEmpty else {
            return matching.isEmpty ? [] : [FolderGroup(id: "flat", title: nil, items: matching)]
        }
        var result: [FolderGroup] = []
        for f in store.folders {
            let items = matching.filter { $0.folderID == f.id }
            if !items.isEmpty { result.append(FolderGroup(id: f.id.uuidString, title: f.name, items: items)) }
        }
        let unfiled = matching.filter { $0.folderID == nil || store.folder($0.folderID) == nil }
        if !unfiled.isEmpty { result.append(FolderGroup(id: "unfiled", title: "Без папки", items: unfiled)) }
        return result
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                emptyState
            } else {
                List(selection: $selection) {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.items) { checklist in
                                ChecklistRow(checklist: checklist, showFolder: false)
                                    .tag(checklist.id)
                                    .draggable(checklist.id.uuidString)
                                    .contextMenu { contextMenu(for: checklist) }
                            }
                        } header: {
                            if let title = group.title {
                                Text(title.uppercased())
                                    .font(Typo.label)
                                    .tracking(1.6)
                                    .foregroundStyle(Palette.amber)
                                    .padding(.top, 6)
                                    .padding(.bottom, 2)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Palette.paper)
        .safeAreaInset(edge: .top, spacing: 0) { searchField }
        .onAppear {
            if autofocus { DispatchQueue.main.async { searchFocused.wrappedValue = true } }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск", text: $search)
                .textFieldStyle(.plain)
                .focused(searchFocused)
                .onSubmit { if let first = visible.first { selection = first.id } }
                .onExitCommand { search = ""; searchFocused.wrappedValue = false }
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            if search.isEmpty {
                Image(systemName: "checklist")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Нет чеклистов")
                    .foregroundStyle(.secondary)
                Button("Создать") { onCreate() }
                    .buttonStyle(.link)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Ничего не найдено")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func contextMenu(for checklist: Checklist) -> some View {
        Button("Дублировать") {
            if let copy = store.duplicateChecklist(checklist.id) { selection = copy.id }
        }
        Menu("Переместить в") {
            Button("Без папки") { store.move(checklist.id, to: nil) }
                .disabled(checklist.folderID == nil)
            if !store.folders.isEmpty { Divider() }
            ForEach(store.folders) { folder in
                Button(folder.name) { store.move(checklist.id, to: folder.id) }
                    .disabled(checklist.folderID == folder.id)
            }
        }
        if checklist.doneCount > 0 {
            Button("Сбросить отметки") { store.resetChecklist(checklist.id) }
        }
        if !checklist.isBuiltIn {
            Divider()
            Button("Удалить", role: .destructive) {
                store.deleteChecklist(checklist.id)
                if selection == checklist.id { selection = nil }
            }
        }
    }
}

private struct ChecklistRow: View {
    @Environment(Store.self) private var store
    var checklist: Checklist
    var showFolder: Bool

    var body: some View {
        HStack(spacing: 10) {
            if checklist.kind == .checklist {
                ProgressRing(progress: checklist.progress, complete: checklist.isComplete)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkMuted)
                    .frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(checklist.displayTitle)
                    .lineLimit(1)
                    .foregroundStyle(checklist.title.isEmpty ? .secondary : .primary)
                HStack(spacing: 4) {
                    Text(subtitle)
                    if showFolder, let folder = store.folder(checklist.folderID) {
                        Text("·")
                        Text(folder.name).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String {
        let count = checklist.actionItems.count
        if count == 0 { return "Пусто" }
        if checklist.kind == .reference { return "Памятка · \(count)" }
        return "\(checklist.doneCount) из \(count)"
    }
}

/// Кольцо прогресса — читается быстрее, чем «3/7» текстом.
struct ProgressRing: View {
    var progress: Double
    var complete: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1.5)
            if complete {
                Circle().fill(Palette.done)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Palette.amber, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(.easeOut(duration: 0.2), value: progress)
    }
}
