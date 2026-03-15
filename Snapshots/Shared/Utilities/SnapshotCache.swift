import Foundation

final class SnapshotCache {
    static let shared = SnapshotCache()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let memoryCache = NSCache<NSString, NSData>()
    private let ioQueue = DispatchQueue(label: "snapshots.cache.io", qos: .utility)

    private init() {
        memoryCache.countLimit = 64
        memoryCache.totalCostLimit = 5 * 1024 * 1024
    }

    func load<Value: Codable>(_ type: Value.Type, key: String, maxAge: TimeInterval? = nil) async -> Value? {
        let data: Data? = await withCheckedContinuation { continuation in
            ioQueue.async {
                let cacheKey = key as NSString

                if let cachedData = self.memoryCache.object(forKey: cacheKey) as Data? {
                    continuation.resume(returning: cachedData)
                    return
                }

                let fileURL = self.fileURL(for: key)
                guard let data = try? Data(contentsOf: fileURL) else {
                    continuation.resume(returning: nil)
                    return
                }

                self.memoryCache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
                continuation.resume(returning: data)
            }
        }

        guard let data,
              let payload = try? decoder.decode(CachePayload<Value>.self, from: data),
              isFresh(savedAt: payload.savedAt, maxAge: maxAge) else {
            return nil
        }

        return payload.value
    }

    func save<Value: Codable>(_ value: Value, key: String) async {
        let payload = CachePayload(savedAt: Date(), value: value)
        guard let data = try? encoder.encode(payload) else { return }

        await withCheckedContinuation { continuation in
            ioQueue.async {
                do {
                    try self.fileManager.createDirectory(at: self.cacheDirectoryURL, withIntermediateDirectories: true)
                    try data.write(to: self.fileURL(for: key), options: .atomic)
                    self.memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
                } catch {
                    print("SnapshotCache save failed for \(key): \(error)")
                }

                continuation.resume()
            }
        }
    }

    func remove(key: String) async {
        await withCheckedContinuation { continuation in
            ioQueue.async {
                self.memoryCache.removeObject(forKey: key as NSString)
                try? self.fileManager.removeItem(at: self.fileURL(for: key))
                continuation.resume()
            }
        }
    }

    private var cacheDirectoryURL: URL {
        let rootURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return rootURL.appendingPathComponent("SnapshotsCache", isDirectory: true)
    }

    private func fileURL(for key: String) -> URL {
        cacheDirectoryURL.appendingPathComponent(safeFilename(for: key)).appendingPathExtension("json")
    }

    private func isFresh(savedAt: Date, maxAge: TimeInterval?) -> Bool {
        guard let maxAge else { return true }
        return Date().timeIntervalSince(savedAt) <= maxAge
    }

    private func safeFilename(for key: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(.init(charactersIn: "-_."))
        return key.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : "_"
        }.reduce(into: "") { partialResult, character in
            partialResult.append(character)
        }
    }
}

private struct CachePayload<Value: Codable>: Codable {
    let savedAt: Date
    let value: Value
}
