//
//  InvalidItemNotifierTests.swift
//  JSONUtilities
//
//  Created by Yonas Kolb on 28/4/17.
//  Copyright © 2017 Luciano Marisi. All rights reserved.
//

import XCTest
@testable import JSONUtilities

class InvalidItemNotifierTests: XCTestCase {

  let key = "key"

  let dictionaryString = [
    "key": [
      "key1": "value1",
      "key2": 2
    ]
  ]

  let arrayString = [
    "key": [
      "value1",
      2
    ]
  ]

  class InvalidItemBehaviourHandler {
    var events: [InvalidItemNotifier.Event] = []

    func handle(event: InvalidItemNotifier.Event) {
      events.append(event)
    }
  }

  func test_invalidItemBehaviourNotifier_sendsRemoved_onRemove() {
    let handler = InvalidItemBehaviourHandler()
    _ = InvalidItemNotifier.addListener(handler: handler.handle)
    expectNoError {
      let _: [String] = try arrayString.json(atKeyPath: key, invalidItemBehaviour: .remove)
      XCTAssertTrue(handler.events.count == 1)
      XCTAssertTrue(handler.events.first?.action == .removed)
      XCTAssertTrue(handler.events.first?.action != .failed)
      let error = handler.events.first?.error
      XCTAssertTrue(error?.reason == DecodingError.Reason.incorrectType)
      XCTAssertTrue(error?.keyPath == key)
    }
  }

  func test_invalidItemBehaviourNotifier_sendsChangedValue_onValue() {
    let handler = InvalidItemBehaviourHandler()
    _ = InvalidItemNotifier.addListener(handler: handler.handle)
    expectNoError {
      let _: [String] = try arrayString.json(atKeyPath: key, invalidItemBehaviour: .value("default"))
      XCTAssertTrue(handler.events.count == 1)
      XCTAssertTrue(handler.events.first?.action == .changedValue("default"))
      let error = handler.events.first?.error
      XCTAssertTrue(error?.reason == DecodingError.Reason.incorrectType)
      XCTAssertTrue(error?.keyPath == key)
    }
  }

  func test_invalidItemBehaviourNotifier_sendsRemoved_onCustomNil() {
    let handler = InvalidItemBehaviourHandler()
    _ = InvalidItemNotifier.addListener(handler: handler.handle)
    expectNoError {
      let _: [String] = try arrayString.json(atKeyPath: key, invalidItemBehaviour: .custom({_ in .remove}))
      XCTAssertTrue(handler.events.count == 1)
      XCTAssertTrue(handler.events.first?.action == .removed)
      let error = handler.events.first?.error
      XCTAssertTrue(error?.reason == DecodingError.Reason.incorrectType)
      XCTAssertTrue(error?.keyPath == key)
    }
  }

  func test_invalidItemBehaviourNotifier_sendsChangedValue_onCustomValue() {
    let handler = InvalidItemBehaviourHandler()
    _ = InvalidItemNotifier.addListener(handler: handler.handle)
    expectNoError {
      let _: [String] = try arrayString.json(atKeyPath: key, invalidItemBehaviour: .custom({.value("\($0.value)")}))
      XCTAssertTrue(handler.events.count == 1)
      XCTAssertTrue(handler.events.first?.action == .changedValue("2"))
      let error = handler.events.first?.error
      XCTAssertTrue(error?.reason == DecodingError.Reason.incorrectType)
      XCTAssertTrue(error?.keyPath == key)
    }
  }

  func test_invalidItemBehaviourNotifier_sendsFailed_onCustomThrow() {
    let handler = InvalidItemBehaviourHandler()
    _ = InvalidItemNotifier.addListener(handler: handler.handle)

    do {
      let _: [String] = try arrayString.json(atKeyPath: key, invalidItemBehaviour: .custom({_ in .fail}))
    } catch {

    }
    XCTAssertTrue(handler.events.count == 1)
    XCTAssertTrue(handler.events.first?.action == .failed)
    let error = handler.events.first?.error
    XCTAssertTrue(error?.reason == DecodingError.Reason.incorrectType)
    XCTAssertTrue(error?.keyPath == key)
  }

  func test_invalidItemBehaviourNotifier_sendsFailed_onFail() {
    let handler = InvalidItemBehaviourHandler()
    _ = InvalidItemNotifier.addListener(handler: handler.handle)

    do {
      let _: [String] = try arrayString.json(atKeyPath: key, invalidItemBehaviour: .fail)
    } catch {

    }
    XCTAssertTrue(handler.events.count == 1)
    XCTAssertTrue(handler.events.first?.action == .failed)
    let error = handler.events.first?.error
    XCTAssertTrue(error?.reason == DecodingError.Reason.incorrectType)
    XCTAssertTrue(error?.keyPath == key)
  }

  func test_invalidItemBehaviourNotifier_arrayLocation() {
    let handler = InvalidItemBehaviourHandler()
    _ = InvalidItemNotifier.addListener(handler: handler.handle)

    expectNoError {
      let _: [String] = try arrayString.json(atKeyPath: key, invalidItemBehaviour: .remove)
    }
    let location = handler.events.first?.location
    let expectedLocation = InvalidItemLocation.array(["value1", 2], index: 1)
    XCTAssertTrue(location == expectedLocation)
    XCTAssertTrue(location?.structureName == expectedLocation.structureName)
    XCTAssertTrue(location != InvalidItemLocation.dictionary([:], key: ""))
  }

  func test_invalidItemBehaviourNotifier_dictionaryLocation() {
    let handler = InvalidItemBehaviourHandler()
    _ = InvalidItemNotifier.addListener(handler: handler.handle)

    expectNoError {
      let _: [String: String] = try dictionaryString.json(atKeyPath: key, invalidItemBehaviour: .remove)
    }
    let location = handler.events.first?.location
    let expectedLocation = InvalidItemLocation.dictionary(["key1": "value1", "key2": 2], key: "key2")
    XCTAssertTrue(location == expectedLocation)
    XCTAssertTrue(location?.structureName == expectedLocation.structureName)
    XCTAssertTrue(location?.value.debugDescription == expectedLocation.value.debugDescription)
    XCTAssertTrue(location != InvalidItemLocation.array([], index: 0))
  }

  func test_invalidItemBehaviourNotifier_removesListener() {
    InvalidItemNotifier.clearListeners()
    let handler = InvalidItemBehaviourHandler()
    let listener1 = InvalidItemNotifier.addListener(handler: handler.handle)
    InvalidItemNotifier.removeListener(listener1)

    let listener2 = InvalidItemNotifier.addListener(handler: handler.handle)
    listener2.stopListening()

    expectNoError {
      let _: [String] = try arrayString.json(atKeyPath: key, invalidItemBehaviour: .remove)
    }

    XCTAssertTrue(handler.events.isEmpty)
    XCTAssertTrue(InvalidItemNotifier.listeners.isEmpty)
  }
}
