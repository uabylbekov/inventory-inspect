import Foundation
import SwiftUI
import Supabase

enum InspectionImageStorage {
    static let bucket = "inspection-images"
    private static let signedURLLifetime = 60 * 60

    static func normalizePath(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func signedURL(for path: String, width: Int? = nil, height: Int? = nil) async throws -> URL {
        try await InspectionImageURLCache.shared.url(for: path, width: width, height: height)
    }

    fileprivate static func makeSignedURL(path: String, width: Int?, height: Int?) async throws -> URL {
        let transform: TransformOptions? = if width != nil || height != nil {
            TransformOptions(width: width, height: height, resize: "contain", quality: 80)
        } else {
            nil
        }

        return try await supabase.storage
            .from(bucket)
            .createSignedURL(
                path: path,
                expiresIn: signedURLLifetime,
                transform: transform
            )
    }
}

actor InspectionImageURLCache {
    static let shared = InspectionImageURLCache()

    private struct Entry {
        let url: URL
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]

    func url(for path: String, width: Int?, height: Int?) async throws -> URL {
        let key = "\(path)|\(width.map(String.init) ?? "-")|\(height.map(String.init) ?? "-")"
        let now = Date()

        if let entry = entries[key], entry.expiresAt > now {
            return entry.url
        }

        let url = try await InspectionImageStorage.makeSignedURL(path: path, width: width, height: height)
        entries[key] = Entry(url: url, expiresAt: now.addingTimeInterval(50 * 60))
        return url
    }
}

struct InspectionEvidenceAsyncImage<Content: View, Placeholder: View>: View {
    let imagePath: String?
    let width: Int?
    let height: Int?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var resolvedURL: URL?

    init(
        imagePath: String?,
        width: Int? = nil,
        height: Int? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.imagePath = InspectionImageStorage.normalizePath(imagePath)
        self.width = width
        self.height = height
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let resolvedURL {
                CachedAsyncImage(url: resolvedURL) { image in
                    content(image)
                } placeholder: {
                    placeholder()
                }
            } else {
                placeholder()
            }
        }
        .task(id: taskKey) {
            await resolveURL()
        }
    }

    private var taskKey: String {
        "\(imagePath ?? "nil")|\(width.map(String.init) ?? "-")|\(height.map(String.init) ?? "-")"
    }

    private func resolveURL() async {
        guard let imagePath else {
            resolvedURL = nil
            return
        }

        do {
            resolvedURL = try await InspectionImageStorage.signedURL(for: imagePath, width: width, height: height)
        } catch {
            resolvedURL = nil
            print("Failed to create signed inspection image URL for \(imagePath): \(error)")
        }
    }
}

struct InspectionEvidenceFullScreenView: View {
    let imagePath: String
    @State private var resolvedURL: URL?

    var body: some View {
        Group {
            if let resolvedURL {
                FullScreenImageView(image: .remote(resolvedURL))
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            }
        }
        .task(id: imagePath) {
            do {
                resolvedURL = try await InspectionImageStorage.signedURL(for: imagePath)
            } catch {
                resolvedURL = nil
                print("Failed to create full-screen signed inspection image URL for \(imagePath): \(error)")
            }
        }
    }
}
