import XCTest

@testable import ComposableEffectIdentifier

final class EffectIDTests: XCTestCase {
  @EffectID var id1
  @EffectID var id2_1 = 1
  @EffectID var id2_2 = 1

  func testEffectIdentifierEquality() {
    XCTAssertEqual(id1, id1)
    XCTAssertEqual(id2_1, id2_1)
    XCTAssertEqual(id2_2, id2_2)

    XCTAssertNotEqual(id1, id2_1)
    XCTAssertNotEqual(id1, id2_2)
    XCTAssertNotEqual(id2_1, id2_2)
  }

  #if compiler(>=5.5)
    func testLocalEffectIdentifierEquality() {
      @EffectID var id1
      @EffectID var id2_1 = 1
      @EffectID var id2_2 = 1

      XCTAssertEqual(id1, id1)
      XCTAssertEqual(id2_1, id2_1)
      XCTAssertEqual(id2_2, id2_2)

      XCTAssertNotEqual(id1, id2_1)
      XCTAssertNotEqual(id1, id2_2)
      XCTAssertNotEqual(id2_1, id2_2)

      XCTAssertNotEqual(id1, self.id1)
    }
  #endif
}
