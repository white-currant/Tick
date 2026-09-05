import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store

    /// Приложение всегда открывается в просмотре; правка — по явному действию.
    @State private var mode: Mode = .view
    @AppStorage("theme") private var themeRaw = AppTheme.system.rawValue
    @State private var folderSelection: FolderSelection? = .all
    @State private var selectedChecklistID: UUID?
    @State private var search = ""
    @State private var showNewFolder = false
    @State private var showPicker = false
    @State private var confirmDelete = false
    @State private var actions = AppActions()
    @State private var windowCornerRadius: CGFloat = 16
    @FocusState private var searchFocused: Bool

    private var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .system }
        nonmutating set { themeRaw = newValue.rawValue }
    }

    private var currentFolder: FolderSelection { folderSelection ?? .all }

    var body: some View {
        Group {
            if mode == .view {
                viewerLayout
            } else {
                editorLayout
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .background(WindowConfigurator(floating: mode == .view, minWidth: 840, cornerRadius: $windowCornerRadius))
        .frame(minWidth: mode == .view ? 340 : 840, minHeight: 380)
        .focusedSceneValue(\.appActions, actions)
        .onAppear {
            bindActions()
            if selectedChecklistID == nil { selectedChecklistID = store.checklists.first?.id }
        }
        .onChange(of: store.folders) { _, folders in
            if let id = currentFolder.folderID, !folders.contains(where: { $0.id == id }) {
                folderSelection = .all
            }
        }
        .onChange(of: folderSelection) { _, _ in
            let visible = store.checklists(in: currentFolder)
            if let id = selectedChecklistID, !visible.contains(where: { $0.id == id }) {
                selectedChecklistID = visible.first?.id
            }
        }
        .confirmationDialog(
            "Удалить «\(selectedChecklist?.displayTitle ?? "")»?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) { deleteSelected() }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    // MARK: Правка — три колонки

    private var editorLayout: some View {
        NavigationSplitView {
            SidebarView(selection: $folderSelection, showNewFolder: $showNewFolder)
                .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 320)
        } content: {
            ChecklistListView(
                folder: currentFolder,
                selection: $selectedChecklistID,
                search: $search,
                searchFocused: $searchFocused,
                onCreate: { newChecklist(kind: .checklist) }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 290, max: 420)
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button("Чеклист", systemImage: "checklist") { newChecklist(kind: .checklist) }
                        Button("Памятка", systemImage: "terminal") { newChecklist(kind: .reference) }
                    } label: {
                        Label("Новый лист", systemImage: "square.and.pencil")
                    } primaryAction: {
                        newChecklist(kind: .checklist)
                    }
                    .help("Новый лист (⌘N)")
                }
            }
        } detail: {
            detail
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 8) {
                            themeMenu
                            modePicker
                        }
                    }
                }
        }
    }

    // MARK: Просмотр — карточка поверх всех окон

    private var viewerLayout: some View {
        Group {
            if let id = selectedChecklistID, let binding = store.binding(for: id) {
                ChecklistReadView(checklist: binding) { viewerControls }
                    .id(id)
            } else {
                VStack(spacing: 0) {
                    CardHeader(title: "Tick", subtitle: "Лист не выбран") { viewerControls }
                    Spacer()
                    Text("Выберите лист кнопкой ☰ или создайте новый в режиме правки.")
                        .font(.callout)
                        .foregroundStyle(Palette.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(24)
                    Spacer()
                }
                .background(Palette.paper)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: windowCornerRadius, style: .circular)
                .strokeBorder(Palette.amber, lineWidth: 3)
                .ignoresSafeArea()
        }
        .ignoresSafeArea(edges: .top)
    }

    private var viewerControls: some View {
        HStack(spacing: 2) {
            HeaderButton(symbol: "list.bullet", help: "Другой лист (⌘F)") { showPicker.toggle() }
                .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                    ChecklistListView(
                        folder: .all,
                        selection: $selectedChecklistID,
                        search: $search,
                        searchFocused: $searchFocused,
                        onCreate: { newChecklist(kind: .checklist) },
                        autofocus: true
                    )
                    .frame(width: 320, height: 400)
                    .onChange(of: selectedChecklistID) { _, _ in showPicker = false }
                }
            HeaderButton(symbol: theme.symbol, help: "Тема: \(theme.title)") { theme = theme.next }
            HeaderButton(symbol: "pencil", help: "Правка (⌘E)") { mode = .edit }
        }
    }

    private var modePicker: some View {
        Picker("Режим", selection: Binding(get: { mode }, set: { mode = $0 })) {
            Label("Просмотр", systemImage: "eye").tag(Mode.view)
            Label("Правка", systemImage: "pencil").tag(Mode.edit)
        }
        .pickerStyle(.segmented)
        .labelStyle(.iconOnly)
        .help("Просмотр / Правка (⌘E)")
    }

    private var themeMenu: some View {
        Menu {
            Picker("Тема", selection: Binding(get: { theme }, set: { theme = $0 })) {
                ForEach(AppTheme.allCases) { t in
                    Label(t.title, systemImage: t.symbol).tag(t)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Тема", systemImage: theme.symbol)
        }
        .help("Тема оформления")
    }

    // MARK: Detail

    private var selectedChecklist: Checklist? {
        guard let id = selectedChecklistID else { return nil }
        return store.checklists.first { $0.id == id }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selectedChecklistID, let binding = store.binding(for: id) {
            ChecklistDetailView(checklist: binding, mode: mode)
                .id(id)
        } else {
            ContentUnavailableView {
                Label("Ничего не выбрано", systemImage: "checklist")
            } description: {
                Text("Выберите лист или создайте новый.")
            } actions: {
                Button("Чеклист") { newChecklist(kind: .checklist) }
                Button("Памятка") { newChecklist(kind: .reference) }
            }
            .background(Palette.paper)
        }
    }

    // MARK: Actions

    private func bindActions() {
        actions.newChecklist = { newChecklist(kind: .checklist) }
        actions.newReference = { newChecklist(kind: .reference) }
        actions.newFolder = {
            if mode == .view { mode = .edit }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showNewFolder = true }
        }
        actions.toggleMode = { mode = mode == .view ? .edit : .view }
        actions.focusSearch = {
            if mode == .view { showPicker = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { searchFocused = true }
        }
        actions.copyChecklist = { if let checklist = selectedChecklist { copyToPasteboard(checklist.plainText) } }
        actions.resetChecklist = { if let checklist = selectedChecklist { store.resetChecklist(checklist.id) } }
        actions.deleteChecklist = {
            guard let checklist = selectedChecklist, !checklist.isBuiltIn else { return }
            confirmDelete = true
        }
    }

    private func newChecklist(kind: ListKind) {
        let checklist = store.addChecklist(in: currentFolder.folderID, kind: kind)
        search = ""
        showPicker = false
        selectedChecklistID = checklist.id
        mode = .edit
    }

    private func deleteSelected() {
        guard let id = selectedChecklistID else { return }
        let visible = store.checklists(in: currentFolder)
        let index = visible.firstIndex { $0.id == id } ?? 0
        store.deleteChecklist(id)
        let remaining = store.checklists(in: currentFolder)
        selectedChecklistID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
    }
}
