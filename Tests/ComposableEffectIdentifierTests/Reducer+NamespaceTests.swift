import ComposableArchitecture
import ComposableEffectIdentifier
import XCTest

final class ReducerNamespaceTests: XCTestCase {
  struct State: Equatable {
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
}
