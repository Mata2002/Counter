import Foundation
import Observation

/// What sheet or screen is showing.
@MainActor
@Observable
final class Router {
    static let shared = Router()

    enum Editor: Identifiable {
        case newTally(folderID: UUID?, template: Tally?)
        case editTally(Tally)
        case newFolder
        /// A new folder that starts with this tally in it (a tally dropped on "New folder").
        case newFolderHolding(UUID)
        case editFolder(TallyFolder)

        var id: String {
            switch self {
            case .newTally(let folderID, let template): return "new-\(folderID?.uuidString ?? "")-\(template?.id.uuidString ?? "")"
            case .editTally(let t): return "edit-\(t.id)"
            case .newFolder: return "new-folder"
            case .newFolderHolding(let id): return "new-folder-\(id)"
            case .editFolder(let f): return "edit-folder-\(f.id)"
            }
        }
    }

    enum SettingsPage: String, Hashable {
        case themes, finished, archive, hidden
    }

    /// The tally open on the counting stage.
    var stageTallyID: UUID?
    var editor: Editor?
    var showSettings = false
    var settingsPath: [SettingsPage] = []
    /// For screenshots: open the stage with the celebration already showing.
    var celebrateOnOpen = false
    /// For screenshots: the Home Screen widgets, drawn in the app.
    var showWidgetGallery = false

    func openTally(_ id: UUID) {
        editor = nil
        showSettings = false
        stageTallyID = id
    }

    func open(_ url: URL) {
        guard url.scheme == "tallyho" else { return }
        switch url.host {
        case "tally":
            if let id = UUID(uuidString: url.lastPathComponent) { openTally(id) }
        case "new":
            stageTallyID = nil
            editor = .newTally(folderID: nil, template: nil)
        default:
            break
        }
    }

    func openForScreenshot(_ screen: String) {
        let store = TallyStore.shared
        let first = store.sorted(store.homeTallies(showHidden: false), by: .lastUsed)
        switch screen {
        case "stage":
            stageTallyID = first.first { $0.name == "Push-ups" }?.id ?? first.first?.id
        case "stagedown":
            stageTallyID = first.first { $0.direction == .down }?.id
        case "stagefree":
            stageTallyID = first.first { !$0.hasGoal }?.id
        case "celebrate":
            celebrateOnOpen = true
            stageTallyID = first.first { $0.name == "Push-ups" }?.id ?? first.first?.id
        case "editor":
            if let t = first.first { editor = .editTally(t) }
        case "new":
            editor = .newTally(folderID: nil, template: nil)
        case "settings":
            showSettings = true
        case "themes":
            showSettings = true
            settingsPath = [.themes]
        case "finished":
            showSettings = true
            settingsPath = [.finished]
        case "widgets":
            showWidgetGallery = true
        case "archive":
            showSettings = true
            settingsPath = [.archive]
        default:
            break
        }
    }
}
