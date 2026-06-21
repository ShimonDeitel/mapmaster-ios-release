import Foundation
import SwiftData
import SwiftUI

/// App state: owns the SwiftData store + the bundled catalog, derives mastery & streak, and tracks
/// the daily learn campaign. Stats are always derived from stored progress — never stored truth.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    let catalog: CapitalCatalog
    weak var store: Store?

    @Published private(set) var masteredCount = 0
    @Published private(set) var seenCount = 0
    @Published private(set) var totalQuizzes = 0
    @Published private(set) var bestScore = 0
    @Published private(set) var currentStreak = 0
    @Published private(set) var longestStreak = 0
    @Published private(set) var didQuizToday = false
    @Published private(set) var lastRank: Rank?
    /// Mastered count per region, recomputed on refresh (drives the Mastery view).
    @Published private(set) var masteredByRegion: [Region: Int] = [:]

    private let kCampaignDay = "mapmaster.campaign.dayIndex"
    private let kCampaignDate = "mapmaster.campaign.lastDate"

    init(container: ModelContainer, catalog: CapitalCatalog = .load()) {
        self.container = container
        self.catalog = catalog
        #if DEBUG
        seedIfRequested()
        #endif
        refresh()
    }

    // MARK: Container (local-only persistence)

    static func makeContainer() -> ModelContainer {
        let schema = Schema([CountryProgress.self, QuizResult.self])
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        // Last resort so the app never crashes on launch.
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Campaign (learn one capital per day)

    /// The pool the user is allowed to learn / be quizzed on, honouring the Pro region gate.
    var availablePool: [Capital] { catalog.available(isPro: store?.isPro == true) }

    /// Today's campaign capital. The index advances by one each new calendar day (looping the pool).
    var todaysCapital: Capital {
        let pool = availablePool
        guard !pool.isEmpty else {
            return Capital(country: "France", capital: "Paris", region: "europe",
                           fact: "The Seine river runs through the centre of the city.")
        }
        return pool[campaignDayIndex % pool.count]
    }

    /// 1-based day number in the campaign (for the "Day N" label).
    var campaignDayNumber: Int { campaignDayIndex + 1 }

    private var campaignDayIndex: Int {
        rolloverCampaignIfNeeded()
        return UserDefaults.standard.integer(forKey: kCampaignDay)
    }

    /// Advances the campaign index once per calendar day (idempotent within a day).
    private func rolloverCampaignIfNeeded() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: kCampaignDate) as? Date {
            let lastDay = cal.startOfDay(for: last)
            if today > lastDay {
                let days = cal.dateComponents([.day], from: lastDay, to: today).day ?? 1
                let next = defaults.integer(forKey: kCampaignDay) + max(1, days)
                defaults.set(next, forKey: kCampaignDay)
                defaults.set(today, forKey: kCampaignDate)
            }
        } else {
            defaults.set(0, forKey: kCampaignDay)
            defaults.set(today, forKey: kCampaignDate)
        }
    }

    // MARK: Recording

    /// Marks today's learn capital as studied (counts as one correct sighting toward mastery).
    func markLearned(_ capital: Capital) {
        let p = progress(for: capital)
        p.correctCount += 1
        p.lastSeen = .now
        try? container.mainContext.save()
        refresh()
    }

    /// Applies a finished quiz: per-question mastery updates + a QuizResult row.
    func recordQuiz(score: Int, total: Int, hardMode: Bool,
                    outcomes: [(country: String, region: Region, correct: Bool)]) {
        let ctx = container.mainContext
        for o in outcomes {
            guard let cap = catalog.capital(country: o.country) else { continue }
            let p = progress(for: cap)
            if o.correct { p.correctCount += 1 } else { p.wrongCount += 1 }
            p.lastSeen = .now
        }
        ctx.insert(QuizResult(score: score, total: total, hardMode: hardMode))
        try? ctx.save()
        refresh()
    }

    private func progress(for capital: Capital) -> CountryProgress {
        let country = capital.country
        let descriptor = FetchDescriptor<CountryProgress>(
            predicate: #Predicate { $0.country == country })
        if let existing = try? container.mainContext.fetch(descriptor).first {
            return existing
        }
        let created = CountryProgress(country: capital.country, region: capital.region)
        container.mainContext.insert(created)
        return created
    }

    func progressList() -> [CountryProgress] {
        (try? container.mainContext.fetch(FetchDescriptor<CountryProgress>())) ?? []
    }

    func isMastered(_ capital: Capital) -> Bool {
        progressList().first { $0.country == capital.country }?.isMastered ?? false
    }

    // MARK: Stats

    func refresh() {
        let progress = progressList()
        seenCount = progress.count
        masteredCount = progress.filter { $0.isMastered }.count

        var byRegion: [Region: Int] = [:]
        for p in progress where p.isMastered {
            if let r = Region(rawValue: p.region) { byRegion[r, default: 0] += 1 }
        }
        masteredByRegion = byRegion

        let quizzes = (try? container.mainContext.fetch(FetchDescriptor<QuizResult>())) ?? []
        totalQuizzes = quizzes.count
        bestScore = quizzes.map(\.score).max() ?? 0
        if let last = quizzes.max(by: { $0.date < $1.date }) {
            lastRank = Rank.forScore(last.score, total: last.total)
        }

        let cal = Calendar.current
        let days = Set(quizzes.map { cal.startOfDay(for: $0.date) })
        didQuizToday = days.contains(cal.startOfDay(for: .now))
        currentStreak = Self.currentStreak(days: days, cal: cal)
        longestStreak = Self.longestStreak(days: days, cal: cal)
    }

    nonisolated static func currentStreak(days: Set<Date>, cal: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        var day = cal.startOfDay(for: .now)
        // If today isn't logged yet, the streak still stands as of yesterday.
        if !days.contains(day) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day), days.contains(yesterday)
            else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    nonisolated static func longestStreak(days: Set<Date>, cal: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var best = 1, run = 1
        for i in 1..<sorted.count {
            if let prev = cal.date(byAdding: .day, value: 1, to: sorted[i - 1]), prev == sorted[i] {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }

    // MARK: Account deletion

    /// Erase all on-device progress (used by Delete Account).
    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: CountryProgress.self)
        try? ctx.delete(model: QuizResult.self)
        try? ctx.save()
        UserDefaults.standard.removeObject(forKey: kCampaignDay)
        UserDefaults.standard.removeObject(forKey: kCampaignDate)
        refresh()
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let n = env["MAPMASTER_SEED"].flatMap(Int.init), n > 0 else { return }
        let ctx = container.mainContext
        if ((try? ctx.fetch(FetchDescriptor<QuizResult>()))?.isEmpty ?? true) {
            let cal = Calendar.current
            for offset in 0..<n {
                if let day = cal.date(byAdding: .day, value: -offset, to: .now) {
                    ctx.insert(QuizResult(date: day, score: 7 + offset % 4, total: 10))
                }
            }
            for cap in catalog.all.prefix(20) {
                ctx.insert(CountryProgress(country: cap.country, region: cap.region,
                                           correctCount: 3, wrongCount: 0))
            }
            try? ctx.save()
        }
    }
    #endif
}
