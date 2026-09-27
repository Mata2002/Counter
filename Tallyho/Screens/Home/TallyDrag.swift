import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A tally being dragged inside Tallyho. Declared in Config/Tallyho-Info.plist.
    static let tallyhoTally = UTType(exportedAs: "mmt.tallyho.tally")
}

/// What a dragged tally row carries: just its id.
struct TallyDragItem: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .tallyhoTally)
    }
}

/// The end of the list: tap to make a folder, or drop a tally here to start a folder with it.
struct NewFolderDropRow: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @State private var targeted = false

    var body: some View {
        Button {
            router.editor = .newFolder
        } label: {
            HStack(spacing: Space.m) {
                Image(systemName: "folder.badge.plus")
                    .font(.body.weight(.semibold))
                    .frame(width: 30)
                    .padding(.leading, Space.s)
                Text(targeted ? "Drop to start a new folder" : "New folder")
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
            }
            .foregroundStyle(targeted ? theme.actionColor : theme.text2Color)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                // Only while a tally hovers: an outline that says "this is a place to drop".
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.actionColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .background(theme.actionColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .opacity(targeted ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropDestination(for: TallyDragItem.self) { items, _ in
            guard let first = items.first else { return false }
            router.editor = .newFolderHolding(first.id)
            return true
        } isTargeted: { hovering in
            withAnimation(Motion.quick) { targeted = hovering }
        }
        .accessibilityHint("Or drag a tally here to start a folder with it.")
    }
}
