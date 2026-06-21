import SwiftUI

/// The hub: today's campaign capital, a one-tap daily quiz, mastery summary and quick links.
struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showLearn = false
    @State private var showQuiz = false
    @State private var showMastery = false
    @State private var showSettings = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                MMBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        learnCard
                        quizCard
                        statsRow
                        masteryButton
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("MapMaster")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showSettings = true } label: {
                        Image(systemName: "gearshape").foregroundStyle(Color.mmAccent)
                    }
                    .accessibilityIdentifier("settings-button")
                }
            }
            .sheet(isPresented: $showLearn) { LearnView() }
            .fullScreenCover(isPresented: $showQuiz) { QuizView() }
            .sheet(isPresented: $showMastery) {
                if store.isPro { MasteryView() } else { PaywallView() }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear { appModel.refresh() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(appModel.campaignDayNumber)")
                    .font(.headline).foregroundStyle(.secondary)
                Text(appModel.didQuizToday ? "Quiz done today" : "Ready for today")
                    .font(.subheadline)
                    .foregroundStyle(appModel.didQuizToday ? Color.mmGreen : .secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(Color.mmAccent)
                Text("\(appModel.currentStreak)").font(.title3.weight(.bold).monospacedDigit())
            }
            .mmPill()
        }
        .padding(.top, 4)
    }

    private var learnCard: some View {
        Button { Haptics.tap(); showLearn = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                Label("Today's capital", systemImage: "book")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mmAccent)
                CapitalCard(capital: appModel.todaysCapital,
                            revealed: appModel.isMastered(appModel.todaysCapital))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("learn-card")
    }

    private var quizCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Quiz").font(.title3.weight(.bold))
                    Text("10 capitals · 90 seconds").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "timer").font(.title2).foregroundStyle(Color.mmAccent)
            }
            Button { Haptics.tap(); showQuiz = true } label: {
                Text(appModel.didQuizToday ? "Play again" : "Start quiz")
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .prominentButton()
            .accessibilityIdentifier("start-quiz")
        }
        .mmCard()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            MetricTile(value: "\(appModel.bestScore)/10", label: "Best score")
            MetricTile(value: "\(appModel.masteredCount)", label: "Mastered")
            MetricTile(value: "\(appModel.longestStreak)", label: "Best streak")
        }
    }

    private var masteryButton: some View {
        Button {
            Haptics.tap()
            if store.isPro { showMastery = true } else { showPaywall = true }
        } label: {
            HStack {
                Image(systemName: "map")
                Text("Mastery map")
                Spacer()
                if !store.isPro { Image(systemName: "lock.fill").font(.footnote) }
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
            }
            .font(.headline)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.mmCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mastery-button")
    }
}
