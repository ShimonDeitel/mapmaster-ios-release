import Foundation
import SwiftUI

/// One multiple-choice question: which capital belongs to `capital.country`.
struct QuizQuestion: Identifiable, Equatable {
    let id = UUID()
    let capital: Capital
    /// Four options (the correct capital plus three distractors), pre-shuffled.
    let options: [String]

    var country: String { capital.country }
    var answer: String { capital.capital }

    static func == (l: QuizQuestion, r: QuizQuestion) -> Bool { l.id == r.id }
}

/// Pure quiz construction + scoring. No timer, no UI — fully unit-testable.
enum QuizBuilder {
    static let questionCount = 10
    static let optionCount = 4

    /// Builds up to `count` questions from `pool`. Each question's distractors are drawn from the
    /// same pool (preferring the same region in Hard Mode for tougher choices). Deterministic when a
    /// seeded generator is supplied so tests are stable.
    static func build(from pool: [Capital],
                      count: Int = questionCount,
                      hardMode: Bool = false,
                      using rng: inout some RandomNumberGenerator) -> [QuizQuestion] {
        guard pool.count >= 2 else { return [] }
        let n = min(count, pool.count)
        let chosen = Array(pool.shuffled(using: &rng).prefix(n))

        return chosen.map { target in
            var distractorSource: [Capital]
            if hardMode {
                let sameRegion = pool.filter { $0.regionValue == target.regionValue && $0.country != target.country }
                // Fall back to the whole pool if a region is too small to fill the options.
                distractorSource = sameRegion.count >= (optionCount - 1) ? sameRegion
                    : pool.filter { $0.country != target.country }
            } else {
                distractorSource = pool.filter { $0.country != target.country }
            }
            let distractors = Array(distractorSource.shuffled(using: &rng).prefix(optionCount - 1)).map(\.capital)
            var options = distractors + [target.capital]
            options.shuffle(using: &rng)
            return QuizQuestion(capital: target, options: options)
        }
    }

    /// Convenience using the system RNG.
    static func build(from pool: [Capital], count: Int = questionCount, hardMode: Bool = false) -> [QuizQuestion] {
        var rng = SystemRandomNumberGenerator()
        return build(from: pool, count: count, hardMode: hardMode, using: &rng)
    }

    static func isCorrect(question: QuizQuestion, picked: String) -> Bool {
        picked == question.answer
    }
}

/// Runs a single timed quiz session: a 90-second countdown over 10 questions, tracking score and
/// per-question correctness. The clock is the only side effect; everything else is derived.
@MainActor
final class QuizEngine: ObservableObject {
    static let duration = 90  // seconds

    @Published private(set) var questions: [QuizQuestion] = []
    @Published private(set) var index = 0
    @Published private(set) var score = 0
    @Published private(set) var secondsRemaining = duration
    @Published private(set) var isRunning = false
    @Published private(set) var isFinished = false
    /// Per-question outcomes, in order (used to update mastery once at the end).
    @Published private(set) var outcomes: [(country: String, region: Region, correct: Bool)] = []
    /// Set briefly after an answer so the UI can flash green/red before advancing.
    @Published var lastPicked: String?
    @Published var revealedAnswer: String?

    var hapticsEnabled = true
    /// Called once when the quiz ends (time out or last question answered).
    var onFinish: ((_ score: Int, _ total: Int, _ outcomes: [(String, Region, Bool)]) -> Void)?

    private var timer: Timer?

    var total: Int { questions.count }
    var currentQuestion: QuizQuestion? { index < questions.count ? questions[index] : nil }
    var progress: Double { total == 0 ? 0 : Double(index) / Double(total) }

    func start(pool: [Capital], hardMode: Bool) {
        questions = QuizBuilder.build(from: pool, hardMode: hardMode)
        index = 0
        score = 0
        outcomes = []
        secondsRemaining = Self.duration
        isFinished = false
        lastPicked = nil
        revealedAnswer = nil
        guard !questions.isEmpty else { finish(); return }
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard isRunning else { return }
        secondsRemaining -= 1
        if secondsRemaining <= 0 {
            secondsRemaining = 0
            finish()
        }
    }

    /// Records the user's pick for the current question and advances. Returns whether it was right.
    @discardableResult
    func answer(_ picked: String) -> Bool {
        guard isRunning, let q = currentQuestion else { return false }
        let correct = QuizBuilder.isCorrect(question: q, picked: picked)
        if correct { score += 1 }
        outcomes.append((q.country, q.capital.regionValue, correct))
        lastPicked = picked
        revealedAnswer = q.answer
        if hapticsEnabled { correct ? Haptics.success() : Haptics.warning() }
        return correct
    }

    /// Moves to the next question (called after the brief answer reveal). Finishes at the end.
    func advance() {
        lastPicked = nil
        revealedAnswer = nil
        index += 1
        if index >= questions.count { finish() }
    }

    func cancel() {
        timer?.invalidate(); timer = nil
        isRunning = false
        isFinished = false
    }

    private func finish() {
        guard !isFinished else { return }
        timer?.invalidate(); timer = nil
        isRunning = false
        isFinished = true
        onFinish?(score, total, outcomes.map { ($0.country, $0.region, $0.correct) })
    }

    deinit { timer?.invalidate() }
}
