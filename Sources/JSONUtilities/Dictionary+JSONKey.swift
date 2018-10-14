//
//  Dictionary+JSONKey.swift
//  JSONUtilities
//
//  Created by Luciano Marisi on 05/03/2016.
//  Copyright © 2016 Luciano Marisi All rights reserved.
//

import Foundation

/// Protocol used for defining the valid JSON types, i.e. Int, Double, Float, String and Bool
public protocol JSONRawType {}
extension Int: JSONRawType {}
extension Double: JSONRawType {}
extension Float: JSONRawType {}
extension String: JSONRawType {}
extension Bool: JSONRawType {}

public protocol JSONKey {
    var key: String { get }
    init?(rawValue: String)
}

extension String: JSONKey {
    public var key: String { return self }

    public init(rawValue: String) {
        self = rawValue
    }
}

extension Dictionary where Key: JSONKey {

    // MARK: JSONRawType

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath) throws -> T {
        return try getValue(atKeyPath: keyPath)
    }

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath) -> T? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [JSONRawType]

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [T] {
        return try decodeArray(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour, decode: getValue)
    }

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [T]? {
        return try? json(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour)
    }

    // MARK: [String: Any]

    public func json(atKeyPath keyPath: KeyPath) throws -> JSONDictionary {
        return try getValue(atKeyPath: keyPath)
    }

    public func json(atKeyPath keyPath: KeyPath) -> JSONDictionary? {
        return self[keyPath: keyPath] as? JSONDictionary
    }

    // MARK: [[String: Any]]

    public func json(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<JSONDictionary> = .remove) throws -> [JSONDictionary] {
        return try decodeArray(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour, decode: getValue)
    }

    public func json(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<JSONDictionary> = .remove) -> [JSONDictionary]? {
        return try? json(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour)
    }

    // MARK: [String: JSONObjectConvertible]

    public func json<T: JSONObjectConvertible, K: JSONKey>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [K: T] {
        return try decodeDictionary(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) { jsonDictionary, key in
            try jsonDictionary.json(atKeyPath: key) as T
        }
    }

    public func json<T: JSONObjectConvertible, K: JSONKey>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [K: T]? {
        return try? json(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) as [K: T]
    }

    // MARK: [String: JSONRawType]

    public func json<T: JSONRawType, K: JSONKey>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [K: T] {
        return try decodeDictionary(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) { jsonDictionary, key in
            try jsonDictionary.json(atKeyPath: key) as T
        }
    }

    public func json<T: JSONRawType, K: JSONKey>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [K: T]? {
        return try? json(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) as [K: T]
    }

    // MARK: [String: JSONPrimitiveConvertible]

    public func json<T: JSONPrimitiveConvertible, K: JSONKey>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [K: T] {
        return try decodeDictionary(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) { jsonDictionary, key in
            try jsonDictionary.json(atKeyPath: key) as T
        }
    }

    public func json<T: JSONPrimitiveConvertible, K: JSONKey>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [K: T]? {
        return try? json(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) as [K: T]
    }

    // MARK: JSONObjectConvertible

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath) throws -> T {
        return try T(jsonDictionary: JSONDictionaryForKey(atKeyPath: keyPath))
    }

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath) -> T? {
        return try? T(jsonDictionary: JSONDictionaryForKey(atKeyPath: keyPath))
    }

    // MARK: [JSONObjectConvertible]

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [T] {
        return try decodeArray(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) { keyPath, jsonArray, value in
            let jsonDictionary: JSONDictionary = try getValue(atKeyPath: keyPath, array: jsonArray, value: value)
            return try T(jsonDictionary: jsonDictionary)
        }
    }

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [T]? {
        return try? json(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour)
    }

    // MARK: RawRepresentable

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath) throws -> T where T.RawValue: JSONRawType {
        let rawValue: T.RawValue = try getValue(atKeyPath: keyPath)

        guard let value = T(rawValue: rawValue) else {
            throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: T.self, value: rawValue, reason: .incorrectRawRepresentableRawValue)
        }

        return value
    }

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath) -> T? where T.RawValue: JSONRawType {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [RawRepresentable]

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [T] where T.RawValue: JSONRawType {

        return try decodeArray(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) { keyPath, jsonArray, value in
            let rawValue: T.RawValue = try getValue(atKeyPath: keyPath, array: jsonArray, value: value)

            guard let value = T(rawValue: rawValue) else {
                throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: T.self, value: rawValue, array: jsonArray, reason: .incorrectRawRepresentableRawValue)
            }
            return value
        }
    }

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [T]? where T.RawValue: JSONRawType {
        return try? json(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour)
    }

    // MARK: [String: RawRepresentable]

    public func json<T: RawRepresentable, K: JSONKey>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [K: T] where T.RawValue: JSONRawType {
        return try decodeDictionary(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) { jsonDictionary, key in
            let rawValue: T.RawValue = try jsonDictionary.getValue(atKeyPath: key)

            guard let value = T(rawValue: rawValue) else {
                throw DecodingError(dictionary: jsonDictionary, keyPath: keyPath, expectedType: T.self, value: rawValue, reason: .incorrectRawRepresentableRawValue)
            }
            return value
        }
    }

    public func json<T: RawRepresentable, K: JSONKey>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [K: T]? where T.RawValue: JSONRawType {
        return try? json(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour)
    }

    // MARK: JSONPrimitiveConvertible

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath) throws -> T {
        let jsonValue: T.JSONType = try getValue(atKeyPath: keyPath)

        guard let transformedValue = T.from(jsonValue: jsonValue) else {
            throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: T.self, value: jsonValue, reason: .conversionFailure)
        }

        return transformedValue
    }

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath) -> T? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [JSONPrimitiveConvertible]

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [T] {
        return try decodeArray(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour) { keyPath, jsonArray, value in
            let jsonValue: T.JSONType = try getValue(atKeyPath: keyPath, array: jsonArray, value: value)

            guard let transformedValue = T.from(jsonValue: jsonValue) else {
                throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: T.self, value: jsonValue, array: jsonArray, reason: .conversionFailure)
            }
            return transformedValue
        }
    }

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [T]? {
        return try? json(atKeyPath: keyPath, invalidItemBehaviour: invalidItemBehaviour)
    }

    // MARK: [String: [RawRepresentable]]

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [String: [T]] where T.RawValue: JSONRawType {
        let jsonDictionary: JSONDictionary = try json(atKeyPath: keyPath)
        var dictionary: [String: [T]] = [:]
        for key in jsonDictionary.keys {
            let array: [T] = try jsonDictionary.json(atKeyPath: .key(key), invalidItemBehaviour: invalidItemBehaviour)
            dictionary[key] = array
        }
        return dictionary
    }

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [String: [T]]? where T.RawValue: JSONRawType {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [String: [JSONPrimitiveConvertible]]

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [String: [T]] {
        let jsonDictionary: JSONDictionary = try json(atKeyPath: keyPath)
        var dictionary: [String: [T]] = [:]
        for key in jsonDictionary.keys {
            let array: [T] = try jsonDictionary.json(atKeyPath: .key(key), invalidItemBehaviour: invalidItemBehaviour)
            dictionary[key] = array
        }
        return dictionary
    }

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [String: [T]]? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [String: [JSONObjectConvertible]]

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [String: [T]] {
        let jsonDictionary: JSONDictionary = try json(atKeyPath: keyPath)
        var dictionary: [String: [T]] = [:]
        for key in jsonDictionary.keys {
            let array: [T] = try jsonDictionary.json(atKeyPath: .key(key), invalidItemBehaviour: invalidItemBehaviour)
            dictionary[key] = array
        }
        return dictionary
    }

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [String: [T]]? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [String: [JSONRawType]]

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [String: [T]] {
        let jsonDictionary: JSONDictionary = try json(atKeyPath: keyPath)
        var dictionary: [String: [T]] = [:]
        for key in jsonDictionary.keys {
            let array: [T] = try jsonDictionary.json(atKeyPath: .key(key), invalidItemBehaviour: invalidItemBehaviour)
            dictionary[key] = array
        }
        return dictionary
    }

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [String: [T]]? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [String: [String: RawRepresentable]]

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [String: [String: T]] where T.RawValue: JSONRawType {
        let jsonDictionary: JSONDictionary = try json(atKeyPath: keyPath)
        var dictionary: [String: [String: T]] = [:]
        for key in jsonDictionary.keys {
            let subDictionary: [String: T] = try jsonDictionary.json(atKeyPath: .key(key), invalidItemBehaviour: invalidItemBehaviour)
            dictionary[key] = subDictionary
        }
        return dictionary
    }

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [String: [String: T]]? where T.RawValue: JSONRawType {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [String: [String: JSONPrimitiveConvertible]]

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [String: [String: T]] {
        let jsonDictionary: JSONDictionary = try json(atKeyPath: keyPath)
        var dictionary: [String: [String: T]] = [:]
        for key in jsonDictionary.keys {
            let subDictionary: [String: T] = try jsonDictionary.json(atKeyPath: .key(key), invalidItemBehaviour: invalidItemBehaviour)
            dictionary[key] = subDictionary
        }
        return dictionary
    }

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [String: [String: T]]? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [String: [String: JSONObjectConvertible]]

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [String: [String: T]] {
        let jsonDictionary: JSONDictionary = try json(atKeyPath: keyPath)
        var dictionary: [String: [String: T]] = [:]
        for key in jsonDictionary.keys {
            let subDictionary: [String: T] = try jsonDictionary.json(atKeyPath: .key(key), invalidItemBehaviour: invalidItemBehaviour)
            dictionary[key] = subDictionary
        }
        return dictionary
    }

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [String: [String: T]]? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [String: [String: JSONRawType]]

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [String: [String: T]] {
        let jsonDictionary: JSONDictionary = try json(atKeyPath: keyPath)
        var dictionary: [String: [String: T]] = [:]
        for key in jsonDictionary.keys {
            let subDictionary: [String: T] = try jsonDictionary.json(atKeyPath: .key(key), invalidItemBehaviour: invalidItemBehaviour)
            dictionary[key] = subDictionary
        }
        return dictionary
    }

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [String: [String: T]]? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [[RawRepresentable]]

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [[T]] where T.RawValue: JSONRawType {

        return try decodeArray(atKeyPath: keyPath) { (keyPath, jsonArray, value) -> [T] in
            if let array = value as? [T.RawValue] {
                return try array.map {
                    guard let value = T(rawValue: $0) else {
                        throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: T.self, value: $0, array: array, reason: .incorrectRawRepresentableRawValue)
                    }
                    return value
                }
            } else {
                throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: Array<T.RawValue>.self, value: value, array: jsonArray, reason: .incorrectType)
            }
        }
    }

    public func json<T: RawRepresentable>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [[T]]? where T.RawValue: JSONRawType {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [[JSONPrimitiveConvertible]]

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [[T]] {

        return try decodeArray(atKeyPath: keyPath) { (keyPath, jsonArray, value) -> [T] in
            if let array = value as? JSONArray {
                return try array.map {
                    let jsonValue: T.JSONType = try getValue(atKeyPath: keyPath, array: array, value: $0)
                    guard let transformedValue = T.from(jsonValue: jsonValue) else {
                        throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: T.self, value: $0, array: jsonArray, reason: .conversionFailure)
                    }
                    return transformedValue
                }
            } else {
                throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: JSONArray.self, value: value, array: jsonArray, reason: .incorrectType)
            }
        }
    }

    public func json<T: JSONPrimitiveConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [[T]]? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [[JSONRawType]]

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [[T]] {

        return try decodeArray(atKeyPath: keyPath) { (keyPath, jsonArray, value) -> [T] in
            if let array = value as? JSONArray {
                return try array.map {
                    try getValue(atKeyPath: keyPath, array: array, value: $0)
                }
            } else {
                throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: JSONArray.self, value: value, array: jsonArray, reason: .incorrectType)
            }
        }
    }

    public func json<T: JSONRawType>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [[T]]? {
        return try? json(atKeyPath: keyPath)
    }

    // MARK: [[JSONObjectConvertible]]

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [[T]] {

        return try decodeArray(atKeyPath: keyPath) { (keyPath, jsonArray, value) -> [T] in
            if let array = value as? JSONArray {
                return try array.map {
                    let jsonDictionary: JSONDictionary = try getValue(atKeyPath: keyPath, array: array, value: $0)
                    return try T(jsonDictionary: jsonDictionary)
                }
            } else {
                throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: JSONArray.self, value: value, array: jsonArray, reason: .incorrectType)
            }
        }
    }

    public func json<T: JSONObjectConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) -> [[T]]? {
        return try? json(atKeyPath: keyPath)
    }
}

