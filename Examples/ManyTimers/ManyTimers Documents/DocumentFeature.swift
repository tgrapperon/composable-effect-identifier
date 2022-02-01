import ComposableArchitecture
import LonelyTimer
import SwiftUI

enum DocumentAction<State, Action> {
  case action(Action)
  case stateDidChange(State)
}

extension Reducer {
  func document<DocumentType>(
    file: FileDocumentConfiguration<DocumentType>
  ) -> Reducer<
    State,
    DocumentAction<State, Action>,
    Environment
  > where DocumentType: FileDocument {
    Reducer<State, DocumentAction<State, Action>, Environment>
      .combine(
        pullback(state: \.self, action: /DocumentAction.action, environment: { $0 }),
        Reducer<
          State, DocumentAction<State, Action>, Environment
        > { state, action, environment in
          switch action {
          case .action:
            return .none
          case let .stateDidChange(newValue):
            state = newValue
            return .none
          }
        }
      )
  }
}

struct DocumentView: View {
  let file: FileDocumentConfiguration<ManyTimersDocument>
  let store: Store<IdentifiedTimer, DocumentAction<IdentifiedTimer, TimerAction>>
  init(
    file: FileDocumentConfiguration<ManyTimersDocument>,
    store: Store<IdentifiedTimer, DocumentAction<IdentifiedTimer, TimerAction>>
  ) {
    self.file = file
    self.store = store
  }

  var body: some View {
    TimerView(store: store.scope(state: \.value, action: DocumentAction.action))
      .background(
        WithViewStore(store) { viewStore in
          Color.clear
            .onChange(of: file.document.identifiedTimer) { viewStore.send(.stateDidChange($0)) }
            .onChange(of: viewStore.state) { file.document.identifiedTimer = $0 }
        }
      )
      .padding()
      .frame(minWidth: 250, minHeight: 100)
  }
}
