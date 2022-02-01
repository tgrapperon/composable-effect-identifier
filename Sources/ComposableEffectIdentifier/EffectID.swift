import Foundation

#if DEBUG
  import os
#endif
/// A property wrapper that generates a hashable value suitable to identify ``Effect``'s.
///
/// These identifiers can be bound to the root ``Store`` executing the ``Reducer`` that produces
/// the ``Effect``'s. This can be conveniently exploited in document-based apps for example, where
/// you may have multiple documents and by extension, multiple root ``Store``'s coexisting in the
/// same process.
///
/// In order to bind the identifiers to a store, you need to namespace their root reducer using the
/// ``Reducer.namespace()`` methods. You don't need to declare a namespace if you're using only one
/// instance of a root store in your application.
///
/// The value returned when accessing a property wrapped with this type is an opaque hashable value
/// that is constant across ``Reducer``'s runs, and which can be used to identify long-running or
/// cancellable effects:
/// ``` swift
/// Reducer<State, Action, Environment> { state, action, environment in
///  @EffectID var timerID
///  switch action {
///  case .onAppear:
///   return
///     .timer(id: timerID, every: 1, on: environment.mainQueue)
///     .map { _ in Action.timerTick }
///  case .onDisappear:
///   return .cancel(id: timerID)
///  case .timerTick:
///   state.ticks += 1
///   return .none
///  }
/// }
/// ```
///
/// These property wrappers can be used without arguments, but you can also provide some contextual
/// data to parametrize them:
///
/// ``` swift
/// Reducer<State, Action, Environment> { state, action, environment in
///  @EffectID var timerID = state.timerID
///  …
/// }
/// ```
///
/// If you want to share an ``EffectID`` across reducers, you should define it as a property in any
/// shared type. You can even use the ``EffectID`` type itself to declare a shared identifier:
/// ```swift
/// extension EffectID {
///   @EffectID public static var sharedID
/// }
/// // And access it as inside reducers as:
/// EffectID.sharedID
/// ```
///
/// - Warning: This property wrapper is context-specific. Two identifiers defined in different
/// locations are always different, even if they share the same user data:
/// ``` swift
/// Reducer<State, Action, Environment> { _, _, _ in
///  @EffectID var id1 = "A"
///  @EffectID var id2 = "A"
///  // => id1 != id2
/// }
/// ```
/// Two identifiers are equal iff they are defined at the same place, and with the same contextual
/// data (if any).
///
/// - Warning: When using namespaces, this property wrapper should only be used within some
/// ``Reducer``'s context, that is, when reducing some action. Failing to do so when using
/// namespaces raises a runtime warning when comparing two identifiers. The value can be defined in
/// any spot allowing property wrappers, but it should only be accessed from some ``Reducer``
/// execution block.
/// When only one, non-namespaced, store is used, these properties can be defined and accessed
/// everywhere.
@propertyWrapper
public struct EffectID: Hashable {
  private static var currentNamespace: EffectNamespace {
    if Thread.isMainThread {
      return mainThreadCurrentEffectIDNamespace
    } else {
      return currentEffectIDNamespaceLock.sync {
        currentEffectIDNamespace
      }
    }
  }

  private let value: Value

  public var wrappedValue: Value {
    value.with(namespace: Self.currentNamespace)
  }

  /// Initialize an ``EffectID`` carrying some user-defined payload.
  ///
  /// The ``EffectID.Value`` returned when accessing this property is as unique and stable as the
  /// value provided. You can assign a value when you want to parametrize the identifier with some
  /// `State`-dependant value for example:
  /// ```swift
  /// let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
  ///   @EffectID var timerId = state.timerID
  ///
  ///   switch action {
  ///   case .startButtonTapped:
  ///     return Effect.timer(id: timerId, every: 1, on: env.mainQueue)
  ///       .map { _ in .timerTicked }
  ///
  ///   case .stopButtonTapped:
  ///     return .cancel(id: timerId)
  ///
  ///   case let .timerTicked:
  ///     state.count += 1
  ///     return .none
  /// }
  /// ```
  /// - Warning: Two @``EffectID``'s defined at different places will always be different, even if
  /// they share the same user-defined value:
  /// ```swift
  /// @EffectID var id1 = "A"
  /// @EffectID var id2 = "A"
  /// // => id1 != id2
  /// ```
  public init<UserData>(
    wrappedValue: UserData,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) where UserData: Hashable {
    value = .init(
      userData: wrappedValue,
      file: file,
      line: line,
      column: column
    )
  }

