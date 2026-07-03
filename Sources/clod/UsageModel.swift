import Foundation
import Observation

@MainActor
@Observable
final class UsageModel {
  private(set) var usage: Usage?
  private(set) var lastScan: Date?
  private(set) var error: String?

  private let fetcher = UsageFetcher()
  private var refreshTask: Task<Void, Never>?

  private static let refreshInterval: Double = 300

  func start() {
    refreshTask = Task { [weak self] in
      while !Task.isCancelled {
        _ = await self?.refresh() ?? false
        try? await Task.sleep(for: .seconds(Self.refreshInterval))
      }
    }
  }

  func refreshNow() {
    Task { await refresh() }
  }

  @discardableResult
  private func refresh() async -> Bool {
    let fetcher = self.fetcher
    do {
      let result = try await Task.detached(priority: .utility) {
        try await fetcher.fetch()
      }.value
      usage = result
      error = nil
      lastScan = Date()
      return true
    } catch {
      self.error = error.localizedDescription
      lastScan = Date()
      return false
    }
  }

  var menuBarTitle: String {
    guard let usage else { return "–" }
    return "\(Int(usage.fiveHour.utilization.rounded()))%"
  }
}
