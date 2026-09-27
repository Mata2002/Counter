import Foundation
import WatchConnectivity

/// Keeps the Apple Watch in step: sends a snapshot of active tallies, receives counts from the wrist.
final class PhoneSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneSync()

    /// Called on the main thread when the watch counts: (tally id, reverse).
    var onCount: ((UUID, Bool) -> Void)?
    /// Called on the main thread when the watch finishes a tally.
    var onComplete: ((UUID) -> Void)?
    /// Called on the main thread when the watch asks for fresh data.
    var onSnapshotRequest: (() -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var isWatchAppInstalled: Bool {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return false }
        return WCSession.default.isWatchAppInstalled
    }

    func send(_ snapshot: WatchSnapshot) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext([WatchSnapshot.contextKey: data])
        if WCSession.default.isReachable {
            WCSession.default.sendMessage([WatchSnapshot.contextKey: data], replyHandler: nil, errorHandler: nil)
        }
    }

    private func handle(_ message: [String: Any]) {
        if let idString = message[WatchSnapshot.countKey] as? String, let id = UUID(uuidString: idString) {
            let reverse = message[WatchSnapshot.reverseKey] as? Bool ?? false
            DispatchQueue.main.async { self.onCount?(id, reverse) }
        } else if let idString = message[WatchSnapshot.completeKey] as? String, let id = UUID(uuidString: idString) {
            DispatchQueue.main.async { self.onComplete?(id) }
        } else if message[WatchSnapshot.requestKey] != nil {
            DispatchQueue.main.async { self.onSnapshotRequest?() }
        }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.onSnapshotRequest?() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handle(message)
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }
}
