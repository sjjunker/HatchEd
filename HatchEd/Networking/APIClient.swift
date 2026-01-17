import Foundation

// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

struct AttendanceSubmissionRecord: Encodable {
    let studentUserId: String
    let isPresent: Bool
}

struct AttendanceSubmissionRequest: Encodable {
    let date: Date
    let records: [AttendanceSubmissionRecord]
}

struct AttendanceRecordDTO: Decodable {
    let id: String
    let familyId: String
    let studentUserId: String
    let recordedByUserId: String
    let date: Date
    let status: String
    let isPresent: Bool
    let createdAt: Date?
    let updatedAt: Date?
}

struct AttendanceSubmissionResponse: Decodable {
    let attendance: [AttendanceRecordDTO]
}

struct AttendanceListResponse: Decodable {
    let attendance: [AttendanceRecordDTO]
}

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
        configuration.timeoutIntervalForRequest = 60  // Increased from 30 to 60 seconds
        configuration.timeoutIntervalForResource = 120  // Increased from 60 to 120 seconds
        configuration.waitsForConnectivity = true  // Wait for network connectivity
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
    
    func submitAttendance(date: Date, records: [AttendanceSubmissionRecord]) async throws -> AttendanceSubmissionResponse {
        let body = AttendanceSubmissionRequest(date: date, records: records)
        return try await request(
            Endpoint(path: "api/attendance", method: .post, body: body),
            responseType: AttendanceSubmissionResponse.self
        )
    }
    
    func fetchAttendance(studentUserId: String, limit: Int? = nil, startDate: Date? = nil, endDate: Date? = nil) async throws -> [AttendanceRecordDTO] {
        var queryItems: [URLQueryItem] = []
        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: startDate)))
        }
        if let endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: endDate)))
        }
        let response: AttendanceListResponse = try await request(
            Endpoint(path: "api/attendance/students/\(studentUserId)", queryItems: queryItems),
            responseType: AttendanceListResponse.self
        )
        return response.attendance
    }
    
    // Curriculum API methods
    struct CoursesResponse: Decodable {
        let courses: [Course]
    }
    
    struct AssignmentsResponse: Decodable {
        let assignments: [Assignment]
    }
    
    struct CourseResponse: Decodable {
        let course: Course
    }
    
    struct AssignmentResponse: Decodable {
        let assignment: Assignment
    }
    
    struct SuccessResponse: Decodable {
        let success: Bool
    }
    
    struct CreateCourseRequest: Encodable {
        let name: String
        let studentUserId: String
        let grade: Double?
    }
    
    struct UpdateCourseRequest: Encodable {
        let name: String?
        let grade: Double?
    }
    
    struct CreateAssignmentRequest: Encodable {
        let title: String
        let studentId: String
        let dueDate: Date?
        let instructions: String?
        let pointsPossible: Double?
        let pointsAwarded: Double?
        let courseId: String?
    }
    
    struct UpdateAssignmentRequest: Encodable {
        let title: String?
        let dueDate: Date?
        let instructions: String?
        let pointsPossible: Double?
        let pointsAwarded: Double?
        let courseId: String?
    }
    
    // Courses
    func createCourse(name: String, studentUserId: String, grade: Double?) async throws -> Course {
        let body = CreateCourseRequest(name: name, studentUserId: studentUserId, grade: grade)
        let response: CourseResponse = try await request(
            Endpoint(path: "api/curriculum/courses", method: .post, body: body),
            responseType: CourseResponse.self
        )
        return response.course
    }
    
    func fetchCourses() async throws -> [Course] {
        let response: CoursesResponse = try await request(
            Endpoint(path: "api/curriculum/courses"),
            responseType: CoursesResponse.self
        )
        return response.courses
    }
    
    func updateCourse(id: String, name: String?, grade: Double?) async throws -> Course {
        let body = UpdateCourseRequest(name: name, grade: grade)
        let response: CourseResponse = try await request(
            Endpoint(path: "api/curriculum/courses/\(id)", method: .patch, body: body),
            responseType: CourseResponse.self
        )
        return response.course
    }
    
    func deleteCourse(id: String) async throws {
        _ = try await request(
            Endpoint(path: "api/curriculum/courses/\(id)", method: .delete),
            responseType: SuccessResponse.self
        )
    }
    
    // Assignments
    func createAssignment(title: String, studentId: String, dueDate: Date?, instructions: String?, pointsPossible: Double?, pointsAwarded: Double?, courseId: String?) async throws -> Assignment {
        let body = CreateAssignmentRequest(title: title, studentId: studentId, dueDate: dueDate, instructions: instructions, pointsPossible: pointsPossible, pointsAwarded: pointsAwarded, courseId: courseId)
        let response: AssignmentResponse = try await request(
            Endpoint(path: "api/curriculum/assignments", method: .post, body: body),
            responseType: AssignmentResponse.self
        )
        return response.assignment
    }
    
    func fetchAssignments() async throws -> [Assignment] {
        let response: AssignmentsResponse = try await request(
            Endpoint(path: "api/curriculum/assignments"),
            responseType: AssignmentsResponse.self
        )
        return response.assignments
    }
    
    func updateAssignment(id: String, title: String?, dueDate: Date?, instructions: String?, pointsPossible: Double?, pointsAwarded: Double?, courseId: String? = nil) async throws -> Assignment {
        let body = UpdateAssignmentRequest(title: title, dueDate: dueDate, instructions: instructions, pointsPossible: pointsPossible, pointsAwarded: pointsAwarded, courseId: courseId)
        let response: AssignmentResponse = try await request(
            Endpoint(path: "api/curriculum/assignments/\(id)", method: .patch, body: body),
            responseType: AssignmentResponse.self
        )
        return response.assignment
    }
    
    func deleteAssignment(id: String) async throws {
        _ = try await request(
            Endpoint(path: "api/curriculum/assignments/\(id)", method: .delete),
            responseType: SuccessResponse.self
        )
    }
    
    // Planner Tasks API methods
    struct PlannerTasksResponse: Decodable {
        let tasks: [PlannerTask]
    }
    
    struct PlannerTaskResponse: Decodable {
        let task: PlannerTask
    }
    
    struct CreatePlannerTaskRequest: Encodable {
        let title: String
        let startDate: Date
        let durationMinutes: Int
        let colorName: String
        let subject: String?
    }
    
    struct UpdatePlannerTaskRequest: Encodable {
        let title: String?
        let startDate: Date?
        let durationMinutes: Int?
        let colorName: String?
        let subject: String?
    }
    
    func createPlannerTask(title: String, startDate: Date, durationMinutes: Int, colorName: String, subject: String?) async throws -> PlannerTask {
        let body = CreatePlannerTaskRequest(title: title, startDate: startDate, durationMinutes: durationMinutes, colorName: colorName, subject: subject)
        let response: PlannerTaskResponse = try await request(
            Endpoint(path: "api/planner/tasks", method: .post, body: body),
            responseType: PlannerTaskResponse.self
        )
        return response.task
    }
    
    func fetchPlannerTasks() async throws -> [PlannerTask] {
        let response: PlannerTasksResponse = try await request(
            Endpoint(path: "api/planner/tasks"),
            responseType: PlannerTasksResponse.self
        )
        return response.tasks
    }
    
    func updatePlannerTask(id: String, title: String?, startDate: Date?, durationMinutes: Int?, colorName: String?, subject: String?) async throws -> PlannerTask {
        let body = UpdatePlannerTaskRequest(title: title, startDate: startDate, durationMinutes: durationMinutes, colorName: colorName, subject: subject)
        let response: PlannerTaskResponse = try await request(
            Endpoint(path: "api/planner/tasks/\(id)", method: .patch, body: body),
            responseType: PlannerTaskResponse.self
        )
        return response.task
    }
    
    func deletePlannerTask(id: String) async throws {
        _ = try await request(
            Endpoint(path: "api/planner/tasks/\(id)", method: .delete),
            responseType: SuccessResponse.self
        )
    }
    
    // Portfolio API methods
    struct PortfoliosResponse: Decodable {
        let portfolios: [Portfolio]
    }
    
    struct PortfolioResponse: Decodable {
        let portfolio: Portfolio
    }
    
    struct StudentWorkFilesResponse: Decodable {
        let files: [StudentWorkFile]
    }
    
    struct StudentWorkFileResponse: Decodable {
        let file: StudentWorkFile
    }
    
    struct CreatePortfolioRequest: Encodable {
        let studentId: String
        let studentName: String
        let designPattern: String
        let studentWorkFileIds: [String]
        let studentRemarks: String?
        let instructorRemarks: String?
        let reportCardSnapshot: String?
        let sectionData: PortfolioSectionData?
    }
    
    func fetchPortfolios() async throws -> [Portfolio] {
        let response: PortfoliosResponse = try await request(
            Endpoint(path: "api/portfolios"),
            responseType: PortfoliosResponse.self
        )
        return response.portfolios
    }
    
    func createPortfolio(
        studentId: String,
        studentName: String,
        designPattern: PortfolioDesignPattern,
        studentWorkFileIds: [String],
        studentRemarks: String?,
        instructorRemarks: String?,
        reportCardSnapshot: String?,
        sectionData: PortfolioSectionData?
    ) async throws -> Portfolio {
        let body = CreatePortfolioRequest(
            studentId: studentId,
            studentName: studentName,
            designPattern: designPattern.rawValue,
            studentWorkFileIds: studentWorkFileIds,
            studentRemarks: studentRemarks,
            instructorRemarks: instructorRemarks,
            reportCardSnapshot: reportCardSnapshot,
            sectionData: sectionData
        )
        let response: PortfolioResponse = try await request(
            Endpoint(path: "api/portfolios", method: .post, body: body),
            responseType: PortfolioResponse.self
        )
        return response.portfolio
    }
    
    func fetchStudentWorkFiles(studentId: String) async throws -> [StudentWorkFile] {
        let response: StudentWorkFilesResponse = try await request(
            Endpoint(path: "api/portfolios/student-work/\(studentId)"),
            responseType: StudentWorkFilesResponse.self
        )
        return response.files
    }
    
    func uploadStudentWorkFile(
        studentId: String,
        fileName: String,
        fileData: Data,
        fileType: String
    ) async throws -> StudentWorkFile {
        // For now, we'll use a simple multipart upload
        // In production, you'd want to use a proper file upload endpoint
        var request = URLRequest(url: baseURL.appendingPathComponent("api/portfolios/student-work/upload"))
        request.httpMethod = "POST"
        if let token = tokenStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add studentId field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"studentId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(studentId)\r\n".data(using: .utf8)!)
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(fileType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Set Content-Length header
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = body
        
        print("[APIClient] Uploading file - size: \(body.count) bytes, fileName: \(fileName)")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder.api.decode(StudentWorkFileResponse.self, from: data).file
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
        case delete = "DELETE"
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
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

// Notification Response Types
struct NotificationResponse: Decodable {
    let notification: Notification
}

