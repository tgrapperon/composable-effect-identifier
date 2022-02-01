import ComposableArchitecture
import ComposableEffectIdentifier
import LonelyTimer
import SwiftUI

var stores: [AnyHashable: Store<IdentifiedTimer, DocumentAction<IdentifiedTimer, TimerAction>>] =
  [:]
func _store(
  for file: FileDocumentConfiguration<ManyTimersDocument>
)
  -> Store<IdentifiedTimer, DocumentAction<IdentifiedTimer, TimerAction>>
{
  if let store = stores[file.documentID] {
    return store
  }
  let documentID = file.documentID
  let store = Store(
    initialState: file.document.identifiedTimer,
    reducer:
      identifiedTimerReducer  // A `timerReducer` that can work transparently on `Identified<TimerState, UUID>` states
      .document(file: file)  // This synchronizes `file.document.identifiedTimer` with `State`'s value
      .namespace(documentID),  // This defines a namespace for the whole document.
    // ^ Namespacing is mandatory for this document-based app. If you comment the line above and
    // open several documents, you can see that if starting the timer in one document cancels any
    // ongoing timer in other documents. With namespacing, all document are behaving correctly in
    // isolation, an multiple timers can run at the same time and be cancelled independently.
    environment:
      .init(
        mainQueue: .main
      )
  )
  stores[documentID] = store
  return store
}

// Makes `timerReducer` work transparently on `IdentifierTimer`'s state.
let identifiedTimerReducer = Reducer<IdentifiedTimer, TimerAction, TimerEnvironment> {
  timerReducer.run(&$0.value, $1, $2)
}

@main
struct ManyTimers_DocumentApp: App {
  var body: some Scene {
    DocumentGroup(
      newDocument:
        ManyTimersDocument(
          timer: .init(
            name: "A Timer",
            duration: TimeInterval(Int.random(in: 4...60))
          ),
          id: UUID())
    ) { file in
      DocumentView(file: file, store: _store(for: file))
    }
  }
}

extension FileDocumentConfiguration where Document == ManyTimersDocument {
  var documentID: AnyHashable {
    if let url = fileURL { return url }
    return document.identifiedTimer.id
  }
}
