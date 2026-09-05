import AppKit
import SwiftUI

// MARK: - Шапка карточки

/// Тёмная шапка с аварийной полосой — общая для просмотра и пустого состояния.
struct CardHeader<Controls: View>: View {
    var title: String
    var subtitle: String
    var counter: String?
    var showReset = false
    var onReset: () -> Void = {}
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Spacer()
                    controls()
                }
                .padding(.top, 6)
                .padding(.trailing, 8)

                Text(title.uppercased())
                    .font(Typo.title)
                    .tracking(1.4)
                    .foregroundStyle(Palette.amber)
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .padding(.horizontal, 18)

                HStack(alignment: .firstTextBaseline) {
                    Text(subtitle.uppercased())
                        .font(Typo.label)
                        .tracking(1.8)
                        .foregroundStyle(Palette.headerInk.opacity(0.65))
                    Spacer()
                    if showReset {
                        Button("Сбросить", action: onReset)
                            .buttonStyle(.plain)
                            .font(Typo.label)
                            .foregroundStyle(Palette.headerInk.opacity(0.65))
                            .help("Сбросить отметки (⌘⇧R)")
                    }
                    if let counter {
                        Text(counter)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.headerInk)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.header)

            HazardStripe()
                .frame(height: 7)
        }
    }
}

// MARK: - Контейнер

struct ChecklistDetailView: View {
    @Binding var checklist: Checklist
    var mode: Mode

    var body: some View {
        Group {
            if mode == .view {
                ChecklistReadView(checklist: $checklist) { EmptyView() }
            } else {
                ChecklistEditView(checklist: $checklist)
            }
        }
        .background(Palette.paper)
    }
}

// MARK: - Просмотр

struct ChecklistReadView<Controls: View>: View {
    @Environment(Store.self) private var store
    @Binding var checklist: Checklist
    @ViewBuilder var controls: () -> Controls

    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var mouseMonitor = KeyMonitor()
    @State private var windowBox = WindowBox()
    @State private var copiedID: UUID?
    @State private var copiedResetTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(
                title: checklist.displayTitle,
                subtitle: subtitle,
                counter: checklist.kind == .checklist ? "\(checklist.doneCount) / \(checklist.actionItems.count)" : nil,
                showReset: checklist.doneCount > 0,
                onReset: { withAnimation(.easeOut(duration: 0.2)) { store.resetChecklist(checklist.id) } },
                controls: controls
            )

            if checklist.kind == .checklist {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(checklist.isComplete ? Palette.done : Palette.amber)
                        .frame(width: proxy.size.width * checklist.progress)
                        .animation(.easeOut(duration: 0.25), value: checklist.progress)
                }
                .frame(height: 7)
                .background(Palette.rule.opacity(0.6))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if checklist.items.isEmpty {
                        Text("Пунктов пока нет — добавьте их в режиме правки (⌘E).")
                            .font(.callout)
                            .foregroundStyle(Palette.inkMuted)
                            .padding(20)
                    }
                    ForEach($checklist.items) { $item in
                        if item.isSection {
                            SectionRow(text: item.text)
                        } else {
                            ReadItemRow(
                                item: $item,
                                number: checklist.number(of: item),
                                kind: checklist.kind,
                                copied: copiedID == item.id
                            )
                        }
                    }
                    if checklist.isComplete {
                        Text("ЧЕКЛИСТ ВЫПОЛНЕН")
                            .font(Typo.label)
                            .tracking(2)
                            .foregroundStyle(Palette.done)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }
        }
        .background(Palette.paper)
        .overlay(alignment: .bottom) {
            if copiedID != nil {
                Text("СКОПИРОВАНО")
                    .font(Typo.label)
                    .tracking(2)
                    .foregroundStyle(Palette.header)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Palette.amber, in: Capsule())
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .background(WindowFinder(box: windowBox))
        .onPreferenceChange(RowFramesKey.self) { rowFrames = $0 }
        .onAppear {
            mouseMonitor.install(matching: .leftMouseDown) { event in
                handleMouse(event)
            }
        }
        .onDisappear { mouseMonitor.remove() }
    }

    // MARK: Клик по пункту — копировать

    /// Клик без протяжки внутри строки копирует её значение (или текст).
    /// Нажатие перехватываем и сами ждём отпускания из очереди окна: отпустили
    /// на месте — копия; сдвинули — возвращаем нажатие тексту, начнётся выделение.
    /// Возвращает true, если событие поглощено.
    private func handleMouse(_ event: NSEvent) -> Bool {
        guard let window = event.window, window === windowBox.window,
              let content = window.contentView,
              event.clickCount == 1,
              event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
        else { return false }
        // NSHostingView перевёрнут (начало сверху), как и SwiftUI-кадры строк.
        let local = content.convert(event.locationInWindow, from: nil)
        let point = content.isFlipped ? local : CGPoint(x: local.x, y: content.bounds.height - local.y)
        guard let id = rowFrames.first(where: { $0.value.contains(point) })?.key else { return false }

        let start = event.locationInWindow
        while true {
            guard let next = window.nextEvent(
                matching: [.leftMouseUp, .leftMouseDragged],
                until: Date(timeIntervalSinceNow: 2),
                inMode: .eventTracking,
                dequeue: true
            ) else { return true } // долгое удержание — не клик
            if next.type == .leftMouseUp {
                copyRow(id)
                return true
            }
            let moved = hypot(next.locationInWindow.x - start.x, next.locationInWindow.y - start.y)
            if moved >= 4 {
                window.sendEvent(event)
                window.sendEvent(next)
                return true
            }
        }
    }

    private func copyRow(_ id: UUID) {
        guard let item = checklist.items.first(where: { $0.id == id }) else { return }
        copyToPasteboard(item.detail.isEmpty ? item.text : item.detail)
        copiedResetTask?.cancel()
        withAnimation(.easeOut(duration: 0.12)) { copiedID = id }
        copiedResetTask = Task {
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { copiedID = nil }
        }
    }

    private var subtitle: String {
        var parts = [checklist.kind.title]
        if let folder = store.folder(checklist.folderID) { parts.append(folder.name) }
        return parts.joined(separator: " · ")
    }
}

