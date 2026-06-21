import SwiftUI

/// Learn today's capital: country shown first, tap to reveal the capital + a factual line, then
/// mark it learned (which counts toward mastery).
struct LearnView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var revealed = false

    private var capital: Capital { appModel.todaysCapital }

    var body: some View {
        NavigationStack {
            ZStack {
                MMBackground()
                VStack(spacing: 24) {
                    Spacer(minLength: 8)

                    VStack(spacing: 8) {
                        RegionChip(region: capital.regionValue)
                        Text(capital.country)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("What is the capital?")
                            .font(.title3).foregroundStyle(.secondary)
                    }

                    ZStack {
                        if revealed {
                            VStack(spacing: 14) {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill").foregroundStyle(Color.mmAccent)
                                    Text(capital.capital)
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                }
                                Text(capital.fact)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        } else {
                            Button {
                                Haptics.soft()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { revealed = true }
                            } label: {
                                Label("Reveal capital", systemImage: "eye")
                                    .frame(maxWidth: .infinity).padding(.vertical, 4)
                            }
                            .prominentButton()
                            .accessibilityIdentifier("reveal")
                        }
                    }
                    .frame(minHeight: 160)

                    Spacer()

                    if revealed {
                        Button {
                            appModel.markLearned(capital)
                            Haptics.success()
                            dismiss()
                        } label: {
                            Text("Got it").frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .prominentButton()
                        .accessibilityIdentifier("got-it")
                    }
                }
                .padding(24)
            }
            .navigationTitle("Day \(appModel.campaignDayNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.mmAccent)
        }
    }
}
