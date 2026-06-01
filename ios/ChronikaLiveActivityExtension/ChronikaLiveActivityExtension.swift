import ActivityKit
import AppIntents
import SwiftUI
import UIKit
import WidgetKit

private let sharedDefaults = UserDefaults(suiteName: ChronikaLiveActivityKeys.appGroupId)!

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
    let sessionUrl = safeUrl(value(context, "goToSessionUrl", "chronika://session"))
    let previousColor = Color(hex: value(context, "previousTrackableColor", "#7C3AED")).softened()

    if #available(iOSApplicationExtension 17.0, *) {
      ChronikaLiveActivityContent(
        context: context,
        compact: compact,
        accent: color,
        sessionUrl: sessionUrl,
        previousColor: previousColor,
        interactive: true
      )
    } else {
      Link(destination: sessionUrl) {
        ChronikaLiveActivityContent(
          context: context,
          compact: compact,
          accent: color,
          sessionUrl: sessionUrl,
          previousColor: previousColor,
          interactive: false
        )
      }
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaLiveActivityContent: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>
  let compact: Bool
  let accent: Color
  let sessionUrl: URL
  let previousColor: Color
  let interactive: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: bool(context, "hasPreviousActivity", false) ? 7 : 0) {
      ChronikaCurrentActivityPanel(
        context: context,
        compact: compact,
        accent: accent,
        sessionUrl: sessionUrl,
        interactive: interactive
      )

      if bool(context, "hasPreviousActivity", false) {
        ChronikaPreviousActivityRow(
          context: context,
          compact: compact,
          accent: previousColor,
          interactive: interactive
        )
      }
    }
    .padding(.horizontal, compact ? 9 : 11)
    .padding(.vertical, compact ? 8 : 9)
    .background(ChronikaSessionGlassBackground(accent: accent.boostedForGlass()))
    .foregroundStyle(.white)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaCurrentActivityPanel: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>
  let compact: Bool
  let accent: Color
  let sessionUrl: URL
  let interactive: Bool

  var body: some View {
    let modeCount = min(Int(number(context, "modeCount", 0)), 4)

    ZStack(alignment: .leading) {
      Rectangle()
        .fill(accent.boostedForGlass())
        .frame(width: 4)
        .clipShape(Capsule())
        .padding(.vertical, 2)

      HStack(alignment: .top, spacing: compact ? 10 : 12) {
        VStack(alignment: .leading, spacing: compact ? 7 : 8) {
          VStack(alignment: .leading, spacing: 1) {
            Text(value(context, "trackableName", "Activity"))
              .font((compact ? Font.headline : Font.title3).weight(.black))
              .lineLimit(1)
              .minimumScaleFactor(0.64)
            ChronikaDurationText(
              context: context,
              durationKey: "trackableDurationSeconds",
              fallbackKey: "trackableDurationSeconds",
              active: bool(context, "isActive", true),
              font: (compact ? Font.headline : Font.title3).weight(.black),
              accent: accent.boostedForGlass()
            )
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Text(value(context, "activeModeName", "main"))
                .font(Font.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
              ChronikaDurationText(
                context: context,
                durationKey: "activeModeDurationSeconds",
                fallbackKey: "trackableDurationSeconds",
                active: bool(context, "isActive", true),
                font: Font.caption2.weight(.black),
                accent: accent.boostedForGlass().opacity(0.88)
              )
            }
          }

          if shouldShowModes(context: context, prefix: "mode", count: modeCount) {
            HStack(spacing: 5) {
              ForEach(0..<modeCount, id: \.self) { index in
                ChronikaModeControl(
                  context: context,
                  index: index,
                  compact: compact,
                  interactive: interactive,
                  accent: accent.boostedForGlass()
                )
              }
              Spacer(minLength: 0)
            }
          }
        }

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: compact ? 3 : 4) {
          Text(value(context, "sessionName", "Session"))
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.68))
            .lineLimit(1)
            .minimumScaleFactor(0.70)
          ChronikaDurationText(
            context: context,
            durationKey: "sessionDurationSeconds",
            fallbackKey: "trackableDurationSeconds",
            active: bool(context, "isActive", true),
            font: Font.caption.weight(.black),
            accent: .white.opacity(0.86)
          )
          .frame(maxWidth: .infinity, alignment: .trailing)
          Link(destination: sessionUrl) {
            ChronikaCircleIcon(
              systemName: "arrow.up.right",
              accent: accent.boostedForGlass(),
              compact: compact,
              large: false
            )
          }
        }
        .frame(width: compact ? 92 : 112, alignment: .trailing)
      }
      .padding(.leading, compact ? 13 : 16)
      .padding(.trailing, compact ? 8 : 10)
      .padding(.vertical, compact ? 5 : 6)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaPreviousActivityRow: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>
  let compact: Bool
  let accent: Color
  let interactive: Bool

  var body: some View {
    let modeCount = min(Int(number(context, "previousModeCount", 0)), 4)

    HStack(alignment: .center, spacing: 12) {
      Rectangle()
        .fill(accent.boostedForGlass())
        .frame(width: 4, height: compact ? 44 : 48)
        .clipShape(Capsule())

      VStack(alignment: .leading, spacing: compact ? 4 : 5) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(value(context, "previousTrackableName", "Previous"))
            .font((compact ? Font.subheadline : Font.headline).weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.64)
          Text(formatDuration(Int(number(context, "previousTrackableDurationSeconds", 0))))
            .monospacedDigit()
            .font((compact ? Font.caption : Font.subheadline).weight(.black))
            .foregroundStyle(accent.boostedForGlass())
            .lineLimit(1)
            .minimumScaleFactor(0.74)
        }

        if shouldShowModes(context: context, prefix: "previousMode", count: modeCount) {
          HStack(spacing: 5) {
            ForEach(0..<modeCount, id: \.self) { index in
              ChronikaPreviousModeControl(
                context: context,
                index: index,
                compact: compact,
                accent: accent.boostedForGlass(),
                interactive: interactive
              )
            }
            Spacer(minLength: 0)
          }
        }
      }

      Spacer(minLength: 8)

      if interactive, #available(iOSApplicationExtension 17.0, *) {
        Button(intent: previousIntent()) {
          ChronikaBackPill(accent: accent.boostedForGlass(), compact: compact)
        }
        .buttonStyle(.plain)
      } else {
        Link(destination: safeUrl(value(context, "previousActivityUrl", "chronika://session"))) {
          ChronikaBackPill(accent: accent.boostedForGlass(), compact: compact)
        }
      }
    }
    .padding(.horizontal, compact ? 6 : 8)
    .padding(.vertical, compact ? 3 : 4)
  }

  @available(iOSApplicationExtension 17.0, *)
  private func previousIntent() -> ChronikaSwitchActivityIntent {
    ChronikaSwitchActivityIntent(
      liveActivityId: context.attributes.id.uuidString,
      sessionId: value(context, "sessionId", ""),
      trackableId: value(context, "previousTrackableId", ""),
      trackableName: value(context, "previousTrackableName", "Previous"),
      trackableColor: value(context, "previousTrackableColor", "#7C3AED"),
      modeId: value(context, "previousModeId", "main"),
      modeName: value(context, "previousModeName", "Main"),
      targetDurationSeconds: Int(number(context, "previousTrackableDurationSeconds", 0)),
      sessionDurationSeconds: Int(number(context, "sessionDurationSeconds", number(context, "trackableDurationSeconds", 0))),
      currentTrackableId: value(context, "trackableId", ""),
      currentTrackableName: value(context, "trackableName", "Activity"),
      currentTrackableColor: value(context, "trackableColor", "#246BFE"),
      currentModeId: value(context, "activeModeId", "main"),
      currentModeName: value(context, "activeModeName", "Main")
    )
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaSessionGlassBackground: View {
  let accent: Color

  var body: some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
      .fill(Color(red: 0.03, green: 0.06, blue: 0.11).opacity(0.76))
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(.thinMaterial.opacity(0.28))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(accent.opacity(0.12))
      )
      .overlay(
        LinearGradient(
          colors: [
            Color.white.opacity(0.08),
            accent.opacity(0.18),
            Color.black.opacity(0.06)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(Color.white.opacity(0.16), lineWidth: 0.9)
      )
      .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaCircleIcon: View {
  let systemName: String
  let accent: Color
  let compact: Bool
  var large = false

  var body: some View {
    Image(systemName: systemName)
      .font((large ? Font.subheadline : Font.caption).weight(.black))
      .foregroundStyle(accent)
      .frame(
        width: large ? (compact ? 30 : 34) : (compact ? 24 : 28),
        height: large ? (compact ? 30 : 34) : (compact ? 24 : 28)
      )
      .background(
        Circle()
          .fill(accent.opacity(large ? 0.24 : 0.14))
          .overlay(Circle().fill(.thinMaterial.opacity(0.18)))
      )
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaBackPill: View {
  let accent: Color
  let compact: Bool

  var body: some View {
    Image(systemName: "arrow.uturn.backward")
      .font(.caption.weight(.black))
      .foregroundStyle(accent)
      .frame(width: compact ? 28 : 32, height: compact ? 26 : 30)
      .background(accent.opacity(0.18), in: Circle())
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaDurationText: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>
  let durationKey: String
  let fallbackKey: String
  let active: Bool
  let font: Font
  let accent: Color

  var body: some View {
    if active {
      Text(timerInterval: timerRange(context), countsDown: false)
        .monospacedDigit()
        .font(font)
        .foregroundStyle(accent)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
        .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
    } else {
      Text(formatDuration(Int(duration(context))))
        .monospacedDigit()
        .font(font)
        .foregroundStyle(accent)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
        .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
    }
  }

  private func duration(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> Double {
    number(context, durationKey, number(context, fallbackKey, 0))
  }

  private func timerRange(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> ClosedRange<Date> {
    let updatedAt = Date(timeIntervalSince1970: number(context, "updatedAtMillis", 0) / 1000)
    let start = updatedAt.addingTimeInterval(-duration(context))
    return start...Date.distantFuture
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
private struct ChronikaPreviousActivityPill: View {
  let title: String
  let accent: Color
  let compact: Bool

  var body: some View {
    Text(title)
      .font((compact ? Font.caption2 : Font.caption).weight(.black))
      .lineLimit(1)
      .minimumScaleFactor(0.68)
      .fixedSize(horizontal: true, vertical: false)
      .padding(.horizontal, compact ? 7 : 8)
      .padding(.vertical, compact ? 4 : 5)
      .background(accent.boostedForGlass().opacity(0.42), in: Capsule())
      .overlay(
        Capsule()
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(0.18),
                accent.boostedForGlass().opacity(0.14),
                Color.clear
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .overlay(
        Capsule().stroke(accent.boostedForGlass().opacity(0.62), lineWidth: 0.7)
      )
      .shadow(color: accent.opacity(0.15), radius: 2, x: 0, y: 1)
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
private struct ChronikaGlassIconLabel: View {
  let systemName: String
  let compact: Bool

  var body: some View {
    Image(systemName: systemName)
      .font((compact ? Font.caption2 : Font.caption).weight(.black))
      .frame(width: compact ? 26 : 30, height: compact ? 24 : 28)
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
private struct ChronikaModeControl: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>
  let index: Int
  let compact: Bool
  let interactive: Bool
  let accent: Color

  var body: some View {
    let name = value(context, "mode\(index)Name", "")
    let url = safeUrl(value(context, "mode\(index)Url", value(context, "goToSessionUrl", "chronika://session")))
    let isActive = bool(context, "mode\(index)Active", false)

    if interactive, #available(iOSApplicationExtension 17.0, *) {
      Button(intent: modeIntent(index: index, name: name)) {
        ChronikaModePillLabel(
          title: name.isEmpty ? "main" : name,
          isActive: isActive,
          compact: compact,
          accent: accent
        )
      }
      .buttonStyle(.plain)
    } else {
      Link(destination: url) {
        ChronikaModePillLabel(
          title: name.isEmpty ? "main" : name,
          isActive: isActive,
          compact: compact,
          accent: accent
        )
      }
    }
  }

  @available(iOSApplicationExtension 17.0, *)
  private func modeIntent(index: Int, name: String) -> ChronikaSwitchActivityIntent {
    ChronikaSwitchActivityIntent(
      liveActivityId: context.attributes.id.uuidString,
      sessionId: value(context, "sessionId", ""),
      trackableId: value(context, "trackableId", ""),
      trackableName: value(context, "trackableName", "Activity"),
      trackableColor: value(context, "trackableColor", "#246BFE"),
      modeId: value(context, "mode\(index)Id", "main"),
      modeName: name.isEmpty ? "main" : name,
      targetDurationSeconds: Int(number(context, "trackableDurationSeconds", 0)),
      sessionDurationSeconds: Int(number(context, "sessionDurationSeconds", number(context, "trackableDurationSeconds", 0))),
      currentTrackableId: value(context, "trackableId", ""),
      currentTrackableName: value(context, "trackableName", "Activity"),
      currentTrackableColor: value(context, "trackableColor", "#246BFE"),
      currentModeId: value(context, "activeModeId", "main"),
      currentModeName: value(context, "activeModeName", "Main")
    )
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaPreviousModeControl: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>
  let index: Int
  let compact: Bool
  let accent: Color
  let interactive: Bool

  var body: some View {
    let name = value(context, "previousMode\(index)Name", "")
    let url = safeUrl(value(context, "previousMode\(index)Url", value(context, "previousActivityUrl", "chronika://session")))
    let isActive = bool(context, "previousMode\(index)Active", false)

    if interactive, #available(iOSApplicationExtension 17.0, *) {
      Button(intent: modeIntent(index: index, name: name)) {
        ChronikaModePillLabel(
          title: name.isEmpty ? "main" : name,
          isActive: isActive,
          compact: compact,
          accent: accent
        )
      }
      .buttonStyle(.plain)
    } else {
      Link(destination: url) {
        ChronikaModePillLabel(
          title: name.isEmpty ? "main" : name,
          isActive: isActive,
          compact: compact,
          accent: accent
        )
      }
    }
  }

  @available(iOSApplicationExtension 17.0, *)
  private func modeIntent(index: Int, name: String) -> ChronikaSwitchActivityIntent {
    ChronikaSwitchActivityIntent(
      liveActivityId: context.attributes.id.uuidString,
      sessionId: value(context, "sessionId", ""),
      trackableId: value(context, "previousTrackableId", ""),
      trackableName: value(context, "previousTrackableName", "Previous"),
      trackableColor: value(context, "previousTrackableColor", "#7C3AED"),
      modeId: value(context, "previousMode\(index)Id", "main"),
      modeName: name.isEmpty ? "main" : name,
      targetDurationSeconds: Int(number(context, "previousTrackableDurationSeconds", 0)),
      sessionDurationSeconds: Int(number(context, "sessionDurationSeconds", number(context, "trackableDurationSeconds", 0))),
      currentTrackableId: value(context, "trackableId", ""),
      currentTrackableName: value(context, "trackableName", "Activity"),
      currentTrackableColor: value(context, "trackableColor", "#246BFE"),
      currentModeId: value(context, "activeModeId", "main"),
      currentModeName: value(context, "activeModeName", "Main")
    )
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ChronikaModePillLabel: View {
  let title: String
  let isActive: Bool
  let compact: Bool
  let accent: Color

  var body: some View {
    Text(title)
      .font((compact ? Font.caption2 : Font.caption).weight(.black))
      .foregroundStyle(isActive ? accent : Color.white.opacity(0.76))
      .lineLimit(1)
      .minimumScaleFactor(0.72)
      .padding(.horizontal, compact ? 8 : 10)
      .padding(.vertical, compact ? 4 : 5)
      .background(isActive ? accent.opacity(0.24) : accent.opacity(0.07), in: Capsule())
      .overlay(
        Capsule()
          .fill(
            LinearGradient(
              colors: [
                accent.opacity(isActive ? 0.20 : 0.08),
                .white.opacity(isActive ? 0.04 : 0.015),
                .clear
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .shadow(color: .black.opacity(0.035), radius: 1.2, x: 0, y: 1)
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

private func safeUrl(_ rawValue: String) -> URL {
  URL(string: rawValue) ?? URL(string: "chronika://session")!
}

@available(iOSApplicationExtension 16.1, *)
private func shouldShowModes(
  context: ActivityViewContext<LiveActivitiesAppAttributes>,
  prefix: String,
  count: Int
) -> Bool {
  if count <= 0 {
    return false
  }
  if count == 1 {
    let name = value(context, "\(prefix)0Name", "main")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    return name != "main"
  }
  return true
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
