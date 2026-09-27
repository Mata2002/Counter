import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// The watch's copy of your active tallies. Counts apply instantly on the wrist and are sent to the iPhone,
/// queued if the phone is out of reach.
@MainActor
@Observable
final class WatchStore {
    static let shared = WatchStore()

    private(set) var tallies: [WatchTally] = []
    private(set) var themeID: String = TallyTheme.fallback.id
    private(set) var lastSync: Date?

    var theme: TallyTheme { TallyTheme.named(themeID) ?? .fallback }

    private let storageKey = "watch.snapshot"
    @ObservationIgnored private let session = WatchSession()

    private init() {
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            tallies = Self.demo
            return
        }
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data) {
            apply(snapshot, persist: false)
        }
        session.onSnapshot = { [weak self] snapshot in self?.apply(snapshot, persist: true) }
        session.activate()
    }

    func tally(_ id: UUID) -> WatchTally? { tallies.first { $0.id == id } }

    /// Sample tallies for screenshots (`-demo`).
    private static var demo: [WatchTally] {
        var pushups = Tally(name: "Push-ups", emoji: "💪", colorIndex: 0, start: 20, target: 70, step: 5)
        pushups.value = 45
        var laps = Tally(name: "Laps left", emoji: "🏊", colorIndex: 5, direction: .down, start: 40, target: 0)
        laps.value = 14
        var water = Tally(name: "Glasses", emoji: "🥤", colorIndex: 1, target: 8)
        water.value = 5
        var birds = Tally(name: "Birds", emoji: "🐦", colorIndex: 2)
        birds.value = 23
        return [pushups, laps, water, birds].map { WatchTally($0, folderName: nil) }
    }

    func requestRefresh() { session.requestSnapshot() }

    private func apply(_ snapshot: WatchSnapshot, persist: Bool) {
        tallies = snapshot.tallies
        themeID = snapshot.themeID
        lastSync = snapshot.sentAt
        if persist, let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Counts once on the wrist. Returns true when this reached the goal.
    @discardableResult
    func count(_ id: UUID, reverse: Bool = false) -> Bool {
        guard let index = tallies.firstIndex(where: { $0.id == id }) else { return false }
        var t = tallies[index].asTally
        let reached = t.apply(reverse ? t.secondaryDelta : t.primaryDelta)
        tallies[index].value = t.value
        session.send([WatchSnapshot.countKey: id.uuidString, WatchSnapshot.reverseKey: reverse])
        WKInterfaceDevice.current().play(reached ? .success : (reverse ? .directionDown : .click))
        return reached
    }

    func finish(_ id: UUID) {
        tallies.removeAll { $0.id == id }
        session.send([WatchSnapshot.completeKey: id.uuidString])
        WKInterfaceDevice.current().play(.success)
    }
}

/// WatchConnectivity plumbing, kept apart from the observable store.
final class WatchSession: NSObject, WCSessionDelegate, @unchecked Sendable {
    var onSnapshot: (@MainActor (WatchSnapshot) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func requestSnapshot() {
        send([WatchSnapshot.requestKey: true])
    }

    /// Sends now if the phone is reachable; otherwise queues it for delivery.
    func send(_ message: [String: Any]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(message)
            }
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    private func decode(_ payload: [String: Any]) {
        guard let data = payload[WatchSnapshot.contextKey] as? Data,
              let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        Task { @MainActor in self.onSnapshot?(snapshot) }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        decode(session.receivedApplicationContext)
        if activationState == .activated { requestSnapshot() }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        decode(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        decode(message)
    }
}
