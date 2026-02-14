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
        let urlString: String
        #if DEBUG
        // Development: use local server so you don't hit production when NODE_ENV=development
        urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL_DEV") as? String ?? "http://localhost:4000"
        #else
        // Release / TestFlight: use production server
        urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "http://localhost:4000"
        #endif
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
    
    // Subjects API methods (courses & assignments)
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
        let studentUserIds: [String]
        let grade: Double?
    }
    
    struct UpdateCourseRequest: Encodable {
        let name: String?
        let grade: Double?
        let studentUserIds: [String]?
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
    func createCourse(name: String, studentUserIds: [String], grade: Double?) async throws -> Course {
        let body = CreateCourseRequest(name: name, studentUserIds: studentUserIds, grade: grade)
        let response: CourseResponse = try await request(
            Endpoint(path: "api/subjects/courses", method: .post, body: body),
            responseType: CourseResponse.self
        )
        return response.course
    }
    
    func fetchCourses() async throws -> [Course] {
        let response: CoursesResponse = try await request(
            Endpoint(path: "api/subjects/courses"),
            responseType: CoursesResponse.self
        )
        return response.courses
    }
    
    func updateCourse(id: String, name: String?, grade: Double?, studentUserIds: [String]? = nil) async throws -> Course {
        let body = UpdateCourseRequest(name: name, grade: grade, studentUserIds: studentUserIds)
        let response: CourseResponse = try await request(
            Endpoint(path: "api/subjects/courses/\(id)", method: .patch, body: body),
            responseType: CourseResponse.self
        )
        return response.course
    }
    
    func deleteCourse(id: String) async throws {
        _ = try await request(
            Endpoint(path: "api/subjects/courses/\(id)", method: .delete),
            responseType: SuccessResponse.self
        )
    }
    
    // Assignments
    func createAssignment(title: String, studentId: String, dueDate: Date?, instructions: String?, pointsPossible: Double?, pointsAwarded: Double?, courseId: String?) async throws -> Assignment {
        let body = CreateAssignmentRequest(title: title, studentId: studentId, dueDate: dueDate, instructions: instructions, pointsPossible: pointsPossible, pointsAwarded: pointsAwarded, courseId: courseId)
        let response: AssignmentResponse = try await request(
            Endpoint(path: "api/subjects/assignments", method: .post, body: body),
            responseType: AssignmentResponse.self
        )
        return response.assignment
    }
    
    func fetchAssignments() async throws -> [Assignment] {
        let response: AssignmentsResponse = try await request(
            Endpoint(path: "api/subjects/assignments"),
            responseType: AssignmentsResponse.self
        )
        return response.assignments
    }
    
    func updateAssignment(id: String, title: String?, dueDate: Date?, instructions: String?, pointsPossible: Double?, pointsAwarded: Double?, courseId: String? = nil) async throws -> Assignment {
        let body = UpdateAssignmentRequest(title: title, dueDate: dueDate, instructions: instructions, pointsPossible: pointsPossible, pointsAwarded: pointsAwarded, courseId: courseId)
        let response: AssignmentResponse = try await request(
            Endpoint(path: "api/subjects/assignments/\(id)", method: .patch, body: body),
            responseType: AssignmentResponse.self
        )
        return response.assignment
    }
    
    func deleteAssignment(id: String) async throws {
        _ = try await request(
            Endpoint(path: "api/subjects/assignments/\(id)", method: .delete),
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
        
        // Use a longer timeout for portfolio creation (5 minutes)
        let endpoint = Endpoint(path: "api/portfolios", method: .post, body: body)
        var urlRequest = try endpoint.urlRequest(baseURL: baseURL)
        if let token = tokenStore.token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create a session with longer timeout for portfolio creation
        let longTimeoutConfig = URLSessionConfiguration.default
        longTimeoutConfig.timeoutIntervalForRequest = 300  // 5 minutes
        longTimeoutConfig.timeoutIntervalForResource = 300  // 5 minutes
        longTimeoutConfig.waitsForConnectivity = true
        let longTimeoutSession = URLSession(configuration: longTimeoutConfig)
        
        let (data, response) = try await longTimeoutSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder.api
            let portfolioResponse = try decoder.decode(PortfolioResponse.self, from: data)
            return portfolioResponse.portfolio
        default:
            throw try APIError(from: data, statusCode: httpResponse.statusCode)
        }
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
    
    // Add Child (parent invite flow)
    struct CreateChildRequest: Encodable {
        let name: String
        let email: String?
    }
    struct CreateChildResponse: Decodable {
        let child: User
        let inviteLink: String
        let inviteToken: String
    }
    struct AcceptInviteResponse: Decodable {
        let token: String
        let user: User
    }
    func createChild(name: String, email: String?) async throws -> CreateChildResponse {
        let body = CreateChildRequest(name: name, email: email)
        return try await request(
            Endpoint(path: "api/users/me/children", method: .post, body: body),
            responseType: CreateChildResponse.self
        )
    }
    func acceptInvite(token: String) async throws -> AcceptInviteResponse {
        let body = ["token": token]
        return try await request(
            Endpoint(path: "api/invite/accept", method: .post, body: body),
            responseType: AcceptInviteResponse.self
        )
    }

    struct ChildInviteResponse: Decodable {
        let inviteLink: String
        let inviteToken: String
    }
    func fetchChildInvite(childId: String) async throws -> ChildInviteResponse {
        try await request(
            Endpoint(path: "api/users/me/children/\(childId)/invite"),
            responseType: ChildInviteResponse.self
        )
    }

    func deleteChild(childId: String) async throws {
        _ = try await request(
            Endpoint(path: "api/users/me/children/\(childId)", method: .delete),
            responseType: EmptyResponse.self
        )
    }

    /// Link Apple ID to the current user (e.g. student after first login via invite).
    func linkApple(identityToken: String) async throws -> UserResponse {
        try await request(
            Endpoint(path: "api/users/me/link-apple", method: .post, body: ["identityToken": identityToken]),
            responseType: UserResponse.self
        )
    }

    /// Link Google account to the current user.
    func linkGoogle(idToken: String) async throws -> UserResponse {
        try await request(
            Endpoint(path: "api/users/me/link-google", method: .post, body: ["idToken": idToken]),
            responseType: UserResponse.self
        )
    }

    /// Set username and/or password for the current user (e.g. student adding sign-in method).
    func setUsernamePassword(username: String?, password: String?) async throws -> UserResponse {
        var body: [String: String] = [:]
        if let u = username, !u.isEmpty { body["username"] = u }
        if let p = password, !p.isEmpty { body["password"] = p }
        return try await request(
            Endpoint(path: "api/users/me/set-username-password", method: .post, body: body),
            responseType: UserResponse.self
        )
    }

    // MARK: - Resources (folders + file/link/photo/video, optional assignment link)
    struct ResourceFoldersResponse: Decodable { let folders: [ResourceFolder] }
    struct ResourceFolderResponse: Decodable { let folder: ResourceFolder }
    struct ResourcesResponse: Decodable { let resources: [Resource] }
    struct ResourceResponse: Decodable { let resource: Resource }

    func fetchResourceFolders() async throws -> [ResourceFolder] {
        let r = try await request(Endpoint(path: "api/resources/folders"), responseType: ResourceFoldersResponse.self)
        return r.folders
    }
    struct CreateResourceFolderRequest: Encodable {
        let name: String
        let parentFolderId: String?
    }
    struct UpdateResourceFolderRequest: Encodable {
        let name: String?
        let parentFolderId: String?
    }
    func createResourceFolder(name: String, parentFolderId: String?) async throws -> ResourceFolder {
        let body = CreateResourceFolderRequest(name: name, parentFolderId: parentFolderId)
        let r = try await request(Endpoint(path: "api/resources/folders", method: .post, body: body), responseType: ResourceFolderResponse.self)
        return r.folder
    }
    func updateResourceFolder(id: String, name: String?, parentFolderId: String?) async throws -> ResourceFolder {
        let body = UpdateResourceFolderRequest(name: name, parentFolderId: parentFolderId)
        let r = try await request(Endpoint(path: "api/resources/folders/\(id)", method: .patch, body: body), responseType: ResourceFolderResponse.self)
        return r.folder
    }
    func deleteResourceFolder(id: String) async throws {
        _ = try await request(Endpoint(path: "api/resources/folders/\(id)", method: .delete), responseType: EmptyResponse.self)
    }
    func fetchResources(folderId: String? = nil) async throws -> [Resource] {
        var endpoint = Endpoint(path: "api/resources")
        if let fid = folderId {
            endpoint.queryItems = [URLQueryItem(name: "folderId", value: fid)]
        }
        let r = try await request(endpoint, responseType: ResourcesResponse.self)
        return r.resources
    }
    func fetchResourcesForAssignment(assignmentId: String) async throws -> [Resource] {
        let r = try await request(
            Endpoint(path: "api/resources/for-assignment/\(assignmentId)"),
            responseType: ResourcesResponse.self
        )
        return r.resources
    }
    struct CreateResourceLinkRequest: Encodable {
        let displayName: String
        let type: String = "link"
        let url: String
        let folderId: String?
        let assignmentId: String?
    }
    func createResourceLink(displayName: String, url: String, folderId: String?, assignmentId: String?) async throws -> Resource {
        let body = CreateResourceLinkRequest(displayName: displayName, url: url, folderId: folderId, assignmentId: assignmentId)
        let r = try await request(Endpoint(path: "api/resources", method: .post, body: body), responseType: ResourceResponse.self)
        return r.resource
    }
    func uploadResource(displayName: String, type: ResourceType, folderId: String?, assignmentId: String?, fileName: String, fileData: Data, mimeType: String) async throws -> Resource {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/resources/upload"))
        request.httpMethod = "POST"
        if let token = tokenStore.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("displayName", displayName)
        appendField("type", type.rawValue)
        if let f = folderId { appendField("folderId", f) }
        if let a = assignmentId { appendField("assignmentId", a) }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else { throw try APIError(from: data, statusCode: httpResponse.statusCode) }
        return try JSONDecoder.api.decode(ResourceResponse.self, from: data).resource
    }
    struct UpdateResourceRequest: Encodable {
        let displayName: String?
        let folderId: String?
        let assignmentId: String?
    }
    func updateResource(id: String, displayName: String?, folderId: String?, assignmentId: String?) async throws -> Resource {
        let body = UpdateResourceRequest(displayName: displayName, folderId: folderId, assignmentId: assignmentId)
        let r = try await request(Endpoint(path: "api/resources/\(id)", method: .patch, body: body), responseType: ResourceResponse.self)
        return r.resource
    }
    func deleteResource(id: String) async throws {
        _ = try await request(Endpoint(path: "api/resources/\(id)", method: .delete), responseType: EmptyResponse.self)
    }
    /// Full URL for a resource file (for opening in browser or app).
    func fullURL(forFileUrl fileUrl: String) -> URL? {
        guard !fileUrl.isEmpty else { return nil }
        let path = fileUrl.hasPrefix("/") ? String(fileUrl.dropFirst()) : fileUrl
        return baseURL.appendingPathComponent(path)
    }

    /// Downloads a resource's file via the authenticated API (GET /api/resources/:id/file) and returns a local temp file URL for preview.
    /// The server looks up the resource in the DB and streams the actual file from disk, so you always get the correct content.
    func downloadResourceFile(resourceId: String, displayName: String?, mimeType: String?) async throws -> URL {
        let endpoint = Endpoint(path: "api/resources/\(resourceId)/file")
        var request = try endpoint.urlRequest(baseURL: baseURL)
        if let token = tokenStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        if contentType.contains("text/html") || contentType.contains("application/json") {
            throw APIError.invalidResponse
        }
        var ext = ""
        if let mime = mimeType?.lowercased() {
            ext = Self.fileExtension(forMimeType: mime)
        }
        if ext.isEmpty, let name = displayName, !name.isEmpty {
            let fromName = (name as NSString).pathExtension.lowercased()
            if ["doc", "docx", "pdf", "xls", "xlsx", "ppt", "pptx", "txt", "rtf"].contains(fromName) {
                ext = fromName
            }
        }
        let safeExt = ext.isEmpty ? "" : ".\(ext)"
        let base: String
        if let name = displayName?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            let sanitized = name
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "\\", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: "*", with: "_")
                .replacingOccurrences(of: "?", with: "_")
                .replacingOccurrences(of: "\"", with: "_")
                .replacingOccurrences(of: "<", with: "_")
                .replacingOccurrences(of: ">", with: "_")
                .replacingOccurrences(of: "|", with: "_")
            let withoutExt = (sanitized as NSString).deletingPathExtension
            base = withoutExt.isEmpty ? "preview" : withoutExt
        } else {
            base = "preview"
        }
        let filename = base + safeExt
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }
        try data.write(to: tempURL)
        return tempURL
    }

    private static func fileExtension(forMimeType mimeType: String) -> String {
        let mime = mimeType.split(separator: ";").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? mimeType
        switch mime {
        case "image/jpeg", "image/jpg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/heic": return "heic"
        case "image/webp": return "webp"
        case "application/pdf": return "pdf"
        case "application/msword": return "doc"
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document": return "docx"
        case "text/plain": return "txt"
        case "text/html": return "html"
        case "application/json": return "json"
        default: return ""
        }
    }

    // Two-Factor Authentication API methods
    struct TwoFactorSetupResponse: Decodable {
        let secret: String
        let qrCode: String
        let manualEntryKey: String
    }
    
    struct TwoFactorVerifyResponse: Decodable {
        let success: Bool
        let message: String
    }
    
    func setupTwoFactor() async throws -> TwoFactorSetupResponse {
        return try await request(
            Endpoint(path: "api/users/me/2fa/setup", method: .post),
            responseType: TwoFactorSetupResponse.self
        )
    }
    
    func verifyTwoFactor(code: String) async throws -> TwoFactorVerifyResponse {
        let body = ["code": code]
        return try await request(
            Endpoint(path: "api/users/me/2fa/verify", method: .post, body: body),
            responseType: TwoFactorVerifyResponse.self
        )
    }
    
    func disableTwoFactor(code: String?) async throws -> TwoFactorVerifyResponse {
        var body: [String: String] = [:]
        if let code = code {
            body["code"] = code
        }
        return try await request(
            Endpoint(path: "api/users/me/2fa/disable", method: .post, body: body),
            responseType: TwoFactorVerifyResponse.self
        )
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

