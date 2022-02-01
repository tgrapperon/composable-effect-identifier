// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "LonelyTimer",
  platforms: [
    .iOS(.v15),
    .macOS(.v12),
    .tvOS(.v15),
    .watchOS(.v8),
  ],
  products: [
    .library(
      name: "LonelyTimer",
      targets: ["LonelyTimer"])
  ],
  dependencies: [
    .package(path: "../../"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.33.1"),
  ],
  targets: [
    .target(
      name: "LonelyTimer",
      dependencies: [
        .product(
          name: "ComposableArchitecture",
          package: "swift-composable-architecture"),
        .product(
          name: "ComposableEffectIdentifier",
          package: "composable-effect-identifier"),
      ])
  ]
)
