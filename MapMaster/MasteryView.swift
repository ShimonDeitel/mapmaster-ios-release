import SwiftUI

/// The Pro mastery map: a per-region progress overview plus a browsable, searchable country list
/// showing which capitals are mastered.
struct MasteryView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var filter: Region? = nil

    private var masteredSet: Set<String> {
        Set(appModel.progressList().filter { $0.isMastered }.map(\.country))
    }

    private var filtered: [Capital] {
        var list = filter == nil ? appModel.catalog.all : appModel.catalog.capitals(in: filter!)
        if !search.isEmpty {
            let q = search.lowercased()
            list = list.filter { $0.country.lowercased().contains(q) || $0.capital.lowercased().contains(q) }
        }
        return list.sorted { $0.country < $1.country }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MMBackground()
                List {
                    Section {
                        overview
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }

                    Section {
                        filterRow
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                    }

                    Section("Countries (\(filtered.count))") {
                        ForEach(filtered) { cap in
                            row(cap)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $search, prompt: "Country or capital")
            }
            .navigationTitle("Mastery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.mmAccent)
            .onAppear { appModel.refresh() }
        }
    }

    private var overview: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                MetricTile(value: "\(appModel.masteredCount)", label: "Mastered")
                MetricTile(value: "\(appModel.catalog.all.count)", label: "Countries")
                MetricTile(value: "\(percent)%", label: "Complete")
            }
            VStack(spacing: 12) {
                ForEach(Region.allCases) { region in
                    RegionMasteryBar(region: region,
                                     mastered: appModel.masteredByRegion[region] ?? 0,
                                     total: appModel.catalog.count(in: region))
                }
            }
            .mmCard()
        }
    }

    private var percent: Int {
        let total = appModel.catalog.all.count
        return total == 0 ? 0 : Int((Double(appModel.masteredCount) / Double(total) * 100).rounded())
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    Haptics.tap(); filter = nil
                } label: {
                    Text("All").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(filter == nil ? Color.mmAccent : Color.mmCard, in: Capsule())
                        .foregroundStyle(filter == nil ? .white : .primary)
                }
                .buttonStyle(.plain)
                ForEach(Region.allCases) { region in
                    RegionSelectChip(region: region, selected: filter == region, locked: false) {
                        Haptics.tap()
                        filter = (filter == region) ? nil : region
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func row(_ cap: Capital) -> some View {
        let mastered = masteredSet.contains(cap.country)
        return HStack(spacing: 12) {
            Circle().fill(cap.regionValue.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(cap.country).font(.body.weight(.medium))
                Text(cap.capital).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: mastered ? "checkmark.seal.fill" : "circle")
                .foregroundStyle(mastered ? Color.mmGreen : Color.mmHair)
        }
    }
}
