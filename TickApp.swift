import SwiftUI

@main
struct TickApp: App {
    @State private var store = Store()
    @FocusedValue(\.appActions) private var actions
    @AppStorage("theme") private var themeRaw = AppTheme.system.rawValue

    var body: some Scene {
        Window("Tick", id: "main") {
            ContentView()
                .environment(store)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .windowResizability(.contentMinSize)
        .defaultSize(width: 380, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Новый чеклист") { actions?.newChecklist() }
                    .keyboardShortcut("n")
                    .disabled(actions == nil)
                Button("Новая памятка") { actions?.newReference() }
                    .keyboardShortcut("n", modifiers: [.command, .option])
                    .disabled(actions == nil)
                Button("Новая папка") { actions?.newFolder() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(actions == nil)
            }
            CommandGroup(after: .importExport) {
                Button("Показать данные в Finder") { store.revealDataInFinder() }
                Button("Папка для данных…") { DataFolderPicker.choose(for: store) }
                Button("Папка по умолчанию") { DataFolderPicker.useDefault(store) }
                    .disabled(!store.usesCustomFolder)
            }
            CommandGroup(after: .textEditing) {
                Divider()
                Button("Найти") { actions?.focusSearch() }
                    .keyboardShortcut("f")
                    .disabled(actions == nil)
            }
            CommandGroup(after: .toolbar) {
                Picker("Тема", selection: $themeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                }
            }
            CommandMenu("Лист") {
                Button("Просмотр / Правка") { actions?.toggleMode() }
                    .keyboardShortcut("e")
                    .disabled(actions == nil)
                Divider()
                Button("Копировать лист") { actions?.copyChecklist() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(actions == nil)
                Button("Сбросить отметки") { actions?.resetChecklist() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(actions == nil)
                Divider()
                Button("Удалить лист") { actions?.deleteChecklist() }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled(actions == nil)
            }
        }
    }
}
