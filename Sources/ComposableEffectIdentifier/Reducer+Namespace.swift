import ComposableArchitecture
import SwiftUI
#if DEBUG
  import os
#endif

extension Reducer {
  /// Define an `EffectID` namespace for this reducer and all its descendents.
  ///
  /// Namespaces allow to discern effects emanating from different instances of the same `Store`
  /// type running at the same time in the same process. This can happen with document-based apps
  /// where each document is supported by distinct instances of `Store`, each one without knowledge
  /// of the other ones. Without namespacing, the `Store` for the document "A" may cancel some
  /// ongoing `Effect`s from the document "B" `Store`.
  ///
  /// You ideally define a namespace for the `Reducer` of the root store, using some `Hashable`
  /// value that is unique to the `Store` instance, like a document identifier.
  ///
  /// - Parameter namespace: some `Hashable` value that is unique to the store using this reducer.
  /// - Warning: The namespace should be constant for the lifetime of the store. Otherwise,
  /// `Effect`s may fail to be property cancelled.
  /// - Returns: A reducer that defines a namespace for identifiers defined with the @``EffectID``
  /// property wrapper.
  public func namespace<Namespace: Hashable>(_ namespace: Namespace) -> Self {
    Reducer<State, Action, Environment> { state, action, environment in
      namespacedEffect(
        namespace: namespace,
        state: &state,
        action: action,
        environment: environment
      )
    }
  }

  /// Define an `EffectID` namespace for this reducer and all its descendents using a constant
  /// identifier extracted from `State`.
  ///
  /// Namespaces allow to discern effects emanating from different instances of the same `Store`
  /// type running at the same time in the same process. This can happen with document-based apps
  /// where each document is supported by distinct instances of `Store`, each one without knowledge
  /// of the other ones. Without namespacing, the `Store` for the document "A" may cancel some
  /// ongoing `Effect`s from the document "B" `Store`.
  ///
  /// You ideally define a namespace for the `Reducer` of the root store, using some `Hashable`
  /// value that is unique to the `Store` instance, like a document identifier.
  ///
  /// - Parameter id: some `Hashable` value derived from `State` that is constant and unique to the
  /// store using this reducer. You can use any function, or a `KeyPath<State, ID>`.
  /// - Warning: The identifier should be constant for the lifetime of the store. Otherwise,
  /// `Effect`s may fail to be property cancelled.
  /// - Returns: A reducer that defines a namespace for identifiers defined with the @``EffectID``
  /// property wrapper.
  public func namespace<ID: Hashable>(_ id: @escaping (State) -> ID) -> Self {
    Reducer<State, Action, Environment> { state, action, environment in
      namespacedEffect(
        namespace: id(state),
        state: &state,
        action: action,
        environment: environment
      )
    }
  }

  /// Define an `EffectID` namespace for this reducer and all its descendents using a constant
  /// identifier extracted from the `Environment`.
  ///
  /// Namespaces allow to discern effects emanating from different instances of the same `Store`
  /// type running at the same time in the same process. This can happen with document-based apps
  /// where each document is supported by distinct instances of `Store`, each one without knowledge
  /// of the other ones. Without namespacing, the `Store` for the document "A" may cancel some
  /// ongoing `Effect`s from the document "B" `Store`.
  ///
  /// You ideally define a namespace for the `Reducer` of the root store, using some `Hashable`
  /// value that is unique to the `Store` instance, like a document identifier.
  ///
  /// - Parameter id: some `Hashable` value derived from `Environment` that is constant and unique
  /// to the store using this reducer. You can use any function, or a `KeyPath<Environment, ID>`.
  /// - Warning: The identifier should be constant for the lifetime of the store. Otherwise,
  /// `Effect`s may fail to be property cancelled.
  /// - Returns: A reducer that defines a namespace for identifiers defined with the @``EffectID``
  /// property wrapper.
  public func namespace<ID: Hashable>(_ id: @escaping (Environment) -> ID) -> Self {
    Reducer<State, Action, Environment> { state, action, environment in
      namespacedEffect(
        namespace: id(environment),
        state: &state,
        action: action,
        environment: environment
      )
    }
  }

  func namespacedEffect<Namespace: Hashable>(
    namespace: Namespace,
    state: inout State,
    action: Action,
    environment: Environment
  ) -> Effect<Action, Never> {
    if Thread.isMainThread {
      mainThreadCurrentEffectIDNamespace.push(namespace)
      defer { mainThreadCurrentEffectIDNamespace.pop() }
      return self.run(&state, action, environment)
    } else {
      return currentEffectIDNamespaceLock.sync {
        currentEffectIDNamespace.push(namespace)
        defer { currentEffectIDNamespace.pop() }
        return self.run(&state, action, environment)
      }
    }
  }
}

extension Reducer {
  /// A version of ``pullback(state:action:environment:)`` that transforms a reducer that works on
  /// an element into one that works on an identified array of elements.
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
    state toLocalState: WritableKeyPath<GlobalState, IdentifiedArray<ID, State>>,
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
          &globalState[keyPath: toLocalState][id: id]!,
          localAction,
          toLocalEnvironment(globalEnvironment)
        )
        .map { toLocalAction.embed((id, $0)) }
    }
  }
  
  /// A version of ``pullback(state:action:environment:)`` that transforms a reducer that works on
  /// an element into one namespaced reducer that works on a dictionary of element values.
  ///
  /// The dictionary's key is used to namespace the element's reducer.
  ///
  /// Take care when combining ``forEachNamespaced(state:action:environment:file:line:)``
  /// reducers into parent domains, as order matters. Always combine
  /// ``forEachNamespaced(state:action:environment:file:line:)`` reducers _before_ parent reducers
  /// that can modify the dictionary.
  ///
  /// - Parameters:
  ///   - toLocalState: A key path that can get/set a dictionary of `State` values inside
  ///     `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `(Key, Action)` from `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  public func forEachNamespaced<GlobalState, GlobalAction, GlobalEnvironment, Key>(
    state toLocalState: WritableKeyPath<GlobalState, [Key: State]>,
    action toLocalAction: CasePath<GlobalAction, (Key, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (key, localAction) = toLocalAction.extract(from: globalAction) else { return .none }

      if globalState[keyPath: toLocalState][key] == nil {
        #if DEBUG
          os_log(
            .fault, dso: rw.dso, log: rw.log,
            """
            A "forEach" reducer at "%@:%d" received an action when state contained no value at \
            that key. …

              Action:
                %@
              Key:
                %@

            This is generally considered an application logic error, and can happen for a few \
            reasons:

            • This "forEach" reducer was combined with or run from another reducer that removed \
            the element at this key when it handled this action. To fix this make sure that this \
            "forEach" reducer is run before any other reducers that can move or remove elements \
            from state. This ensures that "forEach" reducers can handle their actions for the \
            element at the intended key.

            • An in-flight effect emitted this action while state contained no element at this \
            key. It may be perfectly reasonable to ignore this action, but you also may want to \
            cancel the effect it originated from when removing a value from the dictionary, \
            especially if it is a long-living effect.

            • This action was sent to the store while its state contained no element at this \
            key. To fix this make sure that actions for this reducer can only be sent to a view \
            store when its state contains an element at this key.
            """,
            "\(file)",
            line,
            debugCaseOutput(localAction),
            "\(key)"
          )
        #endif
        return .none
      }
      return self
        .namespace(key)
        .run(
        &globalState[keyPath: toLocalState][key]!,
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map { toLocalAction.embed((key, $0)) }
    }
  }
}




