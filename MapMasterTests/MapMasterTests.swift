import XCTest
@testable import MapMaster

/// Pure-logic tests: ranks, quiz construction, region gating, the bundled catalog and the streak math.
final class MapMasterTests: XCTestCase {

    // A small deterministic RNG so quiz-building tests are stable.
    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            return state
        }
    }

    private func samplePool() -> [Capital] {
        [
            Capital(country: "France", capital: "Paris", region: "europe", fact: "a"),
            Capital(country: "Germany", capital: "Berlin", region: "europe", fact: "b"),
            Capital(country: "Spain", capital: "Madrid", region: "europe", fact: "c"),
            Capital(country: "Italy", capital: "Rome", region: "europe", fact: "d"),
            Capital(country: "Japan", capital: "Tokyo", region: "asia", fact: "e"),
            Capital(country: "China", capital: "Beijing", region: "asia", fact: "f"),
            Capital(country: "Brazil", capital: "Brasilia", region: "americas", fact: "g"),
            Capital(country: "Peru", capital: "Lima", region: "americas", fact: "h"),
            Capital(country: "Egypt", capital: "Cairo", region: "africa", fact: "i"),
            Capital(country: "Kenya", capital: "Nairobi", region: "africa", fact: "j"),
            Capital(country: "Ghana", capital: "Accra", region: "africa", fact: "k"),
            Capital(country: "Mali", capital: "Bamako", region: "africa", fact: "l")
        ]
    }

    // MARK: Rank

    func testRankBoundaries() {
        XCTAssertEqual(Rank.forScore(10), .mapMaster)
        XCTAssertEqual(Rank.forScore(9), .globetrotter)
        XCTAssertEqual(Rank.forScore(8), .cartographer)
        XCTAssertEqual(Rank.forScore(7), .cartographer)
        XCTAssertEqual(Rank.forScore(6), .navigator)
        XCTAssertEqual(Rank.forScore(5), .navigator)
        XCTAssertEqual(Rank.forScore(4), .explorer)
        XCTAssertEqual(Rank.forScore(0), .explorer)
    }

    // MARK: QuizBuilder

    func testQuizBuilderProducesTenUniqueWellFormedQuestions() {
        var rng = SeededRNG(seed: 42)
        let qs = QuizBuilder.build(from: samplePool(), using: &rng)
        XCTAssertEqual(qs.count, 10)
        // No country repeats within a quiz.
        XCTAssertEqual(Set(qs.map(\.country)).count, qs.count)
        for q in qs {
            XCTAssertEqual(q.options.count, QuizBuilder.optionCount)
            XCTAssertTrue(q.options.contains(q.answer), "the correct answer must be among the options")
            XCTAssertEqual(Set(q.options).count, q.options.count, "options must be distinct")
        }
    }

    func testQuizBuilderEmptyForTinyPool() {
        var rng = SeededRNG(seed: 1)
        XCTAssertTrue(QuizBuilder.build(from: [], using: &rng).isEmpty)
        XCTAssertTrue(QuizBuilder.build(from: [samplePool()[0]], using: &rng).isEmpty)
    }

    func testHardModeDrawsDistractorsFromSameRegionWhenPossible() {
        // Africa has 4 entries in the pool → enough to fill 4 same-region options.
        var rng = SeededRNG(seed: 7)
        let africa = samplePool().filter { $0.regionValue == .africa }
        let qs = QuizBuilder.build(from: africa, count: 4, hardMode: true, using: &rng)
        XCTAssertFalse(qs.isEmpty)
        let africanCapitals = Set(africa.map(\.capital))
        for q in qs {
            // Every option should be an African capital.
            XCTAssertTrue(Set(q.options).isSubset(of: africanCapitals))
        }
    }

    func testIsCorrect() {
        let q = QuizQuestion(capital: samplePool()[0], options: ["Paris", "Berlin", "Rome", "Madrid"])
        XCTAssertTrue(QuizBuilder.isCorrect(question: q, picked: "Paris"))
        XCTAssertFalse(QuizBuilder.isCorrect(question: q, picked: "Berlin"))
    }

    // MARK: Region gating

    func testFreeRegionGate() {
        XCTAssertTrue(Region.europe.isFree)
        XCTAssertTrue(Region.americas.isFree)
        XCTAssertFalse(Region.asia.isFree)
        XCTAssertFalse(Region.africa.isFree)
        XCTAssertFalse(Region.middleeast.isFree)
        XCTAssertFalse(Region.oceania.isFree)
    }

    func testCatalogAvailableHonoursProGate() {
        let catalog = CapitalCatalog(all: samplePool())
        let free = catalog.available(isPro: false)
        XCTAssertTrue(free.allSatisfy { $0.regionValue.isFree })
        XCTAssertTrue(free.contains { $0.regionValue == .europe })
        XCTAssertTrue(free.contains { $0.regionValue == .americas })
        XCTAssertFalse(free.contains { $0.regionValue == .asia })

        let all = catalog.available(isPro: true)
        XCTAssertEqual(all.count, samplePool().count)
    }

    // MARK: Bundled dataset

    func testBundledCatalogLoadsAndIsWellFormed() {
        let catalog = CapitalCatalog.load(bundle: Bundle(for: MapMasterTests.self))
        // The test bundle may not carry the app's resource; if it loaded the real file it should be
        // large and well-formed, otherwise the safe fallback (>= 4) must still be valid.
        XCTAssertGreaterThanOrEqual(catalog.all.count, 4)
        for cap in catalog.all {
            XCTAssertFalse(cap.country.isEmpty)
            XCTAssertFalse(cap.capital.isEmpty)
            XCTAssertFalse(cap.fact.isEmpty)
            XCTAssertNotNil(Region(rawValue: cap.region), "every region code must be valid: \(cap.region)")
        }
        // Country names are unique (so progress keys never collide).
        XCTAssertEqual(Set(catalog.all.map(\.country)).count, catalog.all.count)
    }

    // MARK: Mastery threshold

    func testMasteryThreshold() {
        let p = CountryProgress(country: "France", region: "europe", correctCount: 1)
        XCTAssertFalse(p.isMastered)
        p.correctCount = 2
        XCTAssertTrue(p.isMastered)
    }

    // MARK: Streak math

    private func days(_ offsets: [Int], cal: Calendar) -> Set<Date> {
        let today = cal.startOfDay(for: Date())
        return Set(offsets.compactMap { cal.date(byAdding: .day, value: -$0, to: today) })
    }

    func testCurrentStreakCountsTodayBackwards() {
        let cal = Calendar.current
        XCTAssertEqual(AppModel.currentStreak(days: days([0, 1, 2], cal: cal), cal: cal), 3)
    }

    func testCurrentStreakHoldsWhenTodayNotYetLogged() {
        let cal = Calendar.current
        XCTAssertEqual(AppModel.currentStreak(days: days([1, 2], cal: cal), cal: cal), 2)
    }

    func testCurrentStreakBreaksWithGap() {
        let cal = Calendar.current
        XCTAssertEqual(AppModel.currentStreak(days: days([0, 2, 3], cal: cal), cal: cal), 1)
        XCTAssertEqual(AppModel.currentStreak(days: [], cal: cal), 0)
    }

    func testLongestStreak() {
        let cal = Calendar.current
        XCTAssertEqual(AppModel.longestStreak(days: days([0, 1, 2, 5, 6], cal: cal), cal: cal), 3)
    }

    // MARK: Store

    @MainActor
    func testStoreProductID() {
        XCTAssertEqual(Store.productID, "mapmaster_pro_unlock")
    }
}
