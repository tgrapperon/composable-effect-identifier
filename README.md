# Composable Effect Identifier

This `ComposableEffectIdentifier` is a small accessory library to [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA). It allows to improve user experience when defining `Effect` identifiers.

It provides two tools to this end: a `@EffectID` property wrapper, and a `namespace()` higher order reducer that allows several similar stores instances to run in the same process without having to micro-manage ongoing `Effect` identifiers.

### The `@EffectID` property wrapper.
When using TCA with long-lived effects, we need to provide some hashable value to identify them accross runs of the same reducer. If we start a `timer` effect, we need to provide an identifier for the effect in order to retrieve the effect and cancel it when we don't need it anymore.

Any `Hashable` value can be used as effect identifier. The authors of the library are recommending to exploit Swift type system by defining ad hoc local and property-less `Hashable` structs. Any instance of this struct is equal to itself, and collisions risks are limited, as these types are defined locally.

For example, inside some `Reducer`'s block, one can define:
```swift
struct TimerID: Hashable {}
```
We can then use any value of this type as an effect idenfier:
```swift
switch action {
  case .start:
    return Effect.timer(id: TimerId(), every: 1, on: environment.mainQueue)
      .map { _ in .tick }
      
  case .stop:
    return .cancel(id: TimerID())
   
  case .tick:
    state.count += 1
    return .none
}
```

This works well. Calling `TimerID()` and creating a whole type when we simply need an `Hashable` value feels a little awkward though.

The `@EffectID` property wrapper allows to define indentifiers with an absolutely clear intent:
```swift
@EffectID var timerID
```
Accessing this value returns a unique and stable `Hashable` value that can be used to identify effects:
```swift
switch action {
  case .start:
    return Effect.timer(id: timerID, every: 1, on: environment.mainQueue)
      .map { _ in .tick }
      
  case .stop:
    return .cancel(id: timerID)
   
  case .tick:
    state.count += 1
    return .none
}
```

In order to be defined locally into some reducer, Swift >=5.4 is required (more precisely Swift >=5.5, as there is a bug with value-less local property wrappers in Swift 5.4).

By assigning some `Hashable` value to the property, you can augment the generated identifier with additional data:
```swift
@EffectID var timerID = state.identifier
```
Please note that `@EffectID` sharing the same user-defined value will not be equal if defined in difference places:
```swift
@EffectID var id1 = "A"
@EffectID var id2 = "A"
// => id1 != id2
```
The use of user-defined values can be even avoided most of the time when using _namespaces_.

### Namespaces
With its current implementation, the core TCA library can be inconvenient to use in certain configurations, especially when developing document-based apps for example. In this kind of apps, each document is represented by a root `Store`. Each document should be unware of the existence of other documents opened at the same time. In such an app, many instances of the same type of root `Store` may run at the same time in the same process. When using local identifiers like `Hashable` structs in reducers to identify effects, one may create collisions, where one store instance may cancel an effect originating from another store (because ongoing effects are internally stored in a common, top-level, dictionary). One solution would be to propagate some document specific identifier in the `State` or the `Environment`, but it would require to append this identifier to **every** effect identifier in order to work property.


### Example app
In order to demonstrate the power the namespaced reducers and `@EffectID` property wrappers, the library ships with an example app that pulls a neat trick: A `LonelyTimer` TCA feature is implemented. This feature handles a timer that count backward down to zero, with some start/stop functions. The `LonelyTimer` feature is unaware of the outer world. It handle its count, and that's it. It doesn't have an identifier itself. It has a name, but only by courtesy.

Around this `LonelyTimer` feature, an app called `ManyTimers` is built. This app handles an arbitrary number of timers, but without touching the code of `LonelyTimer`. The `ManyTimers` app furthermore ships in 4 flavors: an shoebox app, where a dozen of timers are hosted in a list at the same time, for iOS and macOS, and a document-based app, where each file handles one timer, again for iOS and macOS. The document based app can have several files opened at the same time, which is in some way similar as hosting them side to side in a list.

With both apps, several timers can run and be interacted with at the same time, each in isolation. Only one effect identifier is defined, at the `LonelyTimer` level.





