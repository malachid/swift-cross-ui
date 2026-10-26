import CGtk

public protocol GActionMap {
    var actionMapPointer: OpaquePointer { get }
}

extension GActionMap {
    public func addAction(_ action: any GAction) {
        g_action_map_add_action(actionMapPointer, action.actionPointer)
    }

    public func removeAction(named name: String) {
        g_action_map_remove_action(actionMapPointer, name)
    }
}