private struct SectionRow: View {
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text.uppercased())
                .font(Typo.section)
                .tracking(1.6)
                .foregroundStyle(Palette.amber)
                .textSelection(.enabled)
            Rectangle().fill(Palette.ink.opacity(0.8)).frame(height: 1.5)
        }
        .padding(.top, 18)
        .padding(.bottom, 4)
    }
}

private struct ReadItemRow: View {
    @Binding var item: ChecklistItem
    var number: Int?
    var kind: ListKind
    var copied: Bool
    @State private var hovering = false

    /// Короткий ответ идёт в строку через лидер, длинная команда — отдельной строкой.
    private var detailInline: Bool { item.detail.count <= 16 && !item.detail.contains("\n") }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                if kind == .checklist {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { item.isDone.toggle() }
                    } label: {
                        CheckBox(isDone: item.isDone)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 1)
                    .help(item.isDone ? "Снять отметку" : "Отметить")
                }

                // Клик по любому месту пункта копирует значение (или текст, если значения нет).
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(number.map { String(format: "%02d", $0) } ?? "")
                            .font(Typo.number)
                            .foregroundStyle(Palette.inkMuted)
                            .frame(width: 20, alignment: .trailing)

                        Text(item.text.isEmpty ? " " : item.text)
                            .font(Typo.item)
                            .strikethrough(item.isDone, color: Palette.inkMuted)
                            .foregroundStyle(item.isDone ? Palette.inkMuted : Palette.ink)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(2)

                        if !item.detail.isEmpty, detailInline {
                            DotLeader()
                            detailChip
                                .fixedSize()
                                .layoutPriority(3)
                        } else {
                            Spacer(minLength: 0)
                        }

                        copyHint
                            .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }
                    }

                    if !item.detail.isEmpty, !detailInline {
                        detailChip
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 30)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: RowFramesKey.self, value: [item.id: proxy.frame(in: .global)])
                    }
                )
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(rowBackground)
            )
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .help(item.detail.isEmpty ? "Клик — копировать текст" : "Клик — копировать значение")
        .contextMenu {
            if kind == .checklist {
                Button(item.isDone ? "Снять отметку" : "Отметить") { item.isDone.toggle() }
            }
            Button("Копировать текст") { copyToPasteboard(item.text) }
            if !item.detail.isEmpty {
                Button("Копировать значение") { copyToPasteboard(item.detail) }
                Button("Копировать строку") { copyToPasteboard(item.text + " — " + item.detail) }
            }
        }
    }

    /// Выполненный пункт заливается цветом «готово»; копирование и наведение поверх.
    private var rowBackground: Color {
        if copied { return Palette.amber.opacity(0.18) }
        let done = kind == .checklist && item.isDone
        if hovering { return done ? Palette.done.opacity(0.28) : Palette.paperRaised.opacity(0.7) }
        return done ? Palette.done.opacity(0.18) : Color.clear
    }

    private var detailChip: some View {
        Text(item.detail)
            .font(Typo.code)
            .foregroundStyle(item.isDone ? Palette.inkMuted : Palette.ink)
            .textSelection(.enabled)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Palette.code, in: RoundedRectangle(cornerRadius: 4))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var copyHint: some View {
        Image(systemName: "doc.on.doc")
            .font(.system(size: 11))
            .foregroundStyle(Palette.inkMuted)
            .opacity(hovering ? 1 : 0)
            .fixedSize()
    }
}

