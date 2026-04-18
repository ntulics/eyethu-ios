import SwiftUI
import MapKit
import CoreLocation

struct ReportIssueView: View {
    @EnvironmentObject var store: IssueStore
    @Environment(\.dismiss) private var dismiss

    // Optional pre-fill values — supplied when launched from the map pin flow
    var prefillType: IssueType? = nil
    var prefillLatitude: Double? = nil
    var prefillLongitude: Double? = nil

    @State private var selectedType: IssueType = .pothole
    @State private var description = ""
    @State private var streetAddress = ""
    @State private var latitude: Double? = nil
    @State private var longitude: Double? = nil
    @State private var municipality: String? = nil
    @State private var photoData: Data? = nil
    @State private var showImageSourcePicker = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showMapPicker = false
    @State private var step = 0
    @State private var isSubmitting = false
    @State private var uploadProgress: String? = nil
    @State private var submitResult: CreateIssueResult? = nil
    @State private var submitError: String? = nil
    @State private var isGeolocating = false

    var isStepValid: Bool {
        switch step {
        case 0: return true
        case 1: return true // description is optional
        case 2: return !streetAddress.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 6) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i <= step ? Color.teal : Color(.systemGray4))
                            .frame(height: 4)
                            .animation(.easeInOut, value: step)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if let result = submitResult {
                    resultView(result)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            switch step {
                            case 0: typeStep
                            case 1: descriptionStep
                            case 2: locationStep
                            case 3: photoStep
                            default: EmptyView()
                            }

                            if let err = submitError {
                                Label(err, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .padding(10)
                                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(20)
                        .animation(.easeInOut(duration: 0.25), value: step)
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
            // Map location picker (opened from the location step)
            .sheet(isPresented: $showMapPicker) {
                MapLocationPickerSheet { lat, lon in
                    latitude  = lat
                    longitude = lon
                    isGeolocating = true
                    Task {
                        if let result = try? await APIService.shared.geocode(lat: lat, lon: lon) {
                            await MainActor.run {
                                if let addr = result.streetAddress, streetAddress.isEmpty {
                                    streetAddress = addr
                                }
                                if municipality == nil { municipality = result.municipality }
                                isGeolocating = false
                            }
                        } else {
                            await MainActor.run { isGeolocating = false }
                        }
                    }
                }
            }
            // Pre-fill from map pin flow
            .onAppear {
                if let type = prefillType {
                    selectedType = type
                }
                if let lat = prefillLatitude, let lon = prefillLongitude {
                    latitude  = lat
                    longitude = lon
                    // If both type and location are provided, skip the type step
                    if prefillType != nil { step = 1 }
                    // Auto reverse-geocode the coords
                    isGeolocating = true
                    Task {
                        if let result = try? await APIService.shared.geocode(lat: lat, lon: lon) {
                            await MainActor.run {
                                if let addr = result.streetAddress { streetAddress = addr }
                                municipality = result.municipality
                                isGeolocating = false
                            }
                        } else {
                            await MainActor.run { isGeolocating = false }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Steps

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(title: "What's the issue?", subtitle: "Select the category that best describes the problem.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(IssueType.allCases, id: \.self) { type in
                    TypeCard(type: type, isSelected: selectedType == type) { selectedType = type }
                }
            }
        }
    }

    private var descriptionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(title: "Describe the issue", subtitle: "Give as much detail as possible to help resolve it faster.")
            IssueTypeTag(type: selectedType)
            TextEditor(text: $description)
                .frame(minHeight: 140)
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("e.g. Large pothole near the intersection…")
                            .foregroundStyle(.tertiary)
                            .padding(18)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(title: "Where is it?", subtitle: "Use your location, drop a pin on the map, or type the address.")

            VStack(spacing: 10) {
                TextField("Street address", text: $streetAddress)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                // Use my location
                Button { useCurrentLocation() } label: {
                    HStack {
                        if isGeolocating {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "location.fill")
                        }
                        Text(isGeolocating ? "Getting location…" : "Use my location")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.teal)
                }
                .disabled(isGeolocating)

                // Pin on map
                Button { showMapPicker = true } label: {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Pin on map")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.primary)
                }
            }

            if latitude != nil {
                Label("Location pinned", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private var photoStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(title: "Add a photo", subtitle: "A photo helps the council assess and fix the issue faster. Optional.")

            Button {
                showImageSourcePicker = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .foregroundStyle(Color.teal.opacity(0.5))
                        .frame(height: 200)

                    if let data = photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 4)
                                    .padding(10)
                            }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(.teal)
                            Text("Take photo or choose from library")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .confirmationDialog("Add Photo", isPresented: $showImageSourcePicker, titleVisibility: .visible) {
                Button("Take Photo") { showCamera = true }
                Button("Choose from Library") { showLibrary = true }
                if photoData != nil {
                    Button("Remove Photo", role: .destructive) { photoData = nil }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    photoData = image.jpegData(compressionQuality: 0.8)
                }
            }
            .sheet(isPresented: $showLibrary) {
                PhotoLibraryPickerView { data in
                    photoData = data
                }
            }
        }
    }

    // MARK: - Result views

    @ViewBuilder
    private func resultView(_ result: CreateIssueResult) -> some View {
        switch result.value {
        case .created(let issue):
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 120, height: 120)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(.green)
                }
                VStack(spacing: 8) {
                    Text("Issue Reported!").font(.title.bold())
                    Text("Issue #\(issue.id) has been submitted and will be reviewed shortly.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 30)
                }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(.teal)
                Spacer()
            }

        case .duplicate(let dup):
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(Color.orange.opacity(0.12)).frame(width: 120, height: 120)
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 64)).foregroundStyle(.orange)
                }
                VStack(spacing: 8) {
                    Text("Already Reported").font(.title.bold())
                    Text("This issue (#\(dup.existingId)) has already been reported \(dup.reportCount) time(s). " +
                         (dup.alreadyCounted ? "Your report was already counted." : "Your report has been added."))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 30)
                }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(.orange)
                Spacer()
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray5), in: Circle())
                }
                .foregroundStyle(.primary)
            }

            Button {
                if step < 3 {
                    withAnimation { step += 1 }
                } else {
                    submitIssue()
                }
            } label: {
                Group {
                    if isSubmitting {
                        VStack(spacing: 2) {
                            ProgressView().tint(.white)
                            if let progress = uploadProgress {
                                Text(progress)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    } else {
                        Text(step == 3 ? "Submit Report" : "Next")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isStepValid ? Color.teal : Color(.systemGray4), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .disabled(!isStepValid || isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func submitIssue() {
        isSubmitting = true
        submitError = nil
        uploadProgress = nil
        Task {
            do {
                var imageURL: String? = nil

                // Upload photo first if one was selected
                if let data = photoData {
                    uploadProgress = "Uploading photo…"
                    imageURL = try await APIService.shared.uploadPhoto(data)
                    uploadProgress = "Submitting report…"
                }

                submitResult = try await store.createIssue(
                    type: selectedType,
                    description: description.isEmpty ? nil : description,
                    latitude: latitude,
                    longitude: longitude,
                    municipality: municipality,
                    streetAddress: streetAddress.isEmpty ? nil : streetAddress,
                    imageURL: imageURL
                )
            } catch {
                submitError = error.localizedDescription
            }
            isSubmitting = false
            uploadProgress = nil
        }
    }

    private func useCurrentLocation() {
        isGeolocating = true
        Task {
            do {
                // Use a one-shot CLLocationManager
                let loc = try await LocationHelper.shared.requestLocation()
                latitude  = loc.coordinate.latitude
                longitude = loc.coordinate.longitude
                // Reverse-geocode via the backend
                let result = try await APIService.shared.geocode(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                if let addr = result.streetAddress { streetAddress = addr }
                municipality = result.municipality
            } catch {
                // Silently ignore — user can type the address
            }
            isGeolocating = false
        }
    }
}

// MARK: - TypeCard & IssueTypeTag

struct TypeCard: View {
    let type: IssueType
    let isSelected: Bool
    let action: () -> Void

    private var cardColor: Color { type.color }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? cardColor : cardColor.opacity(0.12))
                        .frame(width: 60, height: 60)
                    IssueTypeGlyph(type: type, size: 26, color: isSelected ? .white : cardColor)
                }
                Text(type.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? cardColor.opacity(0.1) : Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isSelected ? cardColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReportIssueView().environmentObject(IssueStore())
}
