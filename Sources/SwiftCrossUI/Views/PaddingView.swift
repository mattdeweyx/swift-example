public struct PaddingView<Child: View>: View {
    public var body: ViewContent1<Child>

    /// The padding to apply to the child view.
    private var padding: Padding

    init(_ content: Child, _ padding: Padding) {
        body = ViewContent1(content)
        self.padding = padding
    }

    public func asWidget(_ children: ViewGraphNodeChildren1<Child>) -> GtkSingleChildBox {
        let box = GtkSingleChildBox()
        box.setChild(children.child0.widget)
        return box
    }

    public func update(_ box: GtkSingleChildBox, children: ViewGraphNodeChildren1<Child>) {
        box.topMargin = padding.top
        box.bottomMargin = padding.bottom
        box.leftMargin = padding.left
        box.rightMargin = padding.right
    }
}
