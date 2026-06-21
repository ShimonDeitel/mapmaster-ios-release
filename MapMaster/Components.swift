import SwiftUI

/// A small flat region colour chip (NOT a flag) with the region's glyph and label.
struct RegionChip: View {
    let region: Region
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(region.color).frame(width: 10, height: 10)
            if !compact {
                Text(region.label).font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, 6)
        .background(region.color.opacity(0.12), in: Capsule())
        .foregroundStyle(.primary)
    }
}

/// A selectable region filter pill; shows a lock when the region is Pro and the user isn't.
struct RegionSelectChip: View {
    let region: Region
    let selected: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(region.color).frame(width: 9, height: 9)
                Text(region.label).font(.subheadline.weight(.semibold))
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selected ? Color.mmAccent : Color.mmCard, in: Capsule())
            .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("region-\(region.rawValue)")
    }
}

/// The big learn card: country, its capital, a region chip and a factual line.
struct CapitalCard: View {
    let capital: Capital
    var revealed: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                RegionChip(region: capital.regionValue)
                Spacer()
                Image(systemName: "globe").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(capital.country)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill").foregroundStyle(Color.mmAccent)
                    Text(revealed ? capital.capital : "• • •")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(revealed ? .primary : .secondary)
                }
            }
            if revealed {
                Text(capital.fact)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mmCard()
    }
}

/// A multiple-choice answer button used in the quiz, with correct/wrong states after a pick.
struct OptionButton: View {
    let text: String
    /// nil = not yet answered; true = this is the correct answer; false = picked & wrong.
    let state: OptionState
    let action: () -> Void

    enum OptionState { case idle, correct, wrong, dimmed }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text).font(.headline)
                Spacer()
                switch state {
                case .correct: Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                case .wrong: Image(systemName: "xmark.circle.fill").foregroundStyle(.white)
                default: EmptyView()
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
    }

    private var background: Color {
        switch state {
        case .idle: return .mmCard
        case .correct: return .mmGreen
        case .wrong: return .mmRed
        case .dimmed: return .mmCard
        }
    }
    private var foreground: Color {
        switch state {
        case .correct, .wrong: return .white
        case .dimmed: return .secondary
        case .idle: return .primary
        }
    }
}

/// A small labelled metric tile used on Home and Mastery.
struct MetricTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.mmAccent)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.mmCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A horizontal mastery bar for one region: mastered / total with the region colour.
struct RegionMasteryBar: View {
    let region: Region
    let mastered: Int
    let total: Int

    private var fraction: Double { total == 0 ? 0 : Double(mastered) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: region.symbol).font(.footnote).foregroundStyle(region.color)
                Text(region.label).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(mastered)/\(total)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.mmField).frame(height: 8)
                    Capsule().fill(region.color)
                        .frame(width: max(0, geo.size.width * fraction), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

/// Wraps UIActivityViewController so we can share a rendered result card image.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

func mmss(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
