import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = UsageModel()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    model.start()
  }
}

@main
enum Main {
  static func main() async {
    if CommandLine.arguments.contains("--usage") {
      do {
        let usage = try await UsageFetcher().fetch()
        let now = Date()
        let fh = usage.fiveHour
        if let resetsAt = fh.resetsAt, resetsAt > now {
          let minutes = Int(resetsAt.timeIntervalSince(now) / 60)
          print("5 hour usage: \(Int(fh.utilization.rounded()))%")
          print("resets at: \(resetsAt.formatted()) (in \(minutes) minutes)")
        } else {
          print("5 hour usage: N/A")
        }
        let sd = usage.sevenDay
        print("7 day usage: \(Int(sd.utilization.rounded()))%")
        if let resetsAt = sd.resetsAt {
          print("resets at: \(resetsAt.formatted())")
        }
      } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
      }
      return
    }
    ClodApp.main()
  }
}

struct ClodApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra {
      MenuContent(model: appDelegate.model)
    } label: {
      Image(systemName: "gauge.with.needle")
      Text(appDelegate.model.menuBarTitle)
    }
    .menuBarExtraStyle(.menu)
  }
}

private struct MenuContent: View {
  var model: UsageModel

  var body: some View {
    Group {
      if let usage = model.usage {
        let now = Date()

        Text("5h: \(pct(usage.fiveHour.utilization))")
        if let resetsAt = usage.fiveHour.resetsAt, resetsAt > now {
          Text("Resets \(resetsAt.formatted(date: .omitted, time: .shortened)) (\(relative(until: resetsAt)))")
        }

        Divider()

        Text("7d: \(pct(usage.sevenDay.utilization))")
        if let resetsAt = usage.sevenDay.resetsAt {
          Text("Resets \(resetsAt.formatted(date: .abbreviated, time: .shortened))")
        }
      } else if let error = model.error {
        Text(error).foregroundStyle(.red)
      } else {
        Text("Loading...")
      }

      Divider()

      Button("Refresh") { model.refreshNow() }.keyboardShortcut("r")
      Button("Quit clod") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
    .onAppear { model.refreshNow() }
  }

  private func pct(_ v: Double) -> String { "\(Int(v.rounded()))%" }

  private func relative(until date: Date) -> String {
    let seconds = max(0, Int(date.timeIntervalSinceNow))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    return hours > 0 ? "in \(hours)h \(minutes)m" : "in \(minutes)m"
  }
}
