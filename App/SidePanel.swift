import SwiftUI

/// Presents `content` as a panel that slides in from `edge` and can be
/// dragged back toward that edge to dismiss it, instead of the default
/// bottom sheet — so Presets (left) and Themes (right) each stay on the
/// side they're opened from.
///
/// Every bit of motion — opening, the live drag, snapping back, and closing
/// (whether by drag, scrim tap, or the panel's own Done button flipping
/// `isPresented` directly) — is driven by the single `dragBack` value below,
/// rather than mixing a manual offset with SwiftUI's own insertion/removal
/// transition. Two separate animation systems fighting over the same frame
/// is what makes a custom drawer feel like it jumps; one value, always
/// animated the same way, doesn't.
struct SidePanel<PanelContent: View>: ViewModifier {
    let edge: HorizontalEdge
    @Binding var isPresented: Bool
    @ViewBuilder var panelContent: () -> PanelContent

    /// Kept in the view tree slightly after `isPresented` goes false, so the
    /// close animation has time to finish before the panel is torn down.
    @State private var mounted = false
    /// How far the panel has been pushed back toward its own edge: 0 is
    /// fully open, `width` is fully (and invisibly) closed.
    @State private var dragBack: CGFloat = 0

    /// Full screen width: the panel now takes over the whole screen rather
    /// than leaving a sliver of the board visible (and the scrim tappable)
    /// on the other side. Everything else — the drag-to-dismiss gesture, the
    /// open/close animation, the 30%-of-width commit threshold — already
    /// worked in terms of `width` rather than a hardcoded number, so taking
    /// over the full screen needed no other change.
    private var width: CGFloat { UIScreen.main.bounds.width }
    private let spring = Animation.interactiveSpring(response: 0.32, dampingFraction: 0.86)

    func body(content: Content) -> some View {
        content
            .overlay {
                if mounted {
                    // The ZStack ignores the safe area so the scrim and the panel's
                    // own background reach every edge, like a native drawer; the
                    // NavigationStack inside `panelContent()` still places its own
                    // toolbar correctly, since it reads safe-area insets from the
                    // environment rather than from whether its parent ignores them.
                    ZStack(alignment: edge == .leading ? .leading : .trailing) {
                        Color.black
                            .opacity(0.35 * (1 - dragBack / width))
                            .contentShape(Rectangle())
                            .onTapGesture { close() }

                        panelContent()
                            .frame(width: width)
                            .frame(maxHeight: .infinity)
                            .background(.regularMaterial)
                            .shadow(color: .black.opacity(0.25), radius: 18, x: edge == .leading ? 8 : -8)
                            .offset(x: edge == .leading ? -dragBack : dragBack)
                            // `simultaneousGesture`, not `gesture`: the panel wraps a
                            // List (PresetListView/ThemeListView), which needs its own
                            // vertical scroll and swipe-to-delete untouched. The
                            // horizontal-dominance guard is what actually keeps the two
                            // from fighting — a vertical or diagonal-ish drag never
                            // moves `dragBack`, so it's free to reach the List below.
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 6)
                                    .onChanged { value in
                                        let horizontal = value.translation.width
                                        let vertical = value.translation.height
                                        guard abs(horizontal) > abs(vertical) * 1.5 else { return }
                                        let pull = edge == .leading ? -horizontal : horizontal
                                        dragBack = max(0, min(width, pull))
                                    }
                                    .onEnded { value in
                                        // No direction guard here, unlike onChanged above:
                                        // once a horizontal pull has already moved dragBack
                                        // off 0, it must always be resolved (closed or
                                        // snapped back) on release, even if the gesture
                                        // happened to end on a more-vertical note.
                                        let horizontal = value.translation.width
                                        let pull = edge == .leading ? -horizontal : horizontal
                                        if pull > width * 0.3 {
                                            close()
                                        } else {
                                            withAnimation(spring) { dragBack = 0 }
                                        }
                                    }
                            )
                    }
                    .ignoresSafeArea()
                }
            }
            .onChange(of: isPresented) { _, presented in
                if presented {
                    dragBack = width
                    mounted = true
                    withAnimation(spring) { dragBack = 0 }
                } else {
                    withAnimation(spring) { dragBack = width }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                        if !isPresented { mounted = false }
                    }
                }
            }
    }

    /// Just flips the binding — `onChange(of: isPresented)` above is the one
    /// place that actually animates the close, so a drag-past-threshold and
    /// the panel's own Done button (which sets `isPresented` directly) end
    /// up producing the exact same animation instead of two slightly
    /// different ones.
    private func close() {
        isPresented = false
    }
}

extension View {
    /// Slides `content` in from `edge` instead of presenting it as a bottom sheet.
    func sidePanel<Content: View>(
        edge: HorizontalEdge,
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(SidePanel(edge: edge, isPresented: isPresented, panelContent: content))
    }
}
