import ComposableArchitecture

#if DEBUG
  import os
#endif

extension Reducer {
  /// A version of ``pullback(state:action:environment:)`` that transforms a reducer that works on
  /// an element into one namespaced reducer that works on an identified array of elements wrapped
  /// in ``Identified``s.
  ///
  /// The wrapper's ``Identified/id`` is used to namespace the element's reducer.
  ///
  /// ```swift
  /// // Global domain that holds a collection of local domains:
  /// struct AppState { var todos: IdentifiedArrayOf<Todo> }
  /// enum AppAction { case todo(id: Todo.ID, action: TodoAction) }
  /// struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
  ///
  /// // A reducer that works on a local domain:
  /// let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { ... }
  ///
  /// // Pullback the local todo reducer so that it works on all of the app domain:
  /// let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  ///   todoReducer.forEach(
  ///     state: \.todos,
  ///     action: /AppAction.todo(id:action:),
  ///     environment: { _ in TodoEnvironment() }
  ///   ),
  ///   Reducer { state, action, environment in
  ///     ...
  ///   }
  /// )
  /// ```
  ///
  /// Take care when combining ``forEach(state:action:environment:file:line:)-gvte`` reducers into
  /// parent domains, as order matters. Always combine
  /// ``forEach(state:action:environment:file:line:)-gvte`` reducers _before_ parent reducers that
  /// can modify the collection.
  ///
  /// - Parameters:
  ///   - toLocalState: A key path that can get/set a collection of `State` elements inside
  ///     `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `(Collection.Index, Action)` from
  ///     `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  public func forEachNamespaced<GlobalState, GlobalAction, GlobalEnvironment, ID>(
    state toLocalState: WritableKeyPath<
      GlobalState, IdentifiedArrayOf<Identified<ID, State>>
    >,
    action toLocalAction: CasePath<GlobalAction, (ID, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (id, localAction) = toLocalAction.extract(from: globalAction) else { return .none }
      if globalState[keyPath: toLocalState][id: id] == nil {
        #if DEBUG
          os_log(
            .fault, dso: rw.dso, log: rw.log,
            """
            A "forEach" reducer at "%@:%d" received an action when state contained no element with \
            that id. …

              Action:
                %@
              ID:
                %@

            This is generally considered an application logic error, and can happen for a few \
            reasons:

            • This "forEach" reducer was combined with or run from another reducer that removed \
            the element at this id when it handled this action. To fix this make sure that this \
            "forEach" reducer is run before any other reducers that can move or remove elements \
            from state. This ensures that "forEach" reducers can handle their actions for the \
            element at the intended id.

            • An in-flight effect emitted this action while state contained no element at this id. \
            It may be perfectly reasonable to ignore this action, but you also may want to cancel \
            the effect it originated from when removing an element from the identified array, \
            especially if it is a long-living effect.

            • This action was sent to the store while its state contained no element at this id. \
            To fix this make sure that actions for this reducer can only be sent to a view store \
            when its state contains an element at this id. In SwiftUI applications, use \
            "ForEachStore".
            """,
            "\(file)",
            line,
            debugCaseOutput(localAction),
            "\(id)"
          )
        #endif
        return .none
      }
      return
        self
        .namespace(id)
        .run(
          &globalState[keyPath: toLocalState][id: id]!.value,
          localAction,
          toLocalEnvironment(globalEnvironment)
        )
        .map { toLocalAction.embed((id, $0)) }
    }
  }
}
