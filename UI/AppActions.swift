import Observation
import SwiftUI

/// Действия текущего окна, доступные из меню и горячих клавиш.
/// Один экземпляр на окно: значение в фокусе сравнивается по ссылке,
/// иначе новые замыкания на каждый рендер зацикливают обновление сцены.
@MainActor
@Observable
final class AppActions: Equatable {
    var newChecklist: () -> Void = {}
    var newReference: () -> Void = {}
    var newFolder: () -> Void = {}
    var toggleMode: () -> Void = {}
    var focusSearch: () -> Void = {}
    var copyChecklist: () -> Void = {}
    var resetChecklist: () -> Void = {}
    var deleteChecklist: () -> Void = {}

    nonisolated static func == (lhs: AppActions, rhs: AppActions) -> Bool { lhs === rhs }
}

private struct AppActionsKey: FocusedValueKey {
    typealias Value = AppActions
}

extension FocusedValues {
    var appActions: AppActions? {
        get { self[AppActionsKey.self] }
        set { self[AppActionsKey.self] = newValue }
    }
}
