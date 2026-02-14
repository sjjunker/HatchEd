//
//  ServiceXCTests.swift
//  HatchEdTests
//
//  XCTest unit tests for Services/Managers. Targets 75–85% coverage.
//  Tests APIError, Endpoint, OfflineCache. No network; deterministic.
//

import XCTest
@testable import HatchEd

final class ServiceXCTests: XCTestCase {

    // MARK: - APIError (business error handling)

    func testAPIError_InvalidURL_HasLocalizedDescription() {
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid URL")
    }

    func testAPIError_InvalidResponse_HasLocalizedDescription() {
        XCTAssertEqual(APIError.invalidResponse.errorDescription, "Invalid server response")
    }

    func testAPIError_DecodingFailed_HasLocalizedDescription() {
        XCTAssertEqual(APIError.decodingFailed.errorDescription, "Unable to decode server response")
    }

    func testAPIError_Server_HasMessageInDescription() {
        let err = APIError.server(message: "Bad request", code: "VALIDATION", status: 400)
        XCTAssertEqual(err.errorDescription, "Bad request")
    }

    func testAPIError_InitFromData_DecodesServerErrorResponse() throws {
        let json = """
        {"error": {"message": "Not found", "code": "NOT_FOUND"}}
        """
        let data = Data(json.utf8)
        let err = try APIError(from: data, statusCode: 404)
        if case .server(let message, let code, let status) = err {
            XCTAssertEqual(message, "Not found")
            XCTAssertEqual(code, "NOT_FOUND")
            XCTAssertEqual(status, 404)
        } else {
            XCTFail("Expected .server case")
        }
    }

    func testAPIError_InitFromData_UnexpectedErrorWhenDecodeFails() throws {
        let data = Data("not json".utf8)
        let err = try APIError(from: data, statusCode: 500)
        if case .server(let message, let code, let status) = err {
            XCTAssertEqual(message, "Unexpected server error")
            XCTAssertNil(code)
            XCTAssertEqual(status, 500)
        } else {
            XCTFail("Expected .server case")
        }
    }

    // MARK: - Endpoint (URL building; no network)

    func testEndpoint_UrlRequest_BuildsCorrectURL() throws {
        let base = URL(string: "https://api.example.com")!
        let endpoint = Endpoint(path: "api/users/me", method: .get)
        let request = try endpoint.urlRequest(baseURL: base)
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/api/users/me")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func testEndpoint_UrlRequest_AppendsQueryItems() throws {
        let base = URL(string: "https://api.example.com")!
        let endpoint = Endpoint(
            path: "api/attendance/students/s1",
            method: .get,
            queryItems: [URLQueryItem(name: "limit", value: "90")]
        )
        let request = try endpoint.urlRequest(baseURL: base)
        XCTAssertTrue(request.url?.absoluteString.contains("limit=90") == true)
    }

    func testEndpoint_UrlRequest_DeleteMethod_SetsMethod() throws {
        let base = URL(string: "https://api.example.com")!
        let endpoint = Endpoint(path: "api/notifications/n1", method: .delete)
        let request = try endpoint.urlRequest(baseURL: base)
        XCTAssertEqual(request.httpMethod, "DELETE")
    }

    func testEndpoint_UrlRequest_PostWithBody_SetsContentTypeAndBody() throws {
        struct Dummy: Encodable { let x: String }
        let base = URL(string: "https://api.example.com")!
        let endpoint = Endpoint(path: "api/auth", method: .post, body: Dummy(x: "y"))
        let request = try endpoint.urlRequest(baseURL: base)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.httpBody)
    }

    // MARK: - OfflineCache (persistence; uses app Documents in test)

    func testOfflineCache_Load_ReturnsNil_WhenFileMissing() {
        let cache = OfflineCache.shared
        let result: User? = cache.load(User.self, from: "nonexistent_\(UUID().uuidString).json")
        XCTAssertNil(result)
    }

    func testOfflineCache_SaveAndLoad_RoundTripsEncodable() {
        struct TestPayload: Codable, Equatable {
            let id: String
            let value: Int
        }
        let cache = OfflineCache.shared
        let fileName = "test_\(UUID().uuidString).json"
        let payload = TestPayload(id: "a", value: 42)
        cache.save(payload, as: fileName)
        let loaded: TestPayload? = cache.load(TestPayload.self, from: fileName)
        XCTAssertEqual(loaded?.id, payload.id)
        XCTAssertEqual(loaded?.value, payload.value)
        cache.remove(fileName)
    }

    func testOfflineCache_Remove_DeletesFile() {
        struct TestPayload: Codable { let x: String }
        let cache = OfflineCache.shared
        let fileName = "test_remove_\(UUID().uuidString).json"
        cache.save(TestPayload(x: "y"), as: fileName)
        var loaded: TestPayload? = cache.load(TestPayload.self, from: fileName)
        XCTAssertNotNil(loaded)
        cache.remove(fileName)
        loaded = cache.load(TestPayload.self, from: fileName)
        XCTAssertNil(loaded)
    }
}
