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
    @State private var mapCenter = CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473)

    // Report-pin flow
    @State private var reportType: IssueType? = nil
    @State private var pendingReportCoordinate: CLLocationCoordinate2D? = nil
    @State private var showTypePicker  = false
    @State private var showReportSheet = false

    private var mappableIssues: [Issue] {
        store.issues.filter { $0.coordinate != nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Map ────────────────────────────────────────────────────────────
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(mappableIssues) { issue in
                    if let coord = issue.coordinate {
                        Annotation(issue.type.displayName, coordinate: coord) {
                            IssueMapPin(issue: issue, isSelected: selectedIssue?.id == issue.id)
                                .onTapGesture {
                                    guard reportType == nil else { return }
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedIssue = selectedIssue?.id == issue.id ? nil : issue
                                    }
                                }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .onMapCameraChange(frequency: .continuous) { context in
                mapCenter = context.region.center
            }

            // ── Crosshair (report mode only) — stays in ZStack at screen centre ─
            if let rt = reportType {
                ReportCrosshair(type: rt)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // ── Instruction banner (report mode) ──────────────────────────────
            if let rt = reportType {
                VStack {
                    Label {
                        Text("Pan to exact spot · tap **Report here**")
                            .font(.system(size: 12, weight: .medium))
                    } icon: {
                        IssueTypeGlyph(type: rt, size: 13, weight: .semibold, color: rt.color)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                    .padding(.top, 12)

                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Issue callout (normal mode) ────────────────────────────────────
            if let issue = selectedIssue, reportType == nil {
                IssueMapCallout(issue: issue) { selectedIssue = nil }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }

            // ── Recenter + FAB ─────────────────────────────────────────────────
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        // Orange FAB — hidden in report mode
                        if reportType == nil {
                            Button { showTypePicker = true } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#FF6B35"))
                                        .frame(width: 52, height: 52)
                                        .shadow(color: Color(hex: "#FF6B35").opacity(0.4), radius: 12, y: 4)
                                    Image(systemName: "plus")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Recenter (always visible)
                        Button { recenterToUserLocation() } label: {
                            ZStack {
                                Circle()
                                    .fill(.regularMaterial)
                                    .frame(width: 42, height: 42)
                                    .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
                                if isRecentering {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.teal)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, reportType != nil ? 84 : (selectedIssue != nil ? 210 : 28))
                    .animation(.spring(response: 0.3), value: reportType != nil)
                    .animation(.spring(response: 0.3), value: selectedIssue != nil)
                }
            }

            // ── Report confirm bar ─────────────────────────────────────────────
            if let rt = reportType {
                ReportConfirmBar(type: rt) {
                    pendingReportCoordinate = nil
                    withAnimation(.spring(response: 0.3)) { reportType = nil }
                } onConfirm: {
                    pendingReportCoordinate = mapCenter
                    showReportSheet = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35), value: reportType)
        .onAppear {
            Task {
                // Try to center on user's actual GPS location first
                if let loc = try? await LocationHelper.shared.requestLocation() {
                    await MainActor.run {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: loc.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                        ))
                        mapCenter = loc.coordinate
                    }
                } else if let first = mappableIssues.first, let coord = first.coordinate {
                    // Fall back to first reported issue if location unavailable
                    await MainActor.run {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                        ))
                    }
                }
            }
        }
        // ── Type picker sheet ─────────────────────────────────────────────────
        .sheet(isPresented: $showTypePicker) {
            IssueTypePickerSheet { type in
                withAnimation(.spring(response: 0.3)) {
                    reportType = type
                    selectedIssue = nil
                }
                showTypePicker = false
            }
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
        }
        // ── Report issue sheet ────────────────────────────────────────────────
        .sheet(isPresented: $showReportSheet, onDismiss: {
            pendingReportCoordinate = nil
            withAnimation(.spring(response: 0.3)) { reportType = nil }
        }) {
            if let rt = reportType, let coord = pendingReportCoordinate {
                ReportIssueView(
                    prefillType: rt,
                    prefillLatitude: coord.latitude,
                    prefillLongitude: coord.longitude
                )
                .environmentObject(store)
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
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
            } catch {}
        }
    }
}

// MARK: - Crosshair overlay

/// A full-screen overlay with a coloured pin whose tip is pinned to the exact
/// map centre. The crosshair lines guide the user to the precise spot.
struct ReportCrosshair: View {
    let type: IssueType

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width  / 2
            let cy = geo.size.height / 2
            // Pin geometry: circle 36pt + triangle stem 10pt = 46pt total
            // Tip of stem sits at cy; circle centre is at cy - 28
            let circleY = cy - 28.0

            ZStack {
                // Crosshair lines (leave a gap around the pin)
                Path { p in
                    p.move(to: CGPoint(x: cx - 40, y: cy)); p.addLine(to: CGPoint(x: cx - 12, y: cy))
                    p.move(to: CGPoint(x: cx + 12, y: cy)); p.addLine(to: CGPoint(x: cx + 40, y: cy))
                    p.move(to: CGPoint(x: cx, y: cy - 72)); p.addLine(to: CGPoint(x: cx, y: cy - 50))
                    p.move(to: CGPoint(x: cx, y: cy + 12)); p.addLine(to: CGPoint(x: cx, y: cy + 40))
                }
                .stroke(Color.white.opacity(0.65), lineWidth: 1.5)

                // Triangle stem — tip at cy
                Path { p in
                    p.move(to: CGPoint(x: cx,      y: cy))
                    p.addLine(to: CGPoint(x: cx - 7, y: cy - 10))
                    p.addLine(to: CGPoint(x: cx + 7, y: cy - 10))
                    p.closeSubpath()
                }
                .fill(type.color)

                // Pin circle
                Circle()
                    .fill(type.color)
                    .frame(width: 36, height: 36)
                    .overlay { IssueTypeGlyph(type: type, size: 16, weight: .bold, color: .white) }
                    .overlay { Circle().strokeBorder(.white, lineWidth: 2.5) }
                    .shadow(color: type.color.opacity(0.5), radius: 8, y: 2)
                    .position(x: cx, y: circleY)

                // Pulse ring
                Circle()
                    .strokeBorder(type.color.opacity(0.25), lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .position(x: cx, y: circleY)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Confirm bar

struct ReportConfirmBar: View {
    let type: IssueType
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 84, height: 50)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button(action: onConfirm) {
                HStack(spacing: 8) {
                    IssueTypeGlyph(type: type, size: 15, weight: .semibold, color: .white)
                    Text("Report here")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(type.color, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .shadow(color: .black.opacity(0.08), radius: 12, y: -3)
    }
}

// MARK: - Type picker sheet

struct IssueTypePickerSheet: View {
    let onSelect: (IssueType) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            Text("What are you reporting?")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(IssueType.allCases, id: \.self) { type in
                    Button { onSelect(type) } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(type.color.opacity(0.12))
                                    .frame(width: 52, height: 52)
                                IssueTypeGlyph(type: type, size: 22, color: type.color)
                            }
                            Text(type.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Existing subviews (unchanged)

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
    @EnvironmentObject var store: IssueStore
    let issue: Issue
    let onDismiss: () -> Void
    @State private var isVoting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(destination: IssueDetailView(issue: issue)) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(issue.type.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                            StatusBadge(status: issue.status)
                        }
                        Text(issue.displayStreet)
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
                        Text("Close")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Is this issue still there?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    Button { voteOnIssue("up") } label: {
                        Text("Yes")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.green)
                    }
                    .disabled(isVoting)
                    
                    Button { voteOnIssue("down") } label: {
                        Text("No")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.red)
                    }
                    .disabled(isVoting)
                }
            }
            .padding(14)

            Divider()

            NavigationLink(destination: IssueDetailView(issue: issue)) {
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
            .buttonStyle(.plain)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
    }

    private func voteOnIssue(_ type: String) {
        isVoting = true
        Task {
            do {
                try await store.vote(issue: issue, type: type)
            } catch {
                // Silently fail or log
            }
            isVoting = false
        }
    }
}

#Preview {
    NavigationStack {
        IssueMapView().environmentObject(IssueStore())
    }
}
