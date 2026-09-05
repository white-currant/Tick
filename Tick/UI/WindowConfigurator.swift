import AppKit
import SwiftUI

/// Переводит окно в «плавающий» режим: поверх всех окон, на всех рабочих
/// столах, и сжимает его до компактной ширины. При выходе восстанавливает
/// прежний размер.
struct WindowConfigurator: NSViewRepresentable {
    var floating: Bool
    /// Минимальная ширина окна в обычном режиме — восстановленный кадр не может быть уже.
    var minWidth: CGFloat = 840
    /// Радиус скругления окна, прочитанный у системы — под него рисуется рамка.
    var cornerRadius: Binding<CGFloat>? = nil

    final class Coordinator {
        var applied: Bool?
        var savedFrame: NSRect?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view.window, coordinator: context.coordinator) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: view.window, coordinator: context.coordinator) }
    }

    private func apply(to window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        if let cornerRadius, let frameView = window.contentView?.superview,
           frameView.responds(to: NSSelectorFromString("_cornerRadius")),
           let value = frameView.value(forKey: "_cornerRadius") as? CGFloat,
           value > 0, cornerRadius.wrappedValue != value {
            DispatchQueue.main.async { cornerRadius.wrappedValue = value }
        }
        guard coordinator.applied != floating else { return }
        coordinator.applied = floating

        if floating {
            window.level = .floating
            window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
            window.hidesOnDeactivate = false
            window.isMovableByWindowBackground = true

            let current = window.frame
            coordinator.savedFrame = current
            let width: CGFloat = 380
            if current.width > width + 40 {
                var frame = current
                frame.size.width = width
                frame.origin.x = current.maxX - width
                window.setFrame(frame, display: true, animate: true)
            }
        } else {
            window.level = .normal
            window.isMovableByWindowBackground = false
            window.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
            if let saved = coordinator.savedFrame {
                var frame = saved
                frame.size.width = max(saved.width, minWidth)
                // Оставляем окно там, куда его перетащил пользователь.
                frame.origin.x = window.frame.maxX - saved.width
                frame.origin.y = window.frame.maxY - saved.height
                if let screen = window.screen ?? NSScreen.main {
                    let visible = screen.visibleFrame
                    frame.origin.x = max(visible.minX, min(frame.origin.x, visible.maxX - frame.width))
                    frame.origin.y = max(visible.minY, min(frame.origin.y, visible.maxY - frame.height))
                }
                window.setFrame(frame, display: true, animate: true)
            }
        }
    }
}
