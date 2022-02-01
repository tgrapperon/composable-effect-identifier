# Composable Effect Identifier

This `ComposableEffectIdentifier` is a small accessory library to [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA). It allows to improve user experience when defining `Effect` identifiers.

It provides two tools to this end: a `@EffectID` property wrapper, and a `namespace()` higher order reducer that allows several similar stores instances to run in the same process without having to micro-manage ongoing `Effect` identifiers.

## The `@EffectID` property wrapper.
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

