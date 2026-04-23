import SwiftUI
import MapKit
import CoreLocation

struct ReportIssueView: View {
    @EnvironmentObject var store: IssueStore
    @Environment(\.dismiss) private var dismiss

    var prefillType: IssueType? = nil
    var prefillLatitude: Double? = nil
    var prefillLongitude: Double? = nil

    @State private var selectedType: IssueType = .pothole
    @State private var description = ""
    @State private var streetAddress = ""
    @State private var latitude: Double? = nil
    @State private var longitude: Double? = nil
    @State private var municipality: String? = nil

    @State private var photoDatas: [Data] = []
    @State private var showImageSourcePicker = false
    @State private var showCamera = false
    @State private var showLibrary = false
    private let maxPhotos = 5

    @State private var showMapPicker = false
    @State private var step = 0
    @State private var isSubmitting = false
    @State private var uploadProgress: String? = nil
    @State private var submitResult: CreateIssueResult? = nil
    @State private var submitError: String? = nil
    @State private var isGeolocating = false

    private var trimmedStreetAddress: String {
        streetAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSelectedCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var isStepValid: Bool {
        switch step {
        case 0: return true
        case 1: return true
        case 2: return hasSelectedCoordinates || !trimmedStreetAddress.isEmpty
        default: return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact Progress Bar
                HStack(spacing: 4) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i <= step ? Color.teal : Color(.systemGray4))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                if let result = submitResult {
                    resultView(result)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            switch step {
                            case 0: typeStep
                            case 1: descriptionStep
                            case 2: locationStep
                            case 3: photoStep
                            default: EmptyView()
                            }

                            if let err = submitError {
                                Text(err).font(.caption).foregroundStyle(.red).padding(.horizontal)
                            }
                        }
                        .padding(20)
                    }

                    bottomBar
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                }
            }
            .onChange(of: step) { _, newStep in
                guard newStep == 2, !isGeolocating else { return }
                if hasSelectedCoordinates {
                    if trimmedStreetAddress.isEmpty, let lat = latitude, let lon = longitude {
                        fetchGeocode(lat: lat, lon: lon)
                    }
                } else {
                    useCurrentLocation()
                }
            }
            .onAppear {
                if let type = prefillType { selectedType = type }
                if let lat = prefillLatitude, let lon = prefillLongitude {
                    applySelectedLocation(lat: lat, lon: lon, shouldFetchGeocode: true)
                    if prefillType != nil { step = 1 }
                }
            }
            .sheet(isPresented: $showMapPicker) {
                MapLocationPickerSheet { lat, lon in
                    applySelectedLocation(lat: lat, lon: lon, shouldFetchGeocode: true)
                }
            }
        }
    }

    // MARK: - Compact Steps

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(title: "What's the issue?", subtitle: "Select a category")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(IssueType.allCases, id: \.self) { type in
                    TypeCard(type: type, isSelected: selectedType == type) {
                        selectedType = type
                        withAnimation { step = 1 }
                    }
                }
            }
        }
    }

    private var descriptionStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(title: "Details", subtitle: "Describe the problem")
            TextEditor(text: $description)
                .frame(minHeight: 100)
                .padding(10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("e.g. Pothole in the left lane...").foregroundStyle(.tertiary).padding(14)
                    }
                }
        }
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(title: "Where is it?", subtitle: "Confirm the address")
            VStack(spacing: 8) {
                TextField("Street address", text: $streetAddress)
                    .textFieldStyle(.roundedBorder)
                
                Button { useCurrentLocation() } label: {
                    Label(isGeolocating ? "Locating..." : "Use my current location", systemImage: "location.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isGeolocating)

                if let lat = latitude, let lon = longitude {
                    Button {
                        showMapPicker = true
                    } label: {
                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                        )))) {
                            Marker("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                .tint(selectedType.color)
                        }
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))
                        .allowsHitTesting(false) // Makes the map itself non-interactive
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showMapPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Pin on map")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var photoStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(title: "Add Photos", subtitle: "Optional, up to 5")
            
            HStack(spacing: 8) {
                if photoDatas.count < maxPhotos {
                    // Direct Camera Button
                    Button { showCamera = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill").font(.system(size: 20))
                            Text("Camera").font(.system(size: 10, weight: .medium))
                        }
                        .frame(width: 65, height: 70)
                        .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.teal)
                    }

                    // Direct Library Button
                    Button { showLibrary = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 20))
                            Text("Library").font(.system(size: 10, weight: .medium))
                        }
                        .frame(width: 65, height: 70)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photoDatas.enumerated()), id: \.offset) { idx, data in
                            if let img = UIImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    Button { photoDatas.remove(at: idx) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white)
                                            .background(Circle().fill(.black.opacity(0.5)))
                                    }
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                    .padding(.top, 4) // Space for the xmark
                }
            }
        }
        .sheet(isPresented: $showCamera) { CameraPickerView { img in photoDatas.append(img.jpegData(compressionQuality: 0.8)!) } }
        .sheet(isPresented: $showLibrary) { PhotoLibraryPickerView { data in photoDatas.append(data) } }
    }

    // MARK: - Helpers

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button { withAnimation { step -= 1 } } label: {
                    Text("Back")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 84, height: 44)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }

            Button {
                if step < 3 { withAnimation { step += 1 } } else { submitIssue() }
            } label: {
                Text(isSubmitting ? "Submitting..." : (step == 3 ? "Submit" : "Next"))
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(isStepValid ? Color.teal : Color(.systemGray4), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .disabled(!isStepValid || isSubmitting)
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func fetchGeocode(lat: Double, lon: Double) {
        isGeolocating = true
        Task {
            if let result = try? await APIService.shared.geocode(lat: lat, lon: lon) {
                await MainActor.run {
                    streetAddress = result.streetName ?? result.streetAddress ?? streetAddress
                    municipality = result.municipality
                    isGeolocating = false
                }
            } else { await MainActor.run { isGeolocating = false } }
        }
    }

    private func applySelectedLocation(lat: Double, lon: Double, shouldFetchGeocode: Bool) {
        latitude = lat
        longitude = lon
        if shouldFetchGeocode {
            fetchGeocode(lat: lat, lon: lon)
        }
    }

    private func useCurrentLocation() {
        isGeolocating = true
        Task {
            do {
                let loc = try await LocationHelper.shared.requestLocation()
                await MainActor.run {
                    applySelectedLocation(
                        lat: loc.coordinate.latitude,
                        lon: loc.coordinate.longitude,
                        shouldFetchGeocode: false
                    )
                }
                fetchGeocode(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
            } catch { await MainActor.run { isGeolocating = false } }
        }
    }

    private func submitIssue() {
        isSubmitting = true
        Task {
            do {
                var urls: [String] = []
                for data in photoDatas { urls.append(try await APIService.shared.uploadPhoto(data)) }
                submitResult = try await store.createIssue(type: selectedType, description: description, latitude: latitude, longitude: longitude, municipality: municipality, streetAddress: streetAddress, imageURLs: urls)
            } catch { submitError = error.localizedDescription }
            isSubmitting = false
        }
    }

    @ViewBuilder
    private func resultView(_ result: CreateIssueResult) -> some View {
        switch result.value {
        case .created(let issue):
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "checkmark.circle.fill").font(.system(size: 50)).foregroundStyle(.green)
                Text("Submitted!").font(.headline)
                Text("Issue #\(issue.id) created.").font(.subheadline).foregroundStyle(.secondary)
                Button("Done") { dismiss() }.buttonStyle(.bordered).tint(.teal)
                Spacer()
            }
        case .duplicate(let dup):
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 50)).foregroundStyle(.orange)
                Text("Already Reported").font(.headline)
                Text("Issue #\(dup.existingId) already exists.").font(.subheadline).foregroundStyle(.secondary)
                Button("Done") { dismiss() }.buttonStyle(.bordered).tint(.orange)
                Spacer()
            }
        }
    }
}

struct TypeCard: View {
    let type: IssueType
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(isSelected ? type.color : type.color.opacity(0.1)).frame(width: 44, height: 44)
                    IssueTypeGlyph(type: type, size: 20, color: isSelected ? .white : type.color)
                }
                Text(type.displayName).font(.system(size: 10, weight: .medium)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? type.color.opacity(0.05) : Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected ? type.color : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
