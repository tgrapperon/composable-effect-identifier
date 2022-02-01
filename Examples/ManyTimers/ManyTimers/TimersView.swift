import ComposableArchitecture
import ComposableEffectIdentifier
import LonelyTimer
import SwiftUI

typealias IdentifiedTimer = Identified<Int, TimerState>

struct TimersState {
  var timers: IdentifiedArrayOf<IdentifiedTimer>
}

enum TimersAction {
  case timers(Int, TimerAction)
}

struct TimersEnvironment {
  let mainQueue: AnySchedulerOf<DispatchQueue>
}

let timersReducers = Reducer<TimersState, TimersAction, TimersEnvironment>
  .combine(
    timerReducer
      .forEachNamespaced(
        state: \.timers,
        action: /TimersAction.timers,
        environment: { .init(mainQueue: $0.mainQueue) }
      ),
    Reducer<TimersState, TimersAction, TimersEnvironment> {
      state, action, environment in
      return .none
    }
  )

struct TimersView: View {
  let store: Store<TimersState, TimersAction>

  var body: some View {
    #if os(macOS)
    contentView
    #else
    NavigationView {
      contentView
    }
    #endif
  }
  
  var contentView: some View {
    ScrollView {
      VStack {
        ForEachStore(store.scope(state: \.timers, action: TimersAction.timers)) { store in
          TimerView(store: store.scope(state: \.value))
            .padding(.horizontal)
        }
      }
      .padding(.top)
    }
    .navigationTitle("Many Timers")
  }
}

struct TimersView_Previews: PreviewProvider {
  static let timers = IdentifiedArrayOf<IdentifiedTimer>(
    uniqueElements: (0..<10).map {
      Identified(TimerState(name: "Timer #\($0)", duration: TimeInterval(3 * $0 + 4)), id: $0)
    }
  )

  static var previews: some View {
    TimersView(
      store: .init(
        initialState:
          .init(timers: timers),
        reducer: timersReducers,
        environment: .init(
          mainQueue: .main
        )
      )
    )
  }
}
