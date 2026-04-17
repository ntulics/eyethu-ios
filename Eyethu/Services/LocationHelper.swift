import CoreLocation

actor LocationHelper: NSObject, CLLocationManagerDelegate {
    static let shared = LocationHelper()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        Task { @MainActor in manager.delegate = self }
    }

    func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            Task { @MainActor in
                manager.requestWhenInUseAuthorization()
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { await resume(with: .success(loc)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { await resume(with: .failure(error)) }
    }

    private func resume(with result: Result<CLLocation, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
