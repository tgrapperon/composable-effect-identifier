# Composable Effect Identifier
[![Swift](https://github.com/tgrapperon/composable-effect-identifier/actions/workflows/swift.yml/badge.svg?branch=main)](https://github.com/tgrapperon/composable-effect-identifier/actions/workflows/swift.yml)
[![Documentation](https://github.com/tgrapperon/composable-effect-identifier/actions/workflows/documentation.yml/badge.svg)](https://github.com/tgrapperon/composable-effect-identifier/actions/workflows/documentation.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftgrapperon%2Fcomposable-effect-identifier%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/tgrapperon/composable-effect-identifier)

This `ComposableEffectIdentifier` is a small accessory library to [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA). It allows to improve user experience when defining `Effect` identifiers.

It provides two tools to this end: a `@EffectID` property wrapper, and a `namespace()` higher order reducer that allows several similar stores instances to run in the same process without having to micro-manage ongoing `Effect` identifiers.

### The `@EffectID` property wrapper.
When using TCA with long-lived effects, we need to provide some hashable value to identify them accross runs of the same reducer. If we start a `timer` effect, we need to provide an identifier for the effect in order to retrieve the effect and cancel it when we don't need it anymore.

Any `Hashable` value can be used as effect identifier. The authors of TCA are recommending to exploit Swift type system by defining ad hoc local and property-less `Hashable` structs. Any value of this struct is equal to itself, and collisions risks are limited, as these types are defined locally.

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
With its current implementation, the core TCA library can be inconvenient to use in certain configurations, especially when developing document-based apps for example. In this kind of apps, each document is represented by a root `Store`. Each document should be unware of the existence of other documents opened at the same time. In such an app, many instances of the same type of root `Store` may run at the same time in the same process. When using local identifiers like `Hashable` structs in reducers to identify effects, one may create collisions, where one store instance may cancel an effect originating from another store (because ongoing effects are internally stored in a common, top-level, dictionary). 

One solution would be to propagate some document-specific identifier in the `State` or the `Environment`, but this would require to append this identifier to **every** effect identifier in order to work properly. Furthermore, "leaking" such an identifier in every unrelated feature impedes feature isolation and reusability (a TCA core principle).

In the same spirit, composing a collection of features with ongoing effects is cumbersome too, as we need to inject some element-specific identifier to discern similar effects originating from different rows. Usually, row features are relatively simple, so the pervasion of the row's identifier is less perceptible, but it's still there, where the row feature should ultimately work in some list-agnostic context.

Fortunately, `ComposableEffectIdentifier` ships with a feature that helps greatly to solve this kind of issue. It works in conjunction with and requires the use of the `@EffectID` property wrapper to declare effect identifiers. Any `Reducer` can be _namespaced_ with some `Hashable` value. This value is used to augment `@EffectID` identifiers with contextual data (you can see it like a user-provided value, but coming "from the top"). Namespaces are propagated downstream along the `Reducer`'s tree, and they compose with deaper namespaces.

#### Reducer namespaces
You namespace a reducer using the `.namespace<ID>(_ id: ID)` higher order reducer, which doesn't change the generic signature of the source `Reducer`. The `id` can be provided directly, or as a function or `KeyPath` from `State` or `Environment`. The `id` value should be constant for the branch, during all the execution of the program. For document-based app, you will most likely namespace the root-reducer with some stable value that identify uniquely the document.

#### Automatic namespaces
Two semi-overloads of the `forEach` pullback are provided. They are both named `forEachNamespace`, but they share the same arguments as their `forEach` counterparts otherwise. These reducers are working like `forEach`, but they're also namespacing their local reducers using the element's identifier (or dictionary key), thereby siloing the effects of each pulled-back reducer. For this reason, these local reducers can define their effect identifiers using the `@EffectID` property wrapper in isolation, without having to carry an external identifier.

#### `Identified` states
TCA already ships with an `Identified` wrapper that can wrap any value into an `Identifiable` value. The use of `@EffectID` leads to features that are becoming more and more agnostic of an external identifier. Because of this, it can be convenient to wrap the `State` of an identifier-less feature with the `Identified` wrapper, for example to include-it into an `IdentifiedArrayOf<Identified<State, ID>>`. As wrapping the feature to make it identifiable may be the only outcome of the procedure, an overload of `forEachNamespace` is also provided to directly pull-back, namespace, and identify an identifier-less reducer in one call. This overload is available when the `GlobalState` is `IdentifiedArrayOf<Identified<LocalState, ID>>`, and the identifier-less reducer works on `LocalState`.

### Example app
In order to demonstrate the power the namespaced reducers and `@EffectID` property wrappers, the library ships with an example app that pulls a neat trick: A `LonelyTimer` TCA feature is implemented. This feature handles a timer that count backward down to zero, with some start/stop functions. The `LonelyTimer` feature is unaware of the outer world. It handles its count, and that's it. It doesn't have an identifier itself. It has a name, but only by courtesy.

Around this `LonelyTimer` feature, an app called `ManyTimers` is built. This app handles an arbitrary number of timers, but without touching the code of `LonelyTimer`. The `ManyTimers` app furthermore ships in 4 flavors: an shoebox app, where a dozen of timers are hosted in a list at the same time, for iOS and macOS, and a document-based app, where each file handles one timer, again for iOS and macOS. The document based app can have several files opened at the same time, which is in some way similar as hosting them side to side in a list.

With both apps, several timers can run and be interacted with at the same time, each in isolation. Only one effect identifier is defined, at the `LonelyTimer` level.

## Documentation
The latest documentation for `ComposableEffectIdentifier`'s APIs is available [here](https://github.com/tgrapperon/composable-effect-identifier/wiki).

## Installation
Add 
```swift
.package(url: "https://github.com/tgrapperon/composable-effect-identifier", from: "0.0.1")
```
to your Package dependencies in `Package.swift`, and then
```swift
.product(name: "ComposableEffectIdentifier", package: "composable-effect-identifier")
```
to your target's dependencies.

## Credits and thanks
The author ([@tgrapperon](https://github.com/tgrapperon)) would like to especially thank [@iampatbrown](https://github.com/iampatbrown) who gave the initial feedback that allowed to shape this library, and of course [@mbrandonw](https://github.com/mbrandonw) and [@stephencelis](https://github.com/stephencelis) for the incredible work they put though TCA and their other amazing open-source projects.

## License

This library is released under the MIT license. See [LICENSE](https://github.com/tgrapperon/composable-effect-identifier/blob/main/LICENSE) for details.
