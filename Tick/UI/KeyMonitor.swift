import AppKit
import SwiftUI

/// Локальный монитор событий. `TextField` в SwiftUI на macOS перехватывает
/// клавиши раньше `onKeyPress`, а выделяемый `Text` съедает клики раньше
/// `TapGesture`, поэтому и то и другое ловим здесь.
@MainActor
final class KeyMonitor {
    private var token: Any?

    /// `handler` возвращает true, если событие обработано и его не надо передавать дальше.
    func install(matching mask: NSEvent.EventTypeMask = .keyDown, _ handler: @escaping (NSEvent) -> Bool) {
        remove()
        token = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            handler(event) ? nil : event
        }
    }

    func remove() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }
}

/// Даёт SwiftUI-вью ссылку на своё NSWindow.
final class WindowBox {
    weak var window: NSWindow?
}

struct WindowFinder: NSViewRepresentable {
    var box: WindowBox

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { box.window = view.window }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { box.window = view.window }
    }
}

/// Кадры строк в координатах окна (`.global`), чтобы сопоставить клик со строкой.
struct RowFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Хранилище кадров вне `@State`: значение читается только при клике, и запись
/// в него не должна заново вычислять body на каждый сдвиг строки.
final class RowFrameStore {
    var frames: [UUID: CGRect] = [:]
}