extension Dictionary where Key: JSONKey {

    // MARK: JSONDictionary and JSONArray creation

    fileprivate func JSONDictionaryForKey(atKeyPath keyPath: KeyPath) throws -> JSONDictionary {
        return try getValue(atKeyPath: keyPath)
    }

    fileprivate func JSONArrayForKey(atKeyPath keyPath: KeyPath) throws -> JSONArray {
        return try getValue(atKeyPath: keyPath)
    }

    // MARK: Value decoding

    fileprivate func getValue<A, B>(atKeyPath keyPath: KeyPath, array: [A], value: A) throws -> B {
        guard let typedValue = value as? B else {
            throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: B.self, value: value, array: array, reason: .incorrectType)
        }
        return typedValue
    }

    fileprivate func getValue<T>(atKeyPath keyPath: KeyPath) throws -> T {
        guard let value = self[keyPath: keyPath] else {
            throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: T.self, value: "", reason: .keyNotFound)
        }
        guard let typedValue = value as? T else {
            throw DecodingError(dictionary: self, keyPath: keyPath, expectedType: T.self, value: value, reason: .incorrectType)
        }
        return typedValue
    }

    // MARK: Dictionary decoding

    fileprivate func decodeDictionary<T, K: JSONKey>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove, decode: (JSONDictionary, KeyPath) throws -> T) throws -> [K: T] {
        let jsonDictionary: JSONDictionary = try json(atKeyPath: keyPath)

        var dictionary: [K: T] = [:]
        for (key, _) in jsonDictionary {
            if let jsonKey = K(rawValue: key), let item = try invalidItemBehaviour.decodeItem(decode: { try decode(jsonDictionary, KeyPath.key(key)) }) {
                dictionary[jsonKey] = item
            }
        }

        return dictionary
    }

    // MARK: Array decoding

    fileprivate func decodeArray<T>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove, decode: (KeyPath, JSONArray, Any) throws -> T) throws -> [T] {
        let jsonArray = try JSONArrayForKey(atKeyPath: keyPath)

        return try jsonArray.compactMap { value in
            try invalidItemBehaviour.decodeItem(decode: { try decode(keyPath, jsonArray, value) })
        }
    }
}
