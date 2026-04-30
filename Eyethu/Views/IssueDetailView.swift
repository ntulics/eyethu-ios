import SwiftUI
import MapKit

private let issueWorkflowSteps = ["Received", "Assigned", "In Progress", "Resolved"]
private let issueEmailSteps = ["Pending", "Sent", "Delivered", "Opened"]

private func workflowStepIndex(for status: IssueStatus) -> Int {
    switch status {
    case .open:       return 0
    case .assigned:   return 1
    case .inProgress: return 2
    case .resolved:   return 3
    }
}

private func emailStepIndex(for status: EmailDeliveryStatus?) -> Int {
    switch status {
    case .pending:   return 0
    case .sent:      return 1
    case .delivered: return 2
    case .opened:    return 3
    case nil:        return -1
    }
}

private func emailStatusNote(for issue: Issue) -> String {
    switch issue.emailRawStatus {
    case "clicked":
        return "Recipient clicked through from the issue email."
    case "bounced":
        return "The latest municipality email bounced."
    case "soft_bounce":
        return "The latest municipality email soft-bounced and may retry."
    case "spam":
        return "The latest municipality email was flagged as spam."
    case "rejected":
        return "The latest municipality email was rejected by the provider."
    case "failed":
        return issue.emailError ?? "The latest municipality email failed to send."
    default:
        if let sentAt = issue.emailSentAt {
            return "Latest email update: \(issue.emailStatus?.displayName.lowercased() ?? "pending") on \(sentAt.shortFormatted)."
        }
        return "No municipality email has been sent for this issue yet."
    }
}

struct IssueDetailView: View {
    let issue: Issue
    @EnvironmentObject var store: IssueStore
    @State private var currentIssue: Issue
    @State private var showShareSheet   = false
    @State private var isWatching       = false
    @State private var isUpdatingStatus = false
    @State private var isVoting         = false
    @State private var errorMessage: String?
    @State private var photos: [IssuePhoto] = []
    @State private var photoPage = 0
    @State private var showFullMap = false

    init(issue: Issue) {
        self.issue = issue
        _currentIssue = State(initialValue: issue)
    }

    var body: some View {
        let current = currentIssue
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Photo carousel (swipe left/right) ──────────────────────
                let allPhotoURLs: [String] = {
                    var urls = photos.map(\.url)
                    // legacy single image_url fallback
                    if urls.isEmpty, let u = current.imageURL { urls = [u] }
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
                    StatusBadge(status: current.status)
                        .padding(.top, 8)

                    // Title + Voting Buttons
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(current.type.displayName)
                                .font(.system(size: 24, weight: .bold))
                            Text(current.displayStreet)
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

                    if let desc = current.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Issue Progress")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ProgressStepTrack(
                            steps: issueWorkflowSteps,
                            completedIndex: workflowStepIndex(for: current.status),
                            accentColor: statusColor(current.status)
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Email Progress")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ProgressStepTrack(
                            steps: issueEmailSteps,
                            completedIndex: emailStepIndex(for: current.emailStatus),
                            accentColor: .teal
                        )
                        Text(emailStatusNote(for: current))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
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
                                            .background(current.status == s ? statusColor(s) : Color(.systemGray5), in: Capsule())
                                            .foregroundStyle(current.status == s ? .white : .primary)
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
                        MetaItem(icon: "number",      label: "#\(current.id)",                    title: "Issue ID")
                        MetaItem(icon: "clock",       label: current.createdAt.shortFormatted,    title: "Reported")
                        if let ward = current.ward {
                            MetaItem(icon: "mappin",  label: ward,                              title: "Ward")
                        }
                        MetaItem(icon: "checkmark.circle.fill", label: "\(current.reportCount ?? 1) said yes",  title: "Still there")
                        MetaItem(icon: "xmark.circle.fill",    label: "\(current.disagreeCount ?? 0) said no",   title: "No longer")
                        
                        MetaItem(
                            icon:  (current.source ?? "web") == "whatsapp" ? "message.fill" : (current.source ?? "ios") == "ios" ? "iphone" : "globe",
                            label: (current.source ?? "web") == "whatsapp" ? "WhatsApp" : (current.source ?? "ios") == "ios" ? "iOS App" : "Web",
                            title: "Source"
                        )
                        if let muni = current.municipality {
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
                    if let coord = current.coordinate {
                        Button {
                            showFullMap = true
                        } label: {
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: coord,
                                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                            ))) {
                                Annotation(current.type.displayName, coordinate: coord) {
                                    IssueMapPin(issue: current, isSelected: true)
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
                if let coord = current.coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))) {
                        Annotation(current.type.displayName, coordinate: coord) {
                            IssueMapPin(issue: current, isSelected: true)
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
            if let refreshed = try? await APIService.shared.fetchIssue(id: issue.id) {
                currentIssue = refreshed
            }
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
            ShareSheet(items: ["\(current.type.displayName) at \(current.displayStreet)"])
        }
    }

    private func updateStatus(_ status: IssueStatus) {
        guard status != currentIssue.status else { return }
        isUpdatingStatus = true
        errorMessage = nil
        Task {
            do {
                try await store.updateStatus(issue: currentIssue, status: status)
                if let refreshed = try? await APIService.shared.fetchIssue(id: currentIssue.id) {
                    currentIssue = refreshed
                }
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
                try await store.vote(issue: currentIssue, type: type)
                if let refreshed = try? await APIService.shared.fetchIssue(id: currentIssue.id) {
                    currentIssue = refreshed
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isVoting = false
        }
    }

    private func statusColor(_ s: IssueStatus) -> Color {
        switch s {
        case .open:       return currentIssue.type.color
        case .assigned:   return Color(hex: "#FF8A1F")
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
                IssueTypeGlyph(type: currentIssue.type, size: 60, weight: .thin, color: typeColor.opacity(0.6))
                Text("No photo attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var typeColor: Color { currentIssue.type.color }
}

struct ProgressStepTrack: View {
    let steps: [String]
    let completedIndex: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 0) {
                    VStack(spacing: 7) {
                        Circle()
                            .fill(index <= completedIndex ? accentColor : Color(.systemGray5))
                            .frame(width: 12, height: 12)
                        Text(step)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(index <= completedIndex ? .primary : .secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < completedIndex ? accentColor : Color(.systemGray5))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                            .offset(y: -10)
                            .padding(.horizontal, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .padding(.top, 4)
    }
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
