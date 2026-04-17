import SwiftUI
import MapKit

struct IssueMapView: View {
    @EnvironmentObject var store: IssueStore
    @State private var selectedIssue: Issue? = nil
    @State private var isRecentering = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    )

    private var mappableIssues: [Issue] {
        store.issues.filter { $0.coordinate != nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(mappableIssues) { issue in
                    if let coord = issue.coordinate {
                        Annotation(issue.type.displayName, coordinate: coord) {
                            IssueMapPin(issue: issue, isSelected: selectedIssue?.id == issue.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedIssue = selectedIssue?.id == issue.id ? nil : issue
                                    }
                                }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea(edges: .bottom)

            if let issue = selectedIssue {
                IssueMapCallout(issue: issue) { selectedIssue = nil }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }

            VStack {
                Spacer()

                HStack {
                    Spacer()

                    Button {
                        recenterToUserLocation()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.regularMaterial)
                                .frame(width: 42, height: 42)
                                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)

                            if isRecentering {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.bottom, selectedIssue == nil ? 24 : 140)
                }
            }
        }
        .onAppear {
            // Centre map on first issue with coordinates
            if let first = mappableIssues.first, let coord = first.coordinate {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                ))
            }
        }
    }

    private func recenterToUserLocation() {
        guard !isRecentering else { return }

        isRecentering = true
        Task {
            defer { isRecentering = false }

            do {
                let location = try await LocationHelper.shared.requestLocation()
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        cameraPosition = .region(region)
                        selectedIssue = nil
                    }
                }
            } catch {
                return
            }
        }
    }
}

struct IssueMapPin: View {
    let issue: Issue
    let isSelected: Bool

    private var pinColor: Color {
        switch issue.status {
        case .open:       return issue.type.color
        case .inProgress: return .teal
        case .resolved:   return .green
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: isSelected ? 40 : 30, height: isSelected ? 40 : 30)
                .shadow(color: pinColor.opacity(0.4), radius: isSelected ? 8 : 4)
            IssueTypeGlyph(
                type: issue.type,
                size: isSelected ? 16 : 12,
                weight: .semibold,
                color: .white
            )
        }
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

struct IssueMapCallout: View {
    let issue: Issue
    let onDismiss: () -> Void

    var body: some View {
        NavigationLink(destination: IssueDetailView(issue: issue)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(issue.type.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                            StatusBadge(status: issue.status)
                        }
                        Text(issue.displayAddress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let desc = issue.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)

                Divider()

                HStack {
                    Image(systemName: "info.circle")
                    Text("View Details")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.teal)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        IssueMapView().environmentObject(IssueStore())
    }
}
