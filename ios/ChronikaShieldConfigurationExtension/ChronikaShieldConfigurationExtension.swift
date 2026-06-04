import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ChronikaShieldConfigurationExtension: ShieldConfigurationDataSource {
  private let defaults = UserDefaults(suiteName: "group.app.greenmonster.timereviewer") ?? .standard
  private let lastBlockedAppNameKey = "chronika_screen_time_last_blocked_app_name"

  override func configuration(shielding application: Application) -> ShieldConfiguration {
    saveLastBlockedName(application.localizedDisplayName ?? "Selected app")
    return configuration()
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    saveLastBlockedName(application.localizedDisplayName ?? "Selected app")
    return configuration()
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    saveLastBlockedName(webDomain.domain ?? "Selected website")
    return configuration()
  }

  override func configuration(
    shielding webDomain: WebDomain,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    saveLastBlockedName(webDomain.domain ?? "Selected website")
    return configuration()
  }

  private func saveLastBlockedName(_ name: String) {
    defaults.set(name, forKey: lastBlockedAppNameKey)
    defaults.synchronize()
  }

  private func configuration() -> ShieldConfiguration {
    ShieldConfiguration(
      backgroundBlurStyle: .systemUltraThinMaterialDark,
      backgroundColor: UIColor(red: 0.03, green: 0.05, blue: 0.09, alpha: 1.0),
      icon: UIImage(systemName: "shield.fill"),
      title: ShieldConfiguration.Label(
        text: "Protected by Chronika",
        color: .white
      ),
      subtitle: ShieldConfiguration.Label(
        text: "This app is blocked right now. Open Chronika, go to Focus Apps, pause for a breath, then choose a short unlock if you need it.",
        color: UIColor.white.withAlphaComponent(0.72)
      )
    )
  }
}
