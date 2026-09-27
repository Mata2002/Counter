import SwiftUI

/// Hosts the home list and every sheet and full-screen cover.
struct RootView: View {
    @Environment(TallyStore.self) private var store
    @Environment(ThemeManager.self) private var themes
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    private struct StageItem: Identifiable { let id: UUID }

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            HomeView()
        }
        .fullScreenCover(item: Binding(
            get: { router.stageTallyID.map(StageItem.init) },
            set: { router.stageTallyID = $0?.id }
        )) { item in
            StageView(tallyID: item.id)
                .environment(store)
                .environment(themes)
                .environment(router)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
        }
        .sheet(item: $router.editor) { editor in
            EditorSheet(editor: editor)
                .environment(store)
                .environment(router)
                .themedSheet(theme)
        }
        .sheet(isPresented: $router.showSettings) {
            SettingsRoot()
                .environment(store)
                .environment(themes)
                .environment(router)
                .themedSheet(theme)
        }
        .overlay(alignment: .bottom) {
            UndoToast()
        }
    }
}

/// "Deleted Push-ups · Undo", fading out after a few seconds.
struct UndoToast: View {
    @Environment(TallyStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let message = store.undoMessage {
                HStack(spacing: Space.m) {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.textColor)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Undo") { withAnimation(Motion.standard) { store.undo() } }
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.actionColor)
                        .frame(minHeight: 44)
                }
                .padding(.leading, Space.l)
                .padding(.trailing, Space.m)
                .glassEffect(.regular, in: Capsule())
                .padding(.horizontal, Space.l)
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(Motion.standard) { store.dismissUndo() }
                }
            }
        }
        .animation(Motion.standard, value: store.undoMessage)
    }
}