// MARK: - Правка

struct ChecklistEditView: View {
    @Environment(Store.self) private var store
    @Binding var checklist: Checklist
    @State private var focus: Field?
    @State private var dragging: UUID?

    enum Field: Hashable {
        case title
        case item(UUID)
        case detail(UUID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                ForEach($checklist.items) { $item in
                    EditItemRow(
                        item: $item,
                        number: checklist.number(of: item),
                        kind: checklist.kind,
                        focus: $focus,
                        onReturn: { insertItem(after: item.id) },
                        onBackspaceEmpty: { removeItem(item.id) },
                        onDelete: { removeItem(item.id) },
                        onDragStart: { dragging = item.id },
                        onFocusNext: { focusNext(after: item.id) },
                        onFocusPrevious: { focusPrevious(before: item.id) }
                    )
                    .opacity(dragging == item.id ? 0.4 : 1)
                    .onDrop(of: [.text], delegate: ReorderDelegate(item: item, items: $checklist.items, dragging: $dragging))
                    .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button { addItem() } label: {
                        Label("Пункт", systemImage: "plus")
                    }
                    Button { addItem(section: true) } label: {
                        Label("Раздел", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.paper)
        .onAppear {
            if checklist.title.isEmpty { focus = .title }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            GrowingTextView(
                text: $checklist.title,
                placeholder: "Название",
                font: .systemFont(ofSize: 20, weight: .heavy),
                color: NSColor(Palette.ink),
                field: Field.title,
                focus: $focus,
                onReturn: { focusFirstOrAdd() },
                onTab: { focusFirstOrAdd() },
                onArrowDown: { if let first = checklist.items.first { focus = .item(first.id) } }
            )

            HStack(spacing: 12) {
                Picker("Тип", selection: $checklist.kind) {
                    ForEach(ListKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()

                Picker("Папка", selection: $checklist.folderID) {
                    Text("Без папки").tag(UUID?.none)
                    if !store.folders.isEmpty { Divider() }
                    ForEach(store.folders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }
            Rectangle().fill(Palette.ink.opacity(0.8)).frame(height: 1.5).padding(.top, 4)
        }
    }

    // MARK: Пункты

    private func focusFirstOrAdd() {
        if let first = checklist.items.first {
            focus = .item(first.id)
        } else {
            addItem()
        }
    }

    /// Стрелка вниз с последнего поля пункта — в следующий пункт.
    private func focusNext(after id: UUID) {
        guard let index = checklist.items.firstIndex(where: { $0.id == id }),
              index + 1 < checklist.items.count else { return }
        focus = .item(checklist.items[index + 1].id)
    }

    /// Стрелка вверх с первого поля пункта — в предыдущий пункт (в его значение), иначе в название.
    private func focusPrevious(before id: UUID) {
        guard let index = checklist.items.firstIndex(where: { $0.id == id }) else { return }
        if index == 0 {
            focus = .title
            return
        }
        let previous = checklist.items[index - 1]
        focus = previous.isSection ? .item(previous.id) : .detail(previous.id)
    }

    private func addItem(section: Bool = false) {
        let item = ChecklistItem(isSection: section)
        checklist.items.append(item)
        focusLater(.item(item.id))
    }

    private func insertItem(after id: UUID) {
        guard let index = checklist.items.firstIndex(where: { $0.id == id }) else { return }
        let item = ChecklistItem()
        checklist.items.insert(item, at: index + 1)
        focusLater(.item(item.id))
    }

    private func removeItem(_ id: UUID) {
        guard let index = checklist.items.firstIndex(where: { $0.id == id }) else { return }
        checklist.items.remove(at: index)
        if index > 0 {
            focusLater(.item(checklist.items[index - 1].id))
        } else {
            focusLater(.title)
        }
    }

    private func focusLater(_ field: Field) {
        DispatchQueue.main.async { focus = field }
    }
}

/// Перестановка перетаскиванием за ручку: пункт переезжает, когда курсор входит в другую строку.
private struct ReorderDelegate: DropDelegate {
    let item: ChecklistItem
    @Binding var items: [ChecklistItem]
    @Binding var dragging: UUID?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != item.id,
              let from = items.firstIndex(where: { $0.id == dragging }),
              let to = items.firstIndex(where: { $0.id == item.id })
        else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

private struct EditItemRow: View {
    @Binding var item: ChecklistItem
    var number: Int?
    var kind: ListKind
    @Binding var focus: ChecklistEditView.Field?
    var onReturn: () -> Void
    var onBackspaceEmpty: () -> Void
    var onDelete: () -> Void
    var onDragStart: () -> Void
    var onFocusNext: () -> Void
    var onFocusPrevious: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkMuted.opacity(hovering ? 0.8 : 0.35))
                .frame(width: 14, height: 20)
                .contentShape(Rectangle())
                .padding(.top, 2)
                .onDrag {
                    onDragStart()
                    return NSItemProvider(object: item.id.uuidString as NSString)
                }
                .help("Перетащите, чтобы переставить")

            if item.isSection {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.amber)
                    .frame(width: 20)
                    .padding(.top, 5)
                GrowingTextView(
                    text: $item.text,
                    placeholder: "Раздел",
                    font: .systemFont(ofSize: 12, weight: .heavy),
                    color: NSColor(Palette.amber),
                    field: ChecklistEditView.Field.item(item.id),
                    focus: $focus,
                    onReturn: onReturn,
                    onBackspaceEmpty: onBackspaceEmpty,
                    onArrowDown: onFocusNext,
                    onArrowUp: onFocusPrevious
                )
                .padding(.top, 3)
            } else {
                Text(number.map { String(format: "%02d", $0) } ?? "")
                    .font(Typo.number)
                    .foregroundStyle(Palette.inkMuted)
                    .frame(width: 20, alignment: .trailing)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 2) {
                    GrowingTextView(
                        text: $item.text,
                        placeholder: kind == .checklist ? "Что проверить" : "Тезис",
                        font: .systemFont(ofSize: 14.5, weight: .medium),
                        color: NSColor(Palette.ink),
                        field: ChecklistEditView.Field.item(item.id),
                        focus: $focus,
                        onReturn: onReturn,
                        onBackspaceEmpty: onBackspaceEmpty,
                        onTab: { focus = .detail(item.id) },
                        onArrowDown: { focus = .detail(item.id) },
                        onArrowUp: onFocusPrevious
                    )
                    HStack(alignment: .top, spacing: 6) {
                        Text("↳")
                            .font(Typo.code)
                            .foregroundStyle(Palette.inkMuted.opacity(0.6))
                            .padding(.top, 2)
                        GrowingTextView(
                            text: $item.detail,
                            placeholder: kind == .checklist ? "ответ или значение" : "команда или значение",
                            font: .monospacedSystemFont(ofSize: 12.5, weight: .medium),
                            color: NSColor(Palette.ink),
                            field: ChecklistEditView.Field.detail(item.id),
                            focus: $focus,
                            onReturn: onReturn,
                            onBackspaceEmpty: { focus = .item(item.id) },
                            onBacktab: { focus = .item(item.id) },
                            onArrowDown: onFocusNext,
                            onArrowUp: { focus = .item(item.id) }
                        )
                    }
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.inkMuted)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .padding(.top, 5)
            .help("Удалить пункт")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Palette.paperRaised.opacity(0.7) : Color.clear)
        )
        .onHover { hovering = $0 }
        .contextMenu {
            Button(item.isSection ? "Сделать пунктом" : "Сделать заголовком раздела") {
                item.isSection.toggle()
                if item.isSection { item.detail = ""; item.isDone = false }
            }
            Divider()
            Button("Удалить", role: .destructive, action: onDelete)
        }
    }
}
