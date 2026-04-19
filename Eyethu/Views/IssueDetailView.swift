import SwiftUI
import MapKit

struct IssueDetailView: View {
    let issue: Issue
    @EnvironmentObject var store: IssueStore
    @State private var showShareSheet   = false
    @State private var isWatching       = false
    @State private var isUpdatingStatus = false
    @State private var errorMessage: String?
    @State private var photos: [IssuePhoto] = []
    @State private var photoPage = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Photo carousel (swipe left/right) ──────────────────────
                let allPhotoURLs: [String] = {
                    var urls = photos.map(\.url)
                    // legacy single image_url fallback
                    if urls.isEmpty, let u = issue.imageURL { urls = [u] }
                    return urls
                }()

                if !allPhotoURLs.isEmpty {
                    ZStack(alignment: .bottom) {
                        TabView(selection: $photoPage) {
                            ForEach(Array(allPhotoURLs.enumerated()), id: \.offset) { idx, urlStr in
                                if let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().scaledToFill()
                                                .frame(maxWidth: .infinity).frame(height: 260)
                                                .clipped()
                                        case .failure:
                                            heroPlaceholder
                                        default:
                                            ZStack {
                                                Rectangle().fill(Color(.systemGray5)).frame(height: 260)
                                                ProgressView()
                                            }
                                        }
                                    }
                                    .tag(idx)
                                }
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: allPhotoURLs.count > 1 ? .always : .never))
                        .frame(height: 260)

                        // Photo count badge
                        if allPhotoURLs.count > 1 {
                            Text("\(photoPage + 1) / \(allPhotoURLs.count)")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(.black.opacity(0.45), in: Capsule())
                                .foregroundStyle(.white)
                                .padding(.bottom, 24)
                        }
                    }
                } else {
                    heroPlaceholder
                }

                VStack(alignment: .leading, spacing: 16) {

                    // Title + status
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.type.displayName)
                                .font(.system(size: 22, weight: .bold))
                            Text(issue.displayStreet)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(status: issue.status)
                    }

                    if let desc = issue.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }

                    Divider()

                    // Status changer (admin-friendly)
                    if store.currentUser?.can("issues.update_status") == true {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Update Status")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(IssueStatus.allCases, id: \.self) { s in
                                    Button {
                                        updateStatus(s)
                                    } label: {
                                        Text(s.displayName)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(issue.status == s ? statusColor(s) : Color(.systemGray5), in: Capsule())
                                            .foregroundStyle(issue.status == s ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isUpdatingStatus)
                                }
                                if isUpdatingStatus {
                                    ProgressView().scaleEffect(0.7)
                                }
                            }
                        }
                        Divider()
                    }

                    // Meta grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        MetaItem(icon: "number",      label: "#\(issue.id)",                    title: "Issue ID")
                        MetaItem(icon: "clock",       label: issue.createdAt.shortFormatted,    title: "Reported")
                        if let ward = issue.ward {
                            MetaItem(icon: "mappin",  label: ward,                              title: "Ward")
                        }
                        MetaItem(icon: "person.2",    label: "\(issue.reportCount) report(s)",  title: "Reports")
                        MetaItem(
                            icon:  issue.source == "whatsapp" ? "message.fill" : issue.source == "ios" ? "iphone" : "globe",
                            label: issue.source == "whatsapp" ? "WhatsApp" : issue.source == "ios" ? "iOS App" : "Web",
                            title: "Source"
                        )
                        if let muni = issue.municipality {
                            MetaItem(icon: "building.2", label: muni, title: "Municipality")
                        }
                        MetaItem(
                            icon:  "photo.on.rectangle.angled",
                            label: photos.isEmpty ? (issue.imageURL != nil ? "1 photo" : "No photos") : "\(photos.count)/5 photo\(photos.count == 1 ? "" : "s")",
                            title: "Photos"
                        )
                    }

                    // Error banner
                    if let msg = errorMessage {
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(10)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }

                    Divider()

                    // Mini map
                    if let coord = issue.coordinate {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                        ))) {
                            Annotation(issue.type.displayName, coordinate: coord) {
                                IssueMapPin(issue: issue, isSelected: true)
                            }
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .disabled(true)
                    }
                }
                .padding(20)
            }
        }
        .task {
            // Fetch photos separately (list API doesn't include them)
            if let fetched = try? await APIService.shared.fetchPhotos(issueId: issue.id) {
                photos = fetched
            }
        }
        .navigationTitle("Issue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    withAnimation { isWatching.toggle() }
                } label: {
                    Label(isWatching ? "Watching" : "Watch",
                          systemImage: isWatching ? "heart.fill" : "heart")
                        .foregroundStyle(isWatching ? .red : .secondary)
                }
                Spacer()
                Button { showShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["\(issue.type.displayName) at \(issue.displayStreet)"])
        }
    }

    private func updateStatus(_ status: IssueStatus) {
        guard status != issue.status else { return }
        isUpdatingStatus = true
        errorMessage = nil
        Task {
            do {
                try await store.updateStatus(issue: issue, status: status)
            } catch {
                errorMessage = error.localizedDescription
            }
            isUpdatingStatus = false
        }
    }

    private func statusColor(_ s: IssueStatus) -> Color {
        switch s {
        case .open:       return issue.type.color
        case .inProgress: return .teal
        case .resolved:   return .green
        }
    }

    private var heroPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    colors: [typeColor.opacity(0.3), typeColor.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 220)
            VStack(spacing: 12) {
                IssueTypeGlyph(type: issue.type, size: 60, weight: .thin, color: typeColor.opacity(0.6))
                Text("No photo attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var typeColor: Color { issue.type.color }
}

struct MetaItem: View {
    let icon: String
    let label: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        IssueDetailView(issue: IssueStore().issues[0])
            .environmentObject(IssueStore())
    }
}
