import Foundation

/// When each holiday theme is in season. US holidays use Gregorian rules (Easter and Thanksgiving are computed),
/// and Nowruz uses the system's Persian calendar (Farvardin 1–13, through Sizdah Bedar).
enum HolidayCalendar {
    static func isActive(_ id: String, on date: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 2000
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        switch id {
        case "newyear":
            return (month == 12 && day == 31) || (month == 1 && day == 1)
        case "valentine":
            return month == 2 && (13...14).contains(day)
        case "stpatricks":
            return month == 3 && (16...17).contains(day)
        case "easter":
            guard let easter = easterSunday(year: year),
                  let distance = calendar.dateComponents([.day], from: easter, to: calendar.startOfDay(for: date)).day
            else { return false }
            return (-2...1).contains(distance)
        case "july4":
            return month == 7 && (3...4).contains(day)
        case "halloween":
            return month == 10 && (24...31).contains(day)
        case "thanksgiving":
            guard month == 11, let thursday = thanksgiving(year: year) else { return false }
            return (thursday - 1...thursday + 3).contains(day)
        case "christmas":
            return month == 12 && (18...26).contains(day)
        case "nowruz":
            let persian = Calendar(identifier: .persian).dateComponents([.month, .day], from: date)
            return persian.month == 1 && (1...13).contains(persian.day ?? 0)
        default:
            return false
        }
    }

    /// Anonymous Gregorian algorithm.
    static func easterSunday(year: Int) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Day of month of the fourth Thursday in November.
    static func thanksgiving(year: Int) -> Int? {
        let calendar = Calendar(identifier: .gregorian)
        guard let first = calendar.date(from: DateComponents(year: year, month: 11, day: 1)) else { return nil }
        let weekday = calendar.component(.weekday, from: first) // 1 = Sunday, 5 = Thursday
        let firstThursday = 1 + (5 - weekday + 7) % 7
        return firstThursday + 21
    }

    /// The current occurrence (if in season) or the next one within about a year.
    static func occurrence(of id: String, from date: Date = Date()) -> (start: Date, end: Date)? {
        let calendar = Calendar(identifier: .gregorian)
        var day = calendar.startOfDay(for: date)
        if isActive(id, on: day) {
            while let previous = calendar.date(byAdding: .day, value: -1, to: day), isActive(id, on: previous) {
                day = previous
            }
        } else {
            var found = false
            for _ in 0..<400 {
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
                day = next
                if isActive(id, on: day) { found = true; break }
            }
            if !found { return nil }
        }
        var end = day
        while let next = calendar.date(byAdding: .day, value: 1, to: end), isActive(id, on: next) {
            end = next
        }
        return (day, end)
    }

    /// "Oct 24 – 31", with "Now · " while in season.
    static func label(for id: String, from date: Date = Date()) -> String {
        guard let range = occurrence(of: id, from: date) else { return "Not scheduled" }
        let calendar = Calendar(identifier: .gregorian)
        let startText = range.start.formatted(.dateTime.month(.abbreviated).day())
        let sameMonth = calendar.component(.month, from: range.start) == calendar.component(.month, from: range.end)
        let endText = sameMonth ? range.end.formatted(.dateTime.day()) : range.end.formatted(.dateTime.month(.abbreviated).day())
        let span = range.start == range.end ? startText : "\(startText) – \(endText)"
        return isActive(id, on: date) ? "Now · \(span)" : span
    }
}
