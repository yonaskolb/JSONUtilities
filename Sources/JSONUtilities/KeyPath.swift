//
//  KeyType.swift
//  JSONUtilities
//
//  Created by Yonas Kolb on 12/5/17.
//  Copyright © 2017 Luciano Marisi. All rights reserved.
//

import Foundation

public enum KeyPath {
  case key(String)
  case keyPath([String])

  public init(_ keyPath: String) {
    var parts = keyPath.components(separatedBy: ".")

    //removes trailing .
    if parts.count > 1, let last = parts.last, last.isEmpty {
      _ = parts.popLast()
    }

    if parts.count > 1 {
      self = .keyPath(parts)
    } else {
      self = .key(keyPath)
    }
  }

  public var string: String {
    switch self {
      case .key(let key): return key
      case .keyPath(let keys): return keys.joined(separator: ".")
    }
  }

  func getValue(dictionary: JSONDictionary) -> Any? {

    switch self {
    case .key(let key):
      return dictionary[key]
    case .keyPath(let keys):
      guard let firstKey = keys.first,
      let value = dictionary[firstKey] else {
        return nil
      }
      var newKeys = keys
      newKeys.removeFirst()
      if newKeys.isEmpty {
        return value
      } else {
        guard let secondKey = newKeys.first else {
          return nil
        }

        // index into array
        if let index = Int(secondKey), index >= 0,
          let array = value as? JSONArray {
          guard index < array.count else {
            // index out of bounds
            return nil
          }
          newKeys.removeFirst()
          let arrayValue = array[index]
          if newKeys.isEmpty {
            return arrayValue
          }
          guard let dictionary = arrayValue as? JSONDictionary else {
            // array value isn't dictionary
            return nil
          }
          return KeyPath.keyPath(newKeys).getValue(dictionary: dictionary)
        }

        guard let dictionary = value as? JSONDictionary else {
          // second key path isn't a dictionary
          return nil
        }
        return KeyPath.keyPath(newKeys).getValue(dictionary: dictionary)
      }
    }
  }
}

extension KeyPath: ExpressibleByStringLiteral {

  public typealias StringLiteralType = String
  public typealias ExtendedGraphemeClusterLiteralType = String
  public typealias UnicodeScalarLiteralType = String

  public init(stringLiteral value: KeyPath.StringLiteralType) {
    self = KeyPath(value)
  }

  public init(extendedGraphemeClusterLiteral value: KeyPath.ExtendedGraphemeClusterLiteralType) {
    self = KeyPath(value)
  }

  public init(unicodeScalarLiteral value: KeyPath.UnicodeScalarLiteralType) {
    self = KeyPath(value)
  }
}
