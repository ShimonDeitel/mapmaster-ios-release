import SwiftUI

/// A single country / capital / fact. Pure value type loaded from the bundled `capitals.json`.
/// `id` is the country name (unique in the dataset) so progress can be keyed stably.
struct Capital: Identifiable, Codable, Equatable, Hashable {
    let country: String
    let capital: String
    let region: String
    let fact: String

    var id: String { country }
    var regionValue: Region { Region(rawValue: region) ?? .europe }
}

/// The six world regions used for the campaign, region filters and the colour chips
/// (a flat region colour chip — never detailed flag art).
enum Region: String, CaseIterable, Identifiable, Codable {
    case europe, asia, middleeast, africa, americas, oceania

    var id: String { rawValue }

    var label: String {
        switch self {
        case .europe: return "Europe"
        case .asia: return "Asia"
        case .middleeast: return "Middle East"
        case .africa: return "Africa"
        case .americas: return "Americas"
        case .oceania: return "Oceania"
        }
    }

    /// SF Symbol used as a small monochrome glyph beside the chip.
    var symbol: String {
        switch self {
        case .europe: return "building.columns"
        case .asia: return "mountain.2"
        case .middleeast: return "sun.max"
        case .africa: return "leaf"
        case .americas: return "globe.americas"
        case .oceania: return "water.waves"
        }
    }

    /// Flat colour chip per region (NOT a flag). All distinct, all readable on light & dark.
    var color: Color {
        switch self {
        case .europe: return Color(hex: "#007AFF")     // blue
        case .asia: return Color(hex: "#FF9500")       // orange
        case .middleeast: return Color(hex: "#AF52DE") // purple
        case .africa: return Color(hex: "#34C759")     // green
        case .americas: return Color(hex: "#FF2D55")   // pink/red
        case .oceania: return Color(hex: "#5AC8FA")    // teal
        }
    }

    /// Regions that are free in the campaign + daily quiz. The rest are a Pro unlock.
    static let freeRegions: Set<Region> = [.europe, .americas]

    var isFree: Bool { Region.freeRegions.contains(self) }
}

/// Loads and owns the bundled capitals dataset. Decoded once at launch.
struct CapitalCatalog {
    let all: [Capital]

    init(all: [Capital]) { self.all = all }

    /// Loads `capitals.json` from the app bundle. Falls back to a tiny built-in set so the app
    /// never shows an empty screen even if the resource is somehow missing.
    static func load(bundle: Bundle = .main) -> CapitalCatalog {
        if let url = bundle.url(forResource: "capitals", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Capital].self, from: data),
           !decoded.isEmpty {
            return CapitalCatalog(all: decoded)
        }
        return CapitalCatalog(all: Self.fallback)
    }

    func capitals(in region: Region) -> [Capital] {
        all.filter { $0.regionValue == region }
    }

    /// Capitals available for the current entitlement: free users only see the free regions.
    func available(isPro: Bool) -> [Capital] {
        isPro ? all : all.filter { $0.regionValue.isFree }
    }

    func capital(country: String) -> Capital? {
        all.first { $0.country == country }
    }

    /// Count of countries per region (for the mastery overview).
    func count(in region: Region) -> Int { capitals(in: region).count }

    private static let fallback: [Capital] = [
        Capital(country: "France", capital: "Paris", region: "europe",
                fact: "The Seine river runs through the centre of the city."),
        Capital(country: "Japan", capital: "Tokyo", region: "asia",
                fact: "One of the most populous metropolitan areas on Earth."),
        Capital(country: "Brazil", capital: "Brasilia", region: "americas",
                fact: "A planned capital shaped a bit like an aeroplane."),
        Capital(country: "Egypt", capital: "Cairo", region: "africa",
                fact: "The Nile River flows through the city.")
    ]
}
