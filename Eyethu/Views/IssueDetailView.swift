import SwiftUI
import MapKit

struct IssueDetailView: View {
    let issue: Issue
    @EnvironmentObject var store: IssueStore
    @State private var showShareSheet   = false
    @State private var isWatching       = false
    @State private var isUpdatingStatus = false
    @State private var isVoting         = false
    @State private var errorMessage: String?
    @State private var photos: [IssuePhoto] = []
    @State private var photoPage = 0
    @State private var showFullMap = false

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

                    // Status Badge (Moved up)
                    StatusBadge(status: issue.status)
                        .padding(.top, 8)

                    // Title + Voting Buttons
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.type.displayName)
                                .font(.system(size: 24, weight: .bold))
                            Text(issue.displayStreet)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()

                        // Still there? Yes / No
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Still there?")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                // Yes
                                Button { voteOnIssue("up") } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 11))
                                        Text("Yes").font(.system(size: 11, weight: .bold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                    .foregroundStyle(.green)
                                }
                                .disabled(isVoting)
                                .buttonStyle(.plain)

                                // No
                                Button { voteOnIssue("down") } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11))
                                        Text("No").font(.system(size: 11, weight: .bold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                                    .foregroundStyle(.red)
                                }
                                .disabled(isVoting)
                                .buttonStyle(.plain)
                            }
                        }
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
                        MetaItem(icon: "checkmark.circle.fill", label: "\(issue.reportCount ?? 1) said yes",  title: "Still there")
                        MetaItem(icon: "xmark.circle.fill",    label: "\(issue.disagreeCount ?? 0) said no",   title: "No longer")
                        
                        MetaItem(
                            icon:  (issue.source ?? "web") == "whatsapp" ? "message.fill" : (issue.source ?? "ios") == "ios" ? "iphone" : "globe",
                            label: (issue.source ?? "web") == "whatsapp" ? "WhatsApp" : (issue.source ?? "ios") == "ios" ? "iOS App" : "Web",
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

                    // Mini map (Interactive)
                    if let coord = issue.coordinate {
                        Button {
                            showFullMap = true
                        } label: {
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
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showFullMap) {
            NavigationStack {
                if let coord = issue.coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))) {
                        Annotation(issue.type.displayName, coordinate: coord) {
                            IssueMapPin(issue: issue, isSelected: true)
                        }
                    }
                    .navigationTitle("Location")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showFullMap = false }
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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

    private func voteOnIssue(_ type: String) {
        isVoting = true
        errorMessage = nil
        Task {
            do {
                try await store.vote(issue: issue, type: type)
            } catch {
                errorMessage = error.localizedDescription
            }
            isVoting = false
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
