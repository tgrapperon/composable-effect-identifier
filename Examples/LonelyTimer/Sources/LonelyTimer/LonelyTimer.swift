import ComposableArchitecture
import ComposableEffectIdentifier
import SwiftUI

public struct TimerState: Hashable, Codable {
  public init(
    name: String,
    duration: TimeInterval,
    position: TimeInterval? = nil,
    state: TimerState.State = .ready
  ) {
    self.name = name
    self.duration = duration
    self.position = position ?? duration
    self.state = state
  }

  public enum State: Hashable, Codable {
    case ready
    case counting
    case finished
  }

  var name: String
  var duration: TimeInterval
  var position: TimeInterval
  var state: State

  var elapsed: TimeInterval {
    duration - position
  }
}

public enum TimerAction {
  case start
  case stop
  case toggle
  case reset
  case tick
  case onAppear
  case onDisappear
}

public struct TimerEnvironment {
  public init(
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.mainQueue = mainQueue
  }

  let mainQueue: AnySchedulerOf<DispatchQueue>
}

public let timerReducer = Reducer<TimerState, TimerAction, TimerEnvironment> {
  state, action, environment in

  @EffectID var timerID

  switch action {
  case .onAppear:
    if state.state == .counting {
      return Effect(value: .start)
    }
    return .none
  case .onDisappear:
    return .cancel(id: timerID)
  case .reset:
    state.position = state.duration
    return Effect(value: .stop)

  case .start:
    state.state = .counting
    return Effect.timer(
      id: timerID,
      every: .seconds(1),
      on: environment.mainQueue
    )
    .map { _ in .tick }

  case .stop:
    state.state = .ready
    return .cancel(id: timerID)

  case .tick:
    state.position -= 1

    if state.position < 1 {
      state.position = 0
      state.state = .finished
      return .cancel(id: timerID)
    }
    return .none

  case .toggle:
    switch state.state {
    case .finished:
      return Effect(value: .reset)
    case .ready:
      return Effect(value: .start)
    case .counting:
      return Effect(value: .stop)
    }
  }
}

public struct TimerView: View {
  let store: Store<TimerState, TimerAction>
  public init(
    store: Store<TimerState, TimerAction>
  ) {
    self.store = store
  }
  public var body: some View {
    WithViewStore(store) { viewStore in
      HStack {

        VStack(alignment: .leading) {
          Text(viewStore.name)
            .bold()
          Text(
            Measurement(value: viewStore.duration, unit: UnitDuration.seconds)
              .formatted(.measurement(width: .wide))
          )
          .monospacedDigit()
        }

        Spacer()

        if viewStore.position != viewStore.duration {
          Button {
            viewStore.send(.reset)
          } label: {
            Image(systemName: "arrow.counterclockwise")

            #if os(macOS)
              .frame(minWidth: 22)
            #else
              .frame(minWidth: 44)
            #endif
          }
          .buttonStyle(.borderless)
          .transition(.move(edge: .trailing).combined(with: .opacity))
        }

        Button {
          viewStore.send(.toggle)
        } label: {
          Image(systemName: viewStore.state.state == .counting ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.borderedProminent)

      }
      .overlay {
        if viewStore.state.state == .finished {
          Button {
            viewStore.send(.reset)
          } label: {
            Text("Done!")
              .bold()
              .blendMode(.destinationOut)

            #if os(macOS)
              .padding(4)
            #else
              .padding(9)
            #endif
            .background {
              RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.accentColor)
            }
            .compositingGroup()
            .rotationEffect(.degrees(-10))
            .transition(.scale)
          }
          .buttonStyle(.plain)
        }
      }
      .background {
        if viewStore.state.state != .finished, viewStore.position != viewStore.duration {
          Circle()
            .trim(from: 0, to: viewStore.elapsed / viewStore.duration)
            .rotation(.degrees(-90))
            .stroke(Color.accentColor, style: .init(lineWidth: 3, lineCap: .round))

            .overlay(
              Text(
                Measurement(value: viewStore.elapsed, unit: UnitDuration.seconds)
                  .formatted(.measurement(width: .narrow))
              )
              .font(Font.system(.callout, design: .rounded).bold())
              .foregroundColor(Color.accentColor)
              .minimumScaleFactor(0.25)
              .lineLimit(1)
              .padding(3)
            )
            .frame(width: 33, height: 33)
            .transition(.scale)
        }
      }
      .animation(.spring(), value: viewStore.position)
      .frame(minWidth: 200)
      .onAppear { viewStore.send(.onAppear) }
      .onDisappear { viewStore.send(.onDisappear) }

    }
  }
}

struct TimerView_Previews: PreviewProvider {
  static var previews: some View {
    TimerView(
      store: .init(
        initialState: .init(
          name: "Timer 1",
          duration: 10,
          position: 4,
          state: .counting
        ),
        reducer: timerReducer,
        environment: .init(
          mainQueue: .main)
      )
    )
    .padding(.horizontal)
  }
}
