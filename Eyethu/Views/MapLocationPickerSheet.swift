import SwiftUI
import MapKit

/// Full-screen map with a crosshair at the centre.
/// Pan the map until the crosshair is over the exact spot, then tap "Confirm location".
struct MapLocationPickerSheet: View {
    let onSelect: (Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    // The coordinate at the crosshair tip (ZStack centre), updated via MapProxy.
    // Using proxy.convert(screenCentre) instead of ctx.region.center eliminates
    // the ~17pt safe-area offset between the Map's extended frame and the ZStack.
    @State private var mapCenter    = CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473)
    @State private var didCenterOnUser = false
    @State private var containerSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Map ──────────────────────────────────────────────────────
                MapReader { proxy in
                    Map(position: $cameraPosition)
                        .mapStyle(.standard(elevation: .realistic))
                        .ignoresSafeArea(edges: .bottom)
                        .onMapCameraChange(frequency: .continuous) { _ in
                            // Convert the ZStack centre pixel → geographic coordinate.
                            // This is accurate regardless of how far the map extends
                            // below the safe area.
                            guard containerSize != .zero else { return }
                            let screenCentre = CGPoint(
                                x: containerSize.width  / 2,
                                y: containerSize.height / 2
                            )
                            if let coord = proxy.convert(screenCentre, from: .named("pickerMap")) {
                                mapCenter = coord
                            }
                        }
                }

                // ── Crosshair — stays at the ZStack/screen centre ─────────
                PickerCrosshair()
                    .allowsHitTesting(false)

                // ── Instruction + Confirm ─────────────────────────────────
                VStack {
                    Text("Pan map to the exact spot")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                        .padding(.top, 12)
                        .allowsHitTesting(false)

                    Spacer()

                    Button {
                        onSelect(mapCenter.latitude, mapCenter.longitude)
                        dismiss()
                    } label: {
                        Label("Confirm location", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.teal, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: -3)
                }
            }
            // Named coordinate space so MapProxy.convert knows which frame to use
            .coordinateSpace(name: "pickerMap")
            // Capture the ZStack's actual size (excludes safe areas)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { containerSize = geo.size }
                        .onChange(of: geo.size) { _, s in containerSize = s }
                }
            )
            .navigationTitle("Pin Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                guard !didCenterOnUser else { return }
                didCenterOnUser = true
                Task {
                    if let loc = try? await LocationHelper.shared.requestLocation() {
                        await MainActor.run {
                            withAnimation {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: loc.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                                ))
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Crosshair

private struct PickerCrosshair: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.7)).frame(width: 28, height: 1.5).offset(x: -20)
            Rectangle().fill(Color.white.opacity(0.7)).frame(width: 28, height: 1.5).offset(x: 20)
            Rectangle().fill(Color.white.opacity(0.7)).frame(width: 1.5, height: 28).offset(y: -20)
            Rectangle().fill(Color.white.opacity(0.7)).frame(width: 1.5, height: 28).offset(y: 20)
            Circle()
                .fill(Color.teal)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                .shadow(color: .teal.opacity(0.5), radius: 6)
        }
    }
}

#Preview {
    MapLocationPickerSheet { lat, lon in
        print("Selected: \(lat), \(lon)")
    }
}
