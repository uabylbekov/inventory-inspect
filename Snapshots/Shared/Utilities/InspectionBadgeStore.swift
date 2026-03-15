import Foundation
import Auth
import Supabase

@Observable @MainActor
final class InspectionBadgeStore {
    static let shared = InspectionBadgeStore()

    var ongoingCount = 0
    private var pollingTask: Task<Void, Never>?

    private init() {}

    func refresh() async {
        do {
            let session = try await supabase.auth.session
            let inspections = try await InspectionDataService.loadAccessibleInspections(for: session.user.id)
            ongoingCount = inspections.filter { $0.status == "in_progress" }.count
        } catch {
            ongoingCount = 0
        }
    }

    func clear() {
        ongoingCount = 0
    }

    func startMonitoring() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }

            await refresh()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }

    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
