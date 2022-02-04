import ComposableArchitecture
import ComposableEffectIdentifier
import XCTest

final class ReducerNamespaceTests: XCTestCase {
  struct State: Equatable, Identifiable {
    var id: Int = 0
    var count: Int = 0
  }
  enum Action {
    case start
    case stop
    case tick
  }
  struct Environment {
    var main: AnySchedulerOf<DispatchQueue>
    var documentID: () -> String = { "" }
  }

  let reducer = Reducer<State, Action, Environment> {
    state, action, environment in
    @EffectID var timerID
    switch action {
    case .start:
      return Effect.timer(id: timerID, every: .seconds(1), on: environment.main)
        .map { _ in .tick }
    case .stop:
      return .cancel(id: timerID)
    case .tick:
      state.count += 1
      return .none
    }
  }

  // This test proves the cancellation collision which can happen when not using namespaces
  func testStoresImproperlyNamespaced() {
    let scheduler = DispatchQueue.test
    let store1 = TestStore(
      initialState: .init(),
      reducer: reducer,
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { fatalError() }
      )
    )
    let store2 = TestStore(
      initialState: .init(),
      reducer: reducer,
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { fatalError() }
      )
    )

    store1.send(.start)
    scheduler.advance(by: 1)
    store1.receive(.tick) {
      $0.count = 1
    }

    // The following should stop the ongoing effect from store1, and the test should pass,
    // as no effect will remain unaccounted by the end of the test.
    store2.send(.stop)
  }

  func testStoreNamespacing() {
    let scheduler = DispatchQueue.test
    let store1 = TestStore(
      initialState: .init(),
      reducer: reducer.namespace(1),
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { fatalError() }
      )
    )
    let store2 = TestStore(
      initialState: .init(),
      reducer: reducer.namespace(2),
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { fatalError() }
      )
    )

    store1.send(.start)
    scheduler.advance(by: 1)
    store1.receive(.tick) {
      $0.count = 1
    }

    // This should be effect-less (!):
    store2.send(.stop)

    // store1 should still be ticking:
    scheduler.advance(by: 1)
    store1.receive(.tick) {
      $0.count = 2
    }

    store1.send(.stop)
  }

  func testStoreNamespacingFromState() {
    let scheduler = DispatchQueue.test
    let store1 = TestStore(
      initialState: .init(id: 1),
      reducer: reducer.namespace(\.id),
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { fatalError() }
      )
    )
    let store2 = TestStore(
      initialState: .init(id: 2),
      reducer: reducer.namespace(\.id),
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { fatalError() }
      )
    )

    store1.send(.start)
    scheduler.advance(by: 1)
    store1.receive(.tick) {
      $0.count = 1
    }

    // This should be effect-less (!):
    store2.send(.stop)

    // store1 should still be ticking:
    scheduler.advance(by: 1)
    store1.receive(.tick) {
      $0.count = 2
    }

    store1.send(.stop)
  }

  func testStoreNamespacingFromEnvironment() {
    let scheduler = DispatchQueue.test
    let store1 = TestStore(
      initialState: .init(),
      reducer: reducer.namespace({ $0.documentID() }),
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { "1" }
      )
    )
    let store2 = TestStore(
      initialState: .init(),
      reducer: reducer.namespace({ $0.documentID() }),
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { "2" }
      )
    )

    store1.send(.start)
    scheduler.advance(by: 1)
    store1.receive(.tick) {
      $0.count = 1
    }

    // This should be effect-less (!):
    store2.send(.stop)

    // store1 should still be ticking:
    scheduler.advance(by: 1)
    store1.receive(.tick) {
      $0.count = 2
    }

    store1.send(.stop)
  }

  func testForEachNamespacedIdentifiedArray() {
    let scheduler = DispatchQueue.test

    struct ParentState: Equatable {
      var timers: IdentifiedArrayOf<State>
    }
    enum ParentAction: Equatable {
      case timers(Int, Action)
    }

    let parentReducer = Reducer<ParentState, ParentAction, Environment>.combine(
      reducer.forEachNamespaced(
        state: \ParentState.timers,
        action: /ParentAction.timers,
        environment: { $0 }
      )
    )

    let store = TestStore(
      initialState: .init(
        timers: [
          .init(id: 0, count: 1),
          .init(id: 1, count: 2),
        ]
      ),
      reducer: parentReducer,
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { fatalError() }
      )
    )

    store.send(.timers(1, .start))
    scheduler.advance(by: 1)
    store.receive(.timers(1, .tick)) {
      $0.timers[id: 1]?.count = 3
    }

    // This should be effect-less (!):
    store.send(.timers(0, .stop))

    // timers[id:1] should still be ticking:
    scheduler.advance(by: 1)
    store.receive(.timers(1, .tick)) {
      $0.timers[id: 1]?.count = 4
    }

    store.send(.timers(1, .stop))
  }

  func testForEachNamespacedIdentifiedArrayOfIdentified() {
    let scheduler = DispatchQueue.test

    struct ParentState: Equatable {
      var timers: IdentifiedArrayOf<Identified<Int, State>>
    }
    enum ParentAction: Equatable {
      case timers(Int, Action)
    }

    let parentReducer = Reducer<ParentState, ParentAction, Environment>.combine(
      reducer.forEachNamespaced(
        state: \ParentState.timers,
        action: /ParentAction.timers,
        environment: { $0 }
      )
    )

    let store = TestStore(
      initialState: .init(
        timers: [
          // We reuse reducer and State, but we don't need `State.id`, so we assign -1 for both
          .init(.init(id: -1, count: 1), id: 0),
          .init(.init(id: -1, count: 2), id: 1),
        ]
      ),
      reducer: parentReducer,
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { fatalError() }
      )
    )

    store.send(.timers(1, .start))
    scheduler.advance(by: 1)
    store.receive(.timers(1, .tick)) {
      $0.timers[id: 1]?.count = 3
    }

    // This should be effect-less (!):
    store.send(.timers(0, .stop))

    // timers[id:1] should still be ticking:
    scheduler.advance(by: 1)
    store.receive(.timers(1, .tick)) {
      $0.timers[id: 1]?.count = 4
    }

    store.send(.timers(1, .stop))
  }

  func testForEachNamespacedDictionary() {
    let scheduler = DispatchQueue.test

    struct ParentState: Equatable {
      var timers: [Int: State]
    }
    enum ParentAction: Equatable {
      case timers(Int, Action)
    }

    let parentReducer = Reducer<ParentState, ParentAction, Environment>.combine(
      reducer.forEachNamespaced(
        state: \ParentState.timers,
        action: /ParentAction.timers,
        environment: { $0 }
      )
    )

    let store = TestStore(
      initialState: .init(
        timers: [
          // We reuse reducer and State, but we don't need `State.id`, so we assign -1 for both
          0: .init(id: -1, count: 1),
          1: .init(id: -1, count: 2),
        ]
      ),
      reducer: parentReducer,
      environment: .init(
        main: scheduler.eraseToAnyScheduler(),
        documentID: { fatalError() }
      )
    )

    store.send(.timers(1, .start))
    scheduler.advance(by: 1)
    store.receive(.timers(1, .tick)) {
      $0.timers[1]?.count = 3
    }

    // This should be effect-less (!):
    store.send(.timers(0, .stop))

    // timers[1] should still be ticking:
    scheduler.advance(by: 1)
    store.receive(.timers(1, .tick)) {
      $0.timers[1]?.count = 4
    }

    store.send(.timers(1, .stop))
  }
}
