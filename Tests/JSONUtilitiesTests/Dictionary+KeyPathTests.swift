//
//  Dictionary+KeyPathTests.swift
//  JSONUtilities
//
//  Created by Luciano Marisi on 04/09/2016.
//  Copyright © 2016 Luciano Marisi. All rights reserved.
//

import XCTest
@testable import JSONUtilities

class Dictionary_KeyPathTests: XCTestCase {

  func testAccessOneLevelDeep() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
        "first_level_key": expectedValue
      ]
    ]
    guard let calculatedValue = dictionary[keyPath: "root_key.first_level_key"] as? String else {
      XCTFail(#function)
      return
    }
    XCTAssertEqual(calculatedValue, expectedValue)
  }

  func testAccessTwoLevelDeep() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
        "first_level_key": [
          "second_level_key": expectedValue
        ]
      ]
    ]
    guard let calculatedValue = dictionary[keyPath: "root_key.first_level_key.second_level_key"] as? String else {
      XCTFail(#function)
      return
    }
    XCTAssertEqual(calculatedValue, expectedValue)
  }

  func testAccessArrayIndex() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
          "incorrectValue1",
          expectedValue,
          "incorrectValue2"
      ]
    ]
    guard let calculatedValue = dictionary[keyPath: "root_key.1"] as? String else {
      XCTFail(#function)
      return
    }
    XCTAssertEqual(calculatedValue, expectedValue)
  }

  func testAccessArrayIndexAndThenDictioanry() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
        ["incorrectDictionary1": "incorrectValue"],
        ["firstLevelKey": expectedValue],
        ["incorrectDictionary1": "incorrectValue"]
      ]
    ]
    guard let calculatedValue = dictionary[keyPath: "root_key.1.firstLevelKey"] as? String else {
      XCTFail(#function)
      return
    }
    XCTAssertEqual(calculatedValue, expectedValue)
  }

  func testAccessRepeatedKey_InSequence_OneLevelDeep() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
        "root_key": expectedValue
      ]
    ]
    guard let calculatedValue = dictionary[keyPath: "root_key.root_key"] as? String else {
      XCTFail(#function)
      return
    }
    XCTAssertEqual(calculatedValue, expectedValue)
  }

  func testAccessInDictionary_withIntKey() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
        "1": [
          "root_key": expectedValue
        ]
      ]
    ]
    guard let calculatedValue = dictionary[keyPath: "root_key.1.root_key"] as? String else {
      XCTFail(#function)
      return
    }
    XCTAssertEqual(calculatedValue, expectedValue)
  }

  func testAccessRepeatedKey_InSequence_TwoLevelsDeep() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
        "root_key": [
          "root_key": expectedValue
        ]
      ]
    ]
    guard let calculatedValue = dictionary[keyPath: "root_key.root_key.root_key"] as? String else {
      XCTFail(#function)
      return
    }
    XCTAssertEqual(calculatedValue, expectedValue)
  }

  func testAccessRepeatedKey_InBetweenSequence_TwoLevelsDeep() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
        "first_level_key": [
          "root_key": expectedValue
        ]
      ]
    ]
    guard let calculatedValue = dictionary[keyPath: "root_key.first_level_key.root_key"] as? String else {
      XCTFail(#function)
      return
    }
    XCTAssertEqual(calculatedValue, expectedValue)
  }

  func testAccess_MalformedKeyPath_OneLevelDeep() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
        "first_level_key": expectedValue
      ]
    ]

    let calculatedValue = dictionary[keyPath: "root_key..first_level_key"] as? String
    XCTAssertNil(calculatedValue)
  }

  func testAccess_KeyPathEndsWithADot_OneLevelDeep() {
    let expectedValue = "value"
    let dictionary = [
      "root_key": [
        "first_level_key": expectedValue
      ]
    ]

    guard let calculatedValue = dictionary[keyPath: "root_key.first_level_key."] as? String else {
      XCTFail(#function)
      return
    }
    XCTAssertEqual(calculatedValue, expectedValue)
  }

}
