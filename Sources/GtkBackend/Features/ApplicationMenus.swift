import CGtk
import Gtk
@_spi(Backends) import SwiftCrossUI

extension GtkBackend: BackendFeatures.ApplicationMenus {
    public func setApplicationMenu(
        _ submenus: [ResolvedMenu.Submenu],
        environment: EnvironmentValues
    ) {
        // Rendering makes the menus' actions afresh, with the current closures
        // and enabled states, and names them by position. So when the items are
        // the same, the menu bar that's shown already names the new actions, and
        // stays: setting a menu bar closes any of its menus that are open.
        let model = renderMenuBar(submenus, environment: environment)
        let outline = submenus.map(MenuOutline.init)
        if outline != menuBarOutline {
            gtkApp.menuBarModel = model
            menuBarOutline = outline
        }

        let showMenuBar = !submenus.isEmpty
        for window in windows {
            window.showMenuBar = showMenuBar
        }
    }

    func renderMenu(
        _ menu: ResolvedMenu,
        actionMap: any GActionMap,
        actionNamespace: String,
        actionPrefix: String?,
        environment: EnvironmentValues
    ) -> GMenu {
        var currentSection = GMenu()
        var previousSections: [GMenu] = []

        for (i, item) in menu.items.enumerated() {
            let actionName =
                if let actionPrefix {
                    "\(actionPrefix)_\(i)"
                } else {
                    "\(i)"
                }

            render(item: item, environment: environment)
            func render(item: ResolvedMenu.Item, environment: EnvironmentValues) {
                switch item {
                    case .button(let label, let action):
                        if let action {
                            let gAction = GSimpleAction(name: actionName, action: action)
                            gAction.enabled = environment.isEnabled
                            actionMap.addAction(gAction)
                        } else {
                            // An action of an earlier render may have this name.
                            actionMap.removeAction(named: actionName)
                        }

                        currentSection.appendItem(
                            label: label,
                            actionName: "\(actionNamespace).\(actionName)"
                        )
                    case .toggle(let label, let value, let onChange):
                        let gAction = GSimpleAction(
                            name: actionName,
                            state: value,
                            action: onChange
                        )
                        gAction.enabled = environment.isEnabled
                        actionMap.addAction(gAction)

                        currentSection.appendItem(
                            label: label,
                            actionName: "\(actionNamespace).\(actionName)"
                        )
                    case .separator:
                        // GTK[3] doesn't have explicit separators per se, but instead deals with
                        // sections (actually quite similar to what you can do in SwiftUI with the
                        // Section view). It'll automatically draw separators between sections.
                        previousSections.append(currentSection)
                        currentSection = GMenu()
                    case .submenu(let submenu):
                        currentSection.appendSubmenu(
                            label: submenu.label,
                            content: renderMenu(
                                submenu.content,
                                actionMap: actionMap,
                                actionNamespace: actionNamespace,
                                actionPrefix: actionName,
                                environment: environment
                            )
                        )
                    case .modifiedEnvironment(let item, let modification):
                        render(item: item, environment: modification(environment))
                }
            }
        }

        if previousSections.isEmpty {
            // There are no dividers; just return the current section to keep the menu tree flat.
            return currentSection
        } else {
            let model = GMenu()
            for section in previousSections + [currentSection] {
                model.appendSection(label: nil, content: section)
            }
            return model
        }
    }

    func renderMenuBar(
        _ submenus: [ResolvedMenu.Submenu],
        environment: EnvironmentValues
    ) -> GMenu {
        let model = GMenu()
        for (i, submenu) in submenus.enumerated() {
            model.appendSubmenu(
                label: submenu.label,
                content: renderMenu(
                    submenu.content,
                    actionMap: gtkApp,
                    actionNamespace: "app",
                    actionPrefix: "\(i)",
                    environment: environment
                )
            )
        }

        return model
    }
}

/// What a menu bar shows of its menus: their items' kinds and labels. Menus
/// with the same outline render the same `GMenu`; what else differs between
/// them is in their actions.
enum MenuOutline: Equatable {
    case button(String)
    case toggle(String)
    case separator
    case submenu(String, [MenuOutline])

    init(_ submenu: ResolvedMenu.Submenu) {
        self = .submenu(submenu.label, submenu.content.items.map(MenuOutline.init))
    }

    init(_ item: ResolvedMenu.Item) {
        switch item {
            case .button(let label, _):
                self = .button(label)
            case .toggle(let label, _, _):
                self = .toggle(label)
            case .separator:
                self = .separator
            case .submenu(let submenu):
                self.init(submenu)
            case .modifiedEnvironment(let item, _):
                self.init(item)
        }
    }
}
