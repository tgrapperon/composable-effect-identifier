import ComposableArchitecture
import LonelyTimer
import SwiftUI

let timers = IdentifiedArrayOf<IdentifiedTimer>(
  uniqueElements: (0..<10).map {
    Identified(TimerState(name: "Timer #\($0)", duration: TimeInterval(3 * $0 + 4)), id: $0)
  }
)

let store = Store(
  initialState: .init(
    timers: timers
  ),
  reducer: timersReducers,
  environment: .init(
    mainQueue: .main
  )
)

@main
struct ManyTimersApp: App {
  var body: some Scene {
    WindowGroup {
      TimersView(store: store)
    }
  }
}
