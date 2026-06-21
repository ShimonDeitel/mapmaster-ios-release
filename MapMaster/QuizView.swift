import SwiftUI

/// The 90-second daily quiz. A pre-quiz setup (region + hard mode for Pro), the timed run,
/// and the result screen with score, rank and share.
struct QuizView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @StateObject private var engine = QuizEngine()
    @AppStorage("mapmaster.haptics") private var hapticsEnabled = true

    @State private var phase: Phase = .setup
    @State private var selectedRegion: Region? = nil   // nil = mixed (all available)
    @State private var hardMode = false
    @State private var showPaywall = false

    private enum Phase { case setup, playing, result }

    var body: some View {
        ZStack {
            MMBackground()
            switch phase {
            case .setup: setupView
            case .playing: playingView
            case .result: ResultView(engine: engine, hardMode: hardMode) { dismiss() }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onChange(of: engine.isFinished) { _, finished in
            if finished { withAnimation { phase = .result } }
        }
    }

    // MARK: Setup

    private var pool: [Capital] {
        if let r = selectedRegion { return appModel.catalog.capitals(in: r) }
        return appModel.availablePool
    }

    private var setupView: some View {
        VStack(spacing: 22) {
            HStack {
                Button { engine.cancel(); dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("quiz-close")
                Spacer()
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Image(systemName: "timer").font(.system(size: 44)).foregroundStyle(Color.mmAccent)
                Text("Daily Quiz").font(.largeTitle.weight(.heavy))
                Text("\(QuizBuilder.questionCount) capitals · \(QuizEngine.duration) seconds")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            regionPicker

            if store.isPro {
                Toggle(isOn: $hardMode) {
                    Label("Hard mode", systemImage: "flame")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(Color.mmAccent)
                .padding(.horizontal)
            } else {
                Button { Haptics.tap(); showPaywall = true } label: {
                    HStack {
                        Label("Hard mode", systemImage: "flame")
                        Spacer()
                        Image(systemName: "lock.fill").font(.footnote)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal)
            }

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                engine.hapticsEnabled = hapticsEnabled
                engine.start(pool: pool, hardMode: hardMode && store.isPro)
                withAnimation { phase = .playing }
            } label: {
                Text("Start").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .prominentButton()
            .padding(.horizontal, 24)
            .disabled(pool.count < 2)
            .accessibilityIdentifier("quiz-begin")
        }
        .padding(.vertical, 24)
    }

    private var regionPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Region").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    mixedChip
                    ForEach(Region.allCases) { region in
                        let locked = !region.isFree && !store.isPro
                        RegionSelectChip(region: region,
                                         selected: selectedRegion == region,
                                         locked: locked) {
                            Haptics.tap()
                            if locked { showPaywall = true }
                            else { selectedRegion = (selectedRegion == region) ? nil : region }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var mixedChip: some View {
        Button {
            Haptics.tap(); selectedRegion = nil
        } label: {
            Text("Mixed").font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(selectedRegion == nil ? Color.mmAccent : Color.mmCard, in: Capsule())
                .foregroundStyle(selectedRegion == nil ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Playing

    private var playingView: some View {
        VStack(spacing: 18) {
            quizHeader
            if let q = engine.currentQuestion {
                VStack(spacing: 6) {
                    RegionChip(region: q.capital.regionValue, compact: true)
                    Text("Capital of")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(q.country)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                }
                .padding(.top, 8)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    ForEach(q.options, id: \.self) { option in
                        OptionButton(text: option, state: state(for: option, in: q)) {
                            pick(option, in: q)
                        }
                        .accessibilityIdentifier("option-\(option)")
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 18)
    }

    private var quizHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Button { engine.cancel(); dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(engine.index + 1)/\(engine.total)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                    Text("\(engine.secondsRemaining)")
                        .monospacedDigit()
                        .foregroundStyle(engine.secondsRemaining <= 10 ? Color.mmRed : .primary)
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.mmField).frame(height: 6)
                    Capsule().fill(Color.mmAccent)
                        .frame(width: max(0, geo.size.width * timeFraction), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)
            .animation(.linear(duration: 0.3), value: engine.secondsRemaining)
        }
    }

    private var timeFraction: Double {
        Double(engine.secondsRemaining) / Double(QuizEngine.duration)
    }

    private func state(for option: String, in q: QuizQuestion) -> OptionButton.OptionState {
        guard let revealed = engine.revealedAnswer else { return .idle }
        if option == revealed { return .correct }
        if option == engine.lastPicked { return .wrong }
        return .dimmed
    }

    private func pick(_ option: String, in q: QuizQuestion) {
        guard engine.revealedAnswer == nil else { return }
        engine.answer(option)
        // Brief reveal, then advance.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            engine.advance()
        }
    }
}
