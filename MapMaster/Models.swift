import Foundation
import SwiftData

/// Per-country mastery progress. One row per country the user has answered at least once.
/// All properties have defaults and there are no unique constraints, so the schema is
/// CloudKit-mirroring compatible (private database).
@Model
final class CountryProgress {
    /// The country name (matches `Capital.country` / `Capital.id`).
    var country: String = ""
    var region: String = "europe"
    var correctCount: Int = 0
    var wrongCount: Int = 0
    var lastSeen: Date = Date.now

    init(country: String = "", region: String = "europe",
         correctCount: Int = 0, wrongCount: Int = 0, lastSeen: Date = .now) {
        self.country = country
        self.region = region
        self.correctCount = correctCount
        self.wrongCount = wrongCount
        self.lastSeen = lastSeen
    }

    /// A country is "mastered" once it has been answered correctly at least twice.
    var isMastered: Bool { correctCount >= CountryProgress.masteryThreshold }

    static let masteryThreshold = 2
}

/// One completed daily quiz. Used for the streak, the best score and the rank history.
@Model
final class QuizResult {
    var id: UUID = UUID()
    var date: Date = Date.now
    var score: Int = 0
    var total: Int = 10
    var hardMode: Bool = false

    init(id: UUID = UUID(), date: Date = .now, score: Int = 0,
         total: Int = 10, hardMode: Bool = false) {
        self.id = id
        self.date = date
        self.score = score
        self.total = total
        self.hardMode = hardMode
    }
}

/// Rank label awarded for a quiz score out of 10. Pure, deterministic, testable.
enum Rank: String, CaseIterable {
    case explorer = "Explorer"
    case navigator = "Navigator"
    case cartographer = "Cartographer"
    case globetrotter = "Globetrotter"
    case mapMaster = "MapMaster"

    /// 0–4 Explorer, 5–6 Navigator, 7–8 Cartographer, 9 Globetrotter, 10 MapMaster.
    static func forScore(_ score: Int, total: Int = 10) -> Rank {
        let pct = total > 0 ? Double(score) / Double(total) : 0
        switch pct {
        case 1.0...: return .mapMaster
        case 0.9..<1.0: return .globetrotter
        case 0.7..<0.9: return .cartographer
        case 0.5..<0.7: return .navigator
        default: return .explorer
        }
    }

    var symbol: String {
        switch self {
        case .explorer: return "binoculars"
        case .navigator: return "location.north.line"
        case .cartographer: return "map"
        case .globetrotter: return "airplane"
        case .mapMaster: return "crown"
        }
    }
}