  /// Initialize an ``EffectID`` that returns a unique and stable ``EffectID.Value`` when accessed.
  ///
  /// You don't need to provide any value:
  /// ```swift
  /// let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
  ///   @EffectID var timerId
  ///
  ///   switch action {
  ///   case .startButtonTapped:
  ///     return Effect.timer(id: timerId, every: 1, on: env.mainQueue)
  ///       .map { _ in .timerTicked }
  ///
  ///   case .stopButtonTapped:
  ///     return .cancel(id: timerId)
  ///
  ///   case let .timerTicked:
  ///     state.count += 1
  ///     return .none
  /// }
  public init(
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) {
    value = .init(
      file: file,
      line: line,
      column: column
    )
  }
}

extension EffectID {
  public struct Value: Hashable {
    var namespace: AnyHashable?
    let userData: AnyHashable?
    let file: String
    let line: UInt
    let column: UInt

    internal init(
      effectIDNamespace: AnyHashable? = nil,
      userData: AnyHashable? = nil,
      file: StaticString,
      line: UInt,
      column: UInt
    ) {
      self.namespace = effectIDNamespace
      self.userData = userData
      self.file = "\(file)"
      self.line = line
      self.column = column
    }

    func with(namespace: AnyHashable?) -> Self {
      var identifier = self
      identifier.namespace = namespace
      return identifier
    }

    public static func == (lhs: Value, rhs: Value) -> Bool {
      #if DEBUG
        // Don't generate warning for SwiftUI Previews
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
          if lhs.namespace == nil || rhs.namespace == nil {
            func issueWarningIfNeeded(id: Value) {
              guard id.namespace == nil else { return }

              let namespace: AnyHashable?
              if Thread.isMainThread {
                namespace = mainThreadCurrentEffectIDNamespace
              } else {
                namespace = currentEffectIDNamespaceLock.sync {
                  currentEffectIDNamespace
                }
              }
              // To avoid runtime warnings in innocuous single-store cases, we only warn the user
              // when some namespace is defined, but the `EffectID.Value` is bearing none, meaning
              // the property wrapper was accessed outside of a `Reducer`'s scope (as we are probably
              // equating this value when trying to cancel an effect).
              // We don't warn if no namespace is defined, as it's only required in specific cases
              // like document-based apps. For this reason, most users can use the `EffectID`
              // property wrapper directly, without namespacing their `Reducer`s.
              guard namespace != nil else { return }

              let warningID = WarningID(file: id.file, line: id.line, column: id.column)
              guard
                Self.issuedWarningsLock.sync(work: {
                  guard !issuedWarnings.contains(warningID) else { return false }
                  issuedWarnings.insert(warningID)
                  return true
                })
              else { return }
              os_log(
                .fault, dso: rw.dso, log: rw.log,
                """
                An `@EffectID` declared at "%@:%d" was accessed outside of a reducer's context.

                `@EffectID` identifiers should only be accessed by `Reducer`'s while they're \
                receiving an action.
                """,
                "\(id.file)",
                id.line
              )
            }
            issueWarningIfNeeded(id: lhs)
            issueWarningIfNeeded(id: rhs)
          }
        }
      #endif
      guard
        lhs.file == rhs.file,
        lhs.line == rhs.line,
        lhs.column == rhs.column,
        lhs.namespace == rhs.namespace,
        lhs.userData == rhs.userData
      else {
        return false
      }
      return true
    }

    #if DEBUG
      static var issuedWarningsLock = NSRecursiveLock()
      static var issuedWarnings = Set<WarningID>()
      struct WarningID: Hashable {
        let file: String
        let line: UInt
        let column: UInt
      }
    #endif
  }
}

let currentEffectIDNamespaceLock = NSRecursiveLock()
var currentEffectIDNamespace = EffectNamespace()
var mainThreadCurrentEffectIDNamespace = EffectNamespace()

struct EffectNamespace: Hashable {
  var components: [AnyHashable] = []
  mutating func push(_ component: AnyHashable) {
    components.append(component)
  }
  mutating func pop() {
    components.removeLast()
  }
}
