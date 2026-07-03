import AppKit
import Observation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  let model = UsageModel()
  var statusItem: NSStatusItem!

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    model.start()

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
      button.image = NSImage(systemSymbolName: "gauge.with.needle", accessibilityDescription: nil)
    }

    let menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu

    observeModel()
  }

  private func observeModel() {
    withObservationTracking {
      statusItem.button?.title = model.menuBarTitle.isEmpty ? "" : " \(model.menuBarTitle)"
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observeModel() }
    }
  }

  func menuWillOpen(_ menu: NSMenu) {
    model.refreshIfStale()
    buildMenu(menu)
  }

  private func buildMenu(_ menu: NSMenu) {
    menu.removeAllItems()

    if let usage = model.usage {
      let now = Date()

      menu.addItem(disabled("5h: \(pct(usage.fiveHour.utilization))"))
      if let resetsAt = usage.fiveHour.resetsAt, resetsAt > now {
        menu.addItem(
          disabled(
            "Resets \(resetsAt.formatted(date: .omitted, time: .shortened)) (\(relative(until: resetsAt)))"
          ))
      }

      menu.addItem(.separator())

      menu.addItem(disabled("7d: \(pct(usage.sevenDay.utilization))"))
      if let resetsAt = usage.sevenDay.resetsAt {
        menu.addItem(disabled("Resets \(resetsAt.formatted(date: .abbreviated, time: .shortened))"))
      }
    } else if let error = model.error {
      menu.addItem(disabled(error))
    } else {
      menu.addItem(disabled("Loading..."))
    }

    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"))
    menu.addItem(NSMenuItem(title: "Quit clod", action: #selector(quit), keyEquivalent: "q"))
  }

  private func disabled(_ title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    return item
  }

  @objc private func refresh() { model.refreshNow() }
  @objc private func quit() { NSApplication.shared.terminate(nil) }

  private func pct(_ v: Double) -> String { "\(Int(v.rounded()))%" }

  private func relative(until date: Date) -> String {
    let seconds = max(0, Int(date.timeIntervalSinceNow))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    return hours > 0 ? "in \(hours)h \(minutes)m" : "in \(minutes)m"
  }
}

@main
enum Main {
  static func main() {
    if CommandLine.arguments.contains("--usage") {
      Task { @MainActor in
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
        exit(0)
      }
      RunLoop.main.run()
      return
    }

    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
  }
}
