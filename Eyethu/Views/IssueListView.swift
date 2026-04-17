import SwiftUI

struct IssueListView: View {
    @EnvironmentObject var store: IssueStore
    @State private var selectedStatus: IssueStatus? = nil
    @State private var selectedType: IssueType? = nil
    @State private var searchText = ""
    @State private var showFilter = false
    @State private var viewMode: ViewMode = .list

    enum ViewMode { case list, map }
    enum EntryFilter {
        case all
        case active
    }

    private let entryFilter: EntryFilter

    init(entryFilter: EntryFilter = .all) {
        self.entryFilter = entryFilter
    }

    var filtered: [Issue] {
        store.issues
            .filter { entryFilter != .active || $0.isActive }
            .filter { selectedStatus == nil || $0.status == selectedStatus }
            .filter { selectedType == nil || $0.type == selectedType }
            .filter {
                searchText.isEmpty ||
                $0.type.displayName.localizedCaseInsensitiveContains(searchText) ||
                ($0.streetAddress ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Map / List toggle
            Picker("View", selection: $viewMode) {
                Text("Map").tag(ViewMode.map)
                Text("List").tag(ViewMode.list)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Status filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All", isSelected: selectedStatus == nil) {
                        selectedStatus = nil
                    }
                    ForEach(IssueStatus.allCases, id: \.self) { status in
                        FilterChip(label: status.displayName, isSelected: selectedStatus == status) {
                            selectedStatus = selectedStatus == status ? nil : status
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            if viewMode == .list {
                listContent
            } else {
                IssueMapView()
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search issues")
        .navigationTitle("Issues")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilter.toggle()
                } label: {
                    Label("Filter", systemImage: selectedType != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.teal)
                }
            }
        }
        .sheet(isPresented: $showFilter) {
            FilterSheet(selectedType: $selectedType)
        }
        .onAppear {
            if entryFilter == .active {
                viewMode = .list
            }
        }
    }

    private var listContent: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Issues Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try adjusting your filters.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { issue in
                    NavigationLink(destination: IssueDetailView(issue: issue)) {
                        IssueRowView(issue: issue)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.teal : Color(.systemGray5), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct FilterSheet: View {
    @Binding var selectedType: IssueType?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Issue Type") {
                    Button("All Types") {
                        selectedType = nil
                        dismiss()
                    }
                    .foregroundStyle(selectedType == nil ? .teal : .primary)

                    ForEach(IssueType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                IssueTypeGlyph(type: type, size: 16, color: selectedType == type ? .teal : .primary)
                                Text(type.displayName)
                            }
                                .foregroundStyle(selectedType == type ? .teal : .primary)
                        }
                    }
                }
            }
            .navigationTitle("Filter Issues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.teal)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        IssueListView()
            .environmentObject(IssueStore())
    }
}
