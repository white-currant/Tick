import SwiftUI

struct SidebarView: View {
    @Environment(Store.self) private var store
    @Binding var selection: FolderSelection?
    @Binding var showNewFolder: Bool

    @State private var renaming: Folder?
    @State private var draftName = ""
    @State private var dropTarget: UUID?

    var body: some View {
        @Bindable var store = store
        List(selection: $selection) {
            Label("Все чеклисты", systemImage: "tray.full")
                .tag(FolderSelection.all)

            if !store.folders.isEmpty {
                Section("Папки") {
                    ForEach(store.folders) { folder in
                        Label(folder.name, systemImage: "folder")
                            .tag(FolderSelection.folder(folder.id))
                            .listRowBackground(
                                dropTarget == folder.id
                                    ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.2))
                                    : nil
                            )
                            .contextMenu {
                                Button("Переименовать") { beginRename(folder) }
                                Divider()
                                Button("Удалить папку", role: .destructive) { store.deleteFolder(folder.id) }
                            }
                            .dropDestination(for: String.self) { ids, _ in
                                for id in ids.compactMap(UUID.init) { store.move(id, to: folder.id) }
                                return true
                            } isTargeted: { targeted in
                                dropTarget = targeted ? folder.id : (dropTarget == folder.id ? nil : dropTarget)
                            }
                    }
                    .onMove { store.folders.move(fromOffsets: $0, toOffset: $1) }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                showNewFolder = true
            } label: {
                Label("Новая папка", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .help("Новая папка (⌘⇧N)")
        }
        .alert("Новая папка", isPresented: $showNewFolder) {
            TextField("Название", text: $draftName)
            Button("Создать") {
                let folder = store.addFolder(named: draftName.trimmingCharacters(in: .whitespaces))
                selection = .folder(folder.id)
                draftName = ""
            }
            Button("Отмена", role: .cancel) { draftName = "" }
        }
        .alert("Переименовать папку", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Название", text: $draftName)
            Button("Готово") {
                if let folder = renaming { store.renameFolder(folder.id, to: draftName) }
                renaming = nil
                draftName = ""
            }
            Button("Отмена", role: .cancel) { renaming = nil; draftName = "" }
        }
    }

    private func beginRename(_ folder: Folder) {
        draftName = folder.name
        renaming = folder
    }
}
