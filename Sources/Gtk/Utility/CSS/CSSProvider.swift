import CGtk

/// Swift representation of a Gtk CSS provider
public class CSSProvider {
    var pointer: UnsafeMutablePointer<GtkCssProvider>
    var display: OpaquePointer?
    var context: UnsafeMutablePointer<GtkStyleContext>?
    /// The CSS last loaded, to skip loading the same CSS again.
    private var loadedCss: String?

    public init(
        forDisplay display: OpaquePointer = gdk_display_get_default(),
        priority: UInt32 = UInt32(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION)
    ) {
        pointer = gtk_css_provider_new()
        self.display = display
        gtk_style_context_add_provider_for_display(display, OpaquePointer(pointer), priority)
    }

    /// A provider for one widget alone, on its own style context: loading it
    /// restyles that widget, not the display. Its selectors only match the
    /// widget's own CSS node, not its children's.
    ///
    /// Deprecated since: 4.10 (GtkStyleContext)
    public init(
        forWidget widget: UnsafeMutablePointer<GtkWidget>,
        priority: UInt32 = UInt32(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION)
    ) {
        pointer = gtk_css_provider_new()
        let context = gtk_widget_get_style_context(widget)!
        g_object_ref(context)
        self.context = context
        gtk_style_context_add_provider(context, OpaquePointer(pointer), priority)
    }

    deinit {
        if let context {
            gtk_style_context_remove_provider(context, OpaquePointer(pointer))
            g_object_unref(context)
        } else if let display {
            gtk_style_context_remove_provider_for_display(display, OpaquePointer(pointer))
        }
    }

    /// Loads data into css_provider.
    ///
    /// This clears any previously loaded information. Loading the CSS the
    /// provider already has does nothing: a load restyles every widget the
    /// provider applies to, and views load their CSS on every update.
    ///
    /// Deprecated since: 4.12
    public func loadCss(from data: String) {
        guard data != loadedCss else { return }
        loadedCss = data
        // TODO: Connect to parsing-error signal to log parsing errors.
        gtk_css_provider_load_from_data(pointer, data, gssize(data.count))
    }
}
