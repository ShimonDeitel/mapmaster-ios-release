import SwiftUI

/// Shown when a quiz finishes: score, rank, and (Pro) a one-tap share. Records the quiz exactly
/// once via `.task` so re-renders never double-count.
struct ResultView: View {
    @ObservedObject var engine: QuizEngine
    let hardMode: Bool
    let onDone: () -> Void

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var recorded = false
    @State private var showShare = false
    @State private var showPaywall = false
    @State private var shareImage: UIImage?

    private var rank: Rank { Rank.forScore(engine.score, total: max(engine.total, 1)) }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)

            Image(systemName: rank.symbol)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Color.mmAccent)

            VStack(spacing: 6) {
                Text("\(engine.score)/\(engine.total)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                Text(rank.rawValue)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.mmAccent)
                Text(subtitle)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            resultCard

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Haptics.tap()
                    if store.isPro { renderAndShare() } else { showPaywall = true }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share result")
                        if !store.isPro { Image(systemName: "lock.fill").font(.footnote) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .softButton()

                Button { onDone() } label: {
                    Text("Done").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .prominentButton()
                .accessibilityIdentifier("result-done")
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .task {
            guard !recorded else { return }
            recorded = true
            appModel.recordQuiz(score: engine.score, total: engine.total,
                                hardMode: hardMode, outcomes: engine.outcomes)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showShare) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
    }

    private var subtitle: String {
        switch rank {
        case .mapMaster: return "Flawless. You are a MapMaster."
        case .globetrotter: return "So close to a clean sweep."
        case .cartographer: return "Strong run — keep climbing."
        case .navigator: return "Good progress. Try again to rank up."
        case .explorer: return "Every expert started here. Keep going."
        }
    }

    private var resultCard: some View {
        HStack(spacing: 12) {
            MetricTile(value: "\(appModel.currentStreak)", label: "Day streak")
            MetricTile(value: "\(appModel.bestScore)/10", label: "Best")
            MetricTile(value: hardMode ? "Hard" : "Normal", label: "Mode")
        }
        .padding(.horizontal)
    }

    @MainActor
    private func renderAndShare() {
        let card = ShareCard(score: engine.score, total: engine.total, rank: rank,
                             streak: appModel.currentStreak)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let img = renderer.uiImage {
            shareImage = img
            showShare = true
        }
    }
}

/// The rendered card image shared from a result (Pro). Original artwork — flat, no flags.
struct ShareCard: View {
    let score: Int
    let total: Int
    let rank: Rank
    let streak: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "globe").font(.title2)
                Text("MapMaster").font(.title3.weight(.bold))
                Spacer()
            }
            .foregroundStyle(.white)

            Spacer()

            Image(systemName: rank.symbol).font(.system(size: 60, weight: .semibold))
                .foregroundStyle(.white)
            Text("\(score)/\(total)").font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(rank.rawValue).font(.title2.weight(.bold)).foregroundStyle(.white.opacity(0.9))

            Spacer()

            HStack {
                Label("\(streak) day streak", systemImage: "flame.fill")
                Spacer()
                Text("Learn a capital a day")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(28)
        .frame(width: 360, height: 480)
        .background(Color.mmAccent)
    }
}
