import Foundation

final class OfflineCache {
    static let shared = OfflineCache()
    
    private let fileManager = FileManager.default
    private let directory: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("OfflineCache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    
    func save<T: Encodable>(_ value: T, as fileName: String) {
        let url = directory.appendingPathComponent(fileName)
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            print("OfflineCache save error: \(error)")
        }
    }
    
    func load<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
    
    func remove(_ fileName: String) {
        let url = directory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }
    
    func wipeAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

