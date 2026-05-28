import ActivityKit
import Foundation

enum ChronikaLiveActivityKeys {
  static let appGroupId = "group.app.greenmonster.timereviewer"
  static let pendingCommandsKey = "chronika.pendingLiveActivityCommands"
}

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {
    var appGroupId: String
  }

  var id = UUID()
}
