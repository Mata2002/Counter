import Foundation

/// Sample data for screenshots and first-look previews. Only used when the app is launched with `-demo`;
/// it then works on a temporary file, so real data is never touched.
enum DemoData {
    static func make() -> TallyData {
        let now = Date()
        func ago(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

        let water = TallyFolder(name: "Water drinks", emoji: "💧", colorIndex: 1, createdAt: ago(20))
        let fitness = TallyFolder(name: "Workout", emoji: "💪", colorIndex: 3, createdAt: ago(18))
        let reading = TallyFolder(name: "Reading", emoji: "📚", colorIndex: 4, createdAt: ago(15))

        var glasses = Tally(name: "Glasses today", emoji: "🥤", colorIndex: 1, tags: ["health"], folderID: water.id,
                            direction: .up, start: 0, target: 8, createdAt: ago(1))
        glasses.value = 5; glasses.lastUsedAt = ago(0.02); glasses.taps = 5; glasses.firstCountAt = ago(0.5)

        var pushups = Tally(name: "Push-ups", emoji: "💪", colorIndex: 0, tags: ["strength", "daily"], folderID: fitness.id,
                            direction: .up, start: 20, target: 70, step: 5, undoStep: 5, createdAt: ago(3))
        pushups.value = 45; pushups.lastUsedAt = ago(0.2); pushups.taps = 5; pushups.firstCountAt = ago(2)

        var laps = Tally(name: "Laps left", emoji: "🏊", colorIndex: 5, tags: ["swim"], folderID: fitness.id,
                         direction: .down, start: 40, target: 0, createdAt: ago(2))
        laps.value = 14; laps.lastUsedAt = ago(0.6); laps.taps = 26; laps.firstCountAt = ago(1)

        var pages = Tally(name: "Pages of Dune", emoji: "📖", colorIndex: 4, tags: ["books"], folderID: reading.id,
                          direction: .up, start: 120, target: 400, step: 10, undoStep: 10, createdAt: ago(9))
        pages.value = 310; pages.lastUsedAt = ago(1.5); pages.taps = 19; pages.firstCountAt = ago(8)

        var birds = Tally(name: "Birds spotted", emoji: "🐦", colorIndex: 2, tags: ["outside"], createdAt: ago(6))
        birds.value = 23; birds.lastUsedAt = ago(0.9); birds.taps = 23

        var movie = Tally(name: "Plot holes", emoji: "🍿", colorIndex: 3, tags: ["fun"], createdAt: ago(0.3))
        movie.value = 7; movie.lastUsedAt = ago(0.05); movie.taps = 7

        var oldWater = Tally(name: "Bottles this week", emoji: "🍶", colorIndex: 1, tags: ["health"], folderID: water.id,
                             direction: .up, start: 0, target: 14, createdAt: ago(12))
        oldWater.value = 14; oldWater.taps = 14; oldWater.firstCountAt = ago(11)
        oldWater.completedAt = ago(5); oldWater.goalReachedAt = ago(5); oldWater.folderNameSnapshot = water.name

        var squats = Tally(name: "Squats", emoji: "🦵", colorIndex: 0, tags: ["strength"], folderID: fitness.id,
                           direction: .up, start: 0, target: 100, step: 10, undoStep: 10, createdAt: ago(10))
        squats.value = 100; squats.taps = 10; squats.firstCountAt = ago(9)
        squats.completedAt = ago(7); squats.goalReachedAt = ago(7); squats.folderNameSnapshot = fitness.name

        var book = Tally(name: "Pages of Piranesi", emoji: "📘", colorIndex: 4, tags: ["books"], folderID: reading.id,
                         direction: .up, start: 0, target: 272, step: 10, createdAt: ago(14))
        book.value = 272; book.taps = 30; book.firstCountAt = ago(14)
        book.completedAt = ago(10); book.goalReachedAt = ago(10); book.folderNameSnapshot = reading.name

        return TallyData(tallies: [glasses, pushups, laps, pages, birds, movie, oldWater, squats, book],
                         folders: [water, fitness, reading])
    }

    /// A folder whose only tally is finished, to show the "start again" ghost.
    static func withEmptyWaterFolder() -> TallyData {
        var data = make()
        data.tallies.removeAll { $0.name == "Glasses today" }
        return data
    }
}
