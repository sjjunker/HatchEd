import Foundation

final class APIClient {
    static let shared = APIClient()
    
    private let baseURL: URL
    private var session: URLSession
    private let tokenStore = TokenStore()
    
    private init() {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "http://localhost:4000"
        guard let url = URL(string: urlString) else {
            fatalError("Invalid API base URL")
        }
        self.baseURL = url
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    func setAuthToken(_ token: String?) {
        tokenStore.token = token
    }
    
    func getAuthToken() -> String? {
        tokenStore.token
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint, responseType: T.Type = T.self) async throws -> T {
        var request = try endpoint.urlRequest(baseURL: baseURL)
        if let token = tokenStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            return try JSONDecoder.api.decode(T.self, from: data)
        default:
            throw try APIError(from: data, statusCode: httpResponse.statusCode)
        }
    }
}

struct Endpoint {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
    }
    
    var path: String
    var method: Method = .get
    var body: Encodable?
    var queryItems: [URLQueryItem] = []
    
    func urlRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder.api.encode(body)
        }
        return request
    }
}

struct EmptyResponse: Decodable {}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case server(message: String, code: String?, status: Int)
    case decodingFailed
    
    init(from data: Data, statusCode: Int) throws {
        let decoder = JSONDecoder.api
        if let apiError = try? decoder.decode(ServerErrorResponse.self, from: data) {
            self = .server(message: apiError.error.message, code: apiError.error.code, status: statusCode)
        } else {
            self = .server(message: "Unexpected server error", code: nil, status: statusCode)
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .decodingFailed: return "Unable to decode server response"
        case .server(let message, _, _): return message
        }
    }
}

private struct ServerErrorResponse: Decodable {
    struct ErrorInfo: Decodable {
        let message: String
        let code: String?
    }
    let error: ErrorInfo
}

private final class TokenStore {
    private let defaults = UserDefaults.standard
    private let key = "authToken"
    
    var token: String? {
        get { defaults.string(forKey: key) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

extension JSONDecoder {
    static var api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static var api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

