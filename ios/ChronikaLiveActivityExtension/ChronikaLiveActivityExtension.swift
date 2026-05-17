import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {
    var appGroupId: String
  }

  var id = UUID()
}

private let sharedDefaults = UserDefaults(suiteName: "group.app.greenmonster.timereviewer")!

@available(iOSApplicationExtension 16.1, *)
struct ChronikaLiveActivityExtension: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      ChronikaLiveActivityView(context: context, compact: false)
        .activityBackgroundTint(Color.clear)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          ChronikaTimerText(context: context, short: true)
        }
      } compactLeading: {
        EmptyView()
      } compactTrailing: {
        ChronikaTimerText(context: context, short: true)
      } minimal: {
        EmptyView()
      }
      .keylineTint(Color.clear)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaLiveActivityView: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>
  let compact: Bool

  var body: some View {
    let color = Color(hex: value(context, "trackableColor", "#246BFE")).softened()
    let sessionUrl = URL(string: value(context, "goToSessionUrl", "chronika://session"))!
    let pauseUrl = URL(string: value(context, "pauseUrl", "chronika://session"))!

    Link(destination: sessionUrl) {
      VStack(alignment: .leading, spacing: compact ? 7 : 9) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 2) {
            Text(value(context, "trackableName", "Activity"))
              .font((compact ? Font.headline : Font.title3).weight(.black))
              .lineLimit(1)
              .minimumScaleFactor(0.78)
              .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
            Text(value(context, "activeModeName", "main"))
              .font(.caption.weight(.bold))
              .foregroundStyle(.white.opacity(0.78))
              .lineLimit(1)
              .minimumScaleFactor(0.78)
              .shadow(color: .black.opacity(0.05), radius: 0.8, x: 0, y: 1)
          }
          Spacer(minLength: 8)
          ChronikaTimerText(context: context, short: false)
        }

        HStack(spacing: compact ? 4 : 5) {
          ForEach(0..<min(Int(number(context, "modeCount", 0)), 4), id: \.self) { index in
            ChronikaModePill(context: context, index: index)
          }
          Spacer(minLength: 2)
          if bool(context, "isActive", true) {
            Link(destination: pauseUrl) {
              ChronikaGlassPillLabel("Pause", compact: compact)
            }
          }
          ChronikaGlassPillLabel("Go to Session", compact: compact)
        }
      }
      .padding(.horizontal, compact ? 8 : 13)
      .padding(.vertical, compact ? 8 : 11)
      .background(
        ChronikaGlassBackground(accent: color)
      )
      .foregroundStyle(.white)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaGlassBackground: View {
  let accent: Color

  var body: some View {
    let boostedAccent = accent.boostedForGlass()
    RoundedRectangle(cornerRadius: 22, style: .continuous)
      .fill(boostedAccent.opacity(0.22))
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(.thinMaterial.opacity(0.42))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(boostedAccent.opacity(0.30))
      )
      .overlay(
        LinearGradient(
          colors: [
            Color.white.opacity(0.12),
            boostedAccent.opacity(0.24),
            boostedAccent.opacity(0.26),
            Color(red: 0.72, green: 0.88, blue: 1.00).opacity(0.08)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(boostedAccent.opacity(0.12))
          .blendMode(.screen)
      )
      .overlay(
        LinearGradient(
          colors: [
            Color.white.opacity(0.20),
            Color.white.opacity(0.06),
            Color.clear
          ],
          startPoint: .topLeading,
          endPoint: .center
        )
        .blendMode(.screen)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(Color.white.opacity(0.22), lineWidth: 0.7)
      )
      .shadow(color: Color.black.opacity(0.035), radius: 5, x: 0, y: 2)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaGlassPillLabel: View {
  let title: String
  let compact: Bool

  init(_ title: String, compact: Bool = false) {
    self.title = title
    self.compact = compact
  }

  var body: some View {
    Text(title)
      .font((compact ? Font.caption2 : Font.caption).weight(.black))
      .lineLimit(1)
      .minimumScaleFactor(0.70)
      .fixedSize(horizontal: true, vertical: false)
      .padding(.horizontal, compact ? 7 : 9)
      .padding(.vertical, compact ? 5 : 6)
      .background(.ultraThinMaterial, in: Capsule())
      .overlay(
        Capsule()
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(0.16),
                Color.white.opacity(0.05),
                Color.clear
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .overlay(
        Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.6)
      )
      .shadow(color: Color.black.opacity(0.035), radius: 1.5, x: 0, y: 1)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaModePill: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>
  let index: Int
  var compact = false

  var body: some View {
    let name = value(context, "mode\(index)Name", "")
    let url = URL(string: value(context, "mode\(index)Url", value(context, "goToSessionUrl", "chronika://session")))!
    let isActive = bool(context, "mode\(index)Active", false)

    Link(destination: url) {
      Text(name.isEmpty ? "main" : name)
        .font((compact ? Font.caption2 : Font.caption).weight(.black))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.horizontal, compact ? 7 : 8)
        .padding(.vertical, compact ? 4 : 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
          Capsule()
            .fill(
              LinearGradient(
                colors: [
                  .white.opacity(isActive ? 0.18 : 0.10),
                  .white.opacity(isActive ? 0.06 : 0.03),
                  .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
        )
        .overlay(
          Capsule().stroke(.white.opacity(isActive ? 0.24 : 0.14), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.035), radius: 1.2, x: 0, y: 1)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaTimerText: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>
  let short: Bool

  var body: some View {
    if bool(context, "isActive", true) {
      Text(timerInterval: timerRange(context), countsDown: false)
        .monospacedDigit()
        .font((short ? Font.caption2 : Font.headline).weight(.black))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
    } else {
      Text(formatDuration(Int(number(context, "trackableDurationSeconds", 0))))
        .monospacedDigit()
        .font((short ? Font.caption2 : Font.headline).weight(.black))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
    }
  }

  private func timerRange(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> ClosedRange<Date> {
    let duration = number(context, "trackableDurationSeconds", 0)
    let updatedAt = Date(timeIntervalSince1970: number(context, "updatedAtMillis", 0) / 1000)
    let start = updatedAt.addingTimeInterval(-duration)
    return start...Date.distantFuture
  }
}

@main
@available(iOSApplicationExtension 16.1, *)
struct ChronikaLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    ChronikaLiveActivityExtension()
  }
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    return "\(id)_\(key)"
  }
}

private func value(
  _ context: ActivityViewContext<LiveActivitiesAppAttributes>,
  _ key: String,
  _ fallback: String
) -> String {
  sharedDefaults.string(forKey: context.attributes.prefixedKey(key)) ?? fallback
}

private func number(
  _ context: ActivityViewContext<LiveActivitiesAppAttributes>,
  _ key: String,
  _ fallback: Double
) -> Double {
  let object = sharedDefaults.object(forKey: context.attributes.prefixedKey(key))
  if let value = object as? Double {
    return value
  }
  if let value = object as? Int {
    return Double(value)
  }
  if let value = object as? String, let parsed = Double(value) {
    return parsed
  }
  return fallback
}

private func bool(
  _ context: ActivityViewContext<LiveActivitiesAppAttributes>,
  _ key: String,
  _ fallback: Bool
) -> Bool {
  let object = sharedDefaults.object(forKey: context.attributes.prefixedKey(key))
  if let value = object as? Bool {
    return value
  }
  if let value = object as? String {
    return value == "true"
  }
  return fallback
}

private func formatDuration(_ seconds: Int) -> String {
  let hours = seconds / 3600
  let minutes = (seconds % 3600) / 60
  let secs = seconds % 60
  if hours > 0 {
    return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", secs))"
  }
  return "\(minutes):\(String(format: "%02d", secs))"
}

private extension Color {
  func softened() -> Color {
    self
  }

  func boostedForGlass() -> Color {
    let uiColor = UIColor(self)
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    guard uiColor.getHue(
      &hue,
      saturation: &saturation,
      brightness: &brightness,
      alpha: &alpha
    ) else {
      return self
    }
    return Color(
      hue: Double(hue),
      saturation: Double(min(max(saturation * 1.18, 0.62), 1.0)),
      brightness: Double(min(max(brightness * 1.12, 0.72), 1.0))
    )
  }

  init(hex: String) {
    let cleaned = hex.replacingOccurrences(of: "#", with: "")
    var value: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&value)
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
  }
}
