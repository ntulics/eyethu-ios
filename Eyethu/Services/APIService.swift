import Foundation

enum APIError: LocalizedError {
    case badURL
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case notFound

    var errorDescription: String? {
        switch self {
        case .badURL:               return "Invalid URL."
        case .serverError(let c, let m): return "Server error \(c): \(m)"
        case .decodingError(let e): return "Decode failed: \(e.localizedDescription)"
        case .networkError(let e):  return e.localizedDescription
        case .unauthorized:         return "Not authenticated."
        case .notFound:             return "Resource not found."
        }
    }
}

actor APIService {
    static let shared = APIService()

    private let baseURL = URL(string: "https://eyethu.org")!
    private let session: URLSession

    // Persists NextAuth session cookie across calls
    private let cookieStorage = HTTPCookieStorage.shared

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Issues

    func fetchIssues(
        status: IssueStatus? = nil,
        type: IssueType? = nil,
        tenantId: Int? = nil
    ) async throws -> [Issue] {
        var components = URLComponents(url: baseURL.appending(path: "/api/issues"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []
        if let s = status  { items.append(.init(name: "status",    value: s.rawValue)) }
        if let t = type    { items.append(.init(name: "type",      value: t.rawValue)) }
        if let id = tenantId { items.append(.init(name: "tenant_id", value: "\(id)")) }
        if !items.isEmpty { components.queryItems = items }

        let request = URLRequest(url: components.url!)
        return try await get(request)
    }

    func fetchIssue(id: Int) async throws -> Issue {
        let url = baseURL.appending(path: "/api/issues/\(id)")
        return try await get(URLRequest(url: url))
    }

    func fetchPhotos(issueId: Int) async throws -> [IssuePhoto] {
        let url = baseURL.appending(path: "/api/issues/\(issueId)/photos")
        return try await get(URLRequest(url: url))
    }

    func createIssue(
        type: IssueType,
        description: String?,
        latitude: Double?,
        longitude: Double?,
        municipality: String?,
        streetAddress: String?,
        imageURL: String? = nil,
        imageURLs: [String] = [],
        tenantId: Int = 1
    ) async throws -> CreateIssueResult {
        var body: [String: Any] = ["type": type.rawValue, "tenant_id": tenantId, "source": "ios"]
        if let v = description,   !v.isEmpty { body["description"]    = v }
        if let v = latitude                  { body["latitude"]        = v }
        if let v = longitude                 { body["longitude"]       = v }
        if let v = municipality,  !v.isEmpty { body["municipality"]    = v }
        if let v = streetAddress, !v.isEmpty { body["street_address"]  = v }
        // Collect all photo URLs (imageURLs takes precedence; imageURL is legacy fallback)
        var allURLs = imageURLs
        if let v = imageURL, !v.isEmpty, !allURLs.contains(v) { allURLs.append(v) }
        if !allURLs.isEmpty { body["image_urls"] = allURLs }

        var req = URLRequest(url: baseURL.appending(path: "/api/issues"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await perform(req)
        let status = (response as! HTTPURLResponse).statusCode

        if status == 200 {
            // Duplicate detected
            let dup = try decode(DuplicateIssueResponse.self, from: data)
            return CreateIssueResult(value: .duplicate(dup))
        } else if status == 201 {
            let issue = try decode(Issue.self, from: data)
            return CreateIssueResult(value: .created(issue))
        } else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(status, msg)
        }
    }

    func updateIssueStatus(id: Int, status: IssueStatus) async throws -> Issue {
        var req = URLRequest(url: baseURL.appending(path: "/api/issues/\(id)"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["status": status.rawValue])
        return try await send(req)
    }

    func voteOnIssue(id: Int, vote: String) async throws -> Issue {
        var req = URLRequest(url: baseURL.appending(path: "/api/issues/\(id)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["vote": vote])
        return try await send(req)
    }

    // MARK: - Photo upload

    struct UploadURLResponse: Codable {
        let uploadUrl: String
        let blobUrl: String
    }

    /// Requests a short-lived SAS write URL from the backend, then PUTs the image
    /// directly to Azure Blob Storage. Returns the permanent public blob URL.
    func uploadPhoto(_ imageData: Data, mimeType: String = "image/jpeg") async throws -> String {
        // 1. Get SAS URL from backend
        var req = URLRequest(url: baseURL.appending(path: "/api/upload"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "filename":    "photo.jpg",
            "contentType": mimeType,
        ])
        let urls: UploadURLResponse = try await send(req)

        // 2. PUT image bytes directly to Azure Blob Storage via the SAS URL
        guard let sasURL = URL(string: urls.uploadUrl) else { throw APIError.badURL }
        var putReq = URLRequest(url: sasURL)
        putReq.httpMethod = "PUT"
        putReq.setValue(mimeType,                         forHTTPHeaderField: "Content-Type")
        putReq.setValue("\(imageData.count)",              forHTTPHeaderField: "Content-Length")
        putReq.setValue("BlockBlob",                       forHTTPHeaderField: "x-ms-blob-type")
        putReq.httpBody = imageData

        let (_, putResponse) = try await perform(putReq)
        let statusCode = (putResponse as! HTTPURLResponse).statusCode
        guard (200..<300).contains(statusCode) else {
            throw APIError.serverError(statusCode, "Azure upload failed")
        }

        return urls.blobUrl
    }

    // MARK: - Geocode

    struct GeocodeResult: Codable {
        let streetAddress: String?   // full address with house number — stored in DB
        let streetName: String?      // street only, no house number — shown in UI
        let municipality: String?
        let snappedLat: Double?      // road-snapped coordinate from Azure Maps
        let snappedLon: Double?
        enum CodingKeys: String, CodingKey {
            case streetAddress = "streetAddress"
            case streetName    = "streetName"
            case municipality
            case snappedLat    = "snappedLat"
            case snappedLon    = "snappedLon"
        }
    }

    func geocode(lat: Double, lon: Double) async throws -> GeocodeResult {
        var components = URLComponents(url: baseURL.appending(path: "/api/geocode"), resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "lat", value: "\(lat)"), .init(name: "lon", value: "\(lon)")]
        return try await get(URLRequest(url: components.url!))
    }

    // MARK: - Auth (NextAuth credentials)

    struct SignInResult {
        let ok: Bool
        let error: String?
    }

    func signIn(email: String, password: String) async throws -> SignInResult {
        // Step 1: get CSRF token
        let csrfURL = baseURL.appending(path: "/api/auth/csrf")
        let (csrfData, _) = try await perform(URLRequest(url: csrfURL))
        guard
            let json = try? JSONSerialization.jsonObject(with: csrfData) as? [String: Any],
            let csrfToken = json["csrfToken"] as? String
        else { throw APIError.serverError(500, "Could not get CSRF token") }

        // Step 2: post credentials
        var req = URLRequest(url: baseURL.appending(path: "/api/auth/callback/credentials"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "csrfToken=\(csrfToken)&email=\(email.urlEncoded)&password=\(password.urlEncoded)&redirect=false&json=true"
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await perform(req)
        let code = (response as! HTTPURLResponse).statusCode

        if code == 200 {
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let error = obj?["error"] as? String
            return SignInResult(ok: error == nil, error: error)
        }
        return SignInResult(ok: false, error: "Auth failed (\(code))")
    }

    func signOut() async throws {
        var req = URLRequest(url: baseURL.appending(path: "/api/auth/signout"))
        req.httpMethod = "POST"
        _ = try await perform(req)
        HTTPCookieStorage.shared.cookies?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }

    func fetchSession() async throws -> SessionUser? {
        let url = baseURL.appending(path: "/api/auth/session")
        let (data, _) = try await perform(URLRequest(url: url))
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let userDict = json["user"] as? [String: Any],
            let id    = userDict["id"]    as? String,
            let name  = userDict["name"]  as? String,
            let email = userDict["email"] as? String,
            let role  = userDict["role"]  as? String
        else { return nil }
        let perms = (userDict["permissions"] as? [String]) ?? []
        return SessionUser(id: id, name: name, email: email, role: role, permissions: perms)
    }

    // MARK: - Private helpers

    private func get<T: Decodable>(_ request: URLRequest) async throws -> T {
        try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await perform(request)
        let code = (response as! HTTPURLResponse).statusCode
        guard (200..<300).contains(code) else {
            if code == 401 { throw APIError.unauthorized }
            if code == 404 { throw APIError.notFound }
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(code, msg)
        }
        return try decode(T.self, from: data)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

struct SessionUser {
    let id: String
    let name: String
    let email: String
    let role: String
    let permissions: [String]

    func can(_ permission: String) -> Bool {
        permissions.contains(permission)
    }
}

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
