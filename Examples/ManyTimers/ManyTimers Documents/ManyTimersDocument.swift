import ComposableArchitecture
import LonelyTimer
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
  static var timer: UTType {
    UTType(exportedAs: "composable.effect.identifier-many.timers.timer", conformingTo: .json)
  }
}

typealias IdentifiedTimer = Identified<UUID, TimerState>

// WARNING: It is bad practice to rely on `Codable` to serialize your documents. It is especially
// bad when versions from the past are editing new versions of the document, as it may lead to data
// losses. You should at least store a version identifier to prevent writes "from the past" if you
// still opt to use `Codable`. It is used directly here for presentation purposes.
struct ManyTimersDocument: FileDocument {
  var identifiedTimer: IdentifiedTimer

  init(
    timer: TimerState, id: UUID
  ) {
    self.identifiedTimer = .init(timer, id: id)
  }

  static var readableContentTypes: [UTType] { [.timer] }

  init(
    configuration: ReadConfiguration
  ) throws {
    guard let data = configuration.file.regularFileContents,
      let identifiedTimer = try? JSONDecoder().decode(IdentifiedTimer.self, from: data)
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    self.identifiedTimer = identifiedTimer
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let data = try JSONEncoder().encode(identifiedTimer)
    return .init(regularFileWithContents: data)
  }
}
