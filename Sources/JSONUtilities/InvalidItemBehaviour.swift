//
//  InvalidItemBehaviour.swift
//  JSONUtilities
//
//  Created by Yonas Kolb on 27/4/17.
//  Copyright © 2017 Luciano Marisi. All rights reserved.
//

import Foundation

/// The behaviour of what should be done when an invalid JSON object or primitive is found
///
/// - remove: The item is filtered, only valid items are returned
/// - fail:  The call fails. For non optional properties this will throw an error, and for optional properties nil is returned
public enum InvalidItemBehaviour<T> {
  case remove
  case fail
  case value(T)
  case custom((DecodingError) -> InvalidItemBehaviour<T>)

  func decodeItem(location: InvalidItemLocation, decode: () throws -> T) throws -> T? {
    do {
      return try decode()
    } catch {
      let decodingError = error as? DecodingError

      switch self {
      case .remove:
        if let decodingError = decodingError {
          InvalidItemNotifier.sendEvent(.removed, location: location, behaviour: self, error: decodingError)
        }
        return nil
      case .fail:
        if let decodingError = decodingError {
          InvalidItemNotifier.sendEvent(.failed, location: location, behaviour: self, error: decodingError)
        }
        throw error
      case .value(let value):
        if let decodingError = decodingError {
            InvalidItemNotifier.sendEvent(.changedValue(value), location: location, behaviour: self, error: decodingError)
        }
        return value
      case .custom(let getBehaviour):
        guard let decodingError = decodingError  else { return nil }
        let behaviour = getBehaviour(decodingError)
        return try behaviour.decodeItem(location: location, decode: decode)
      }
    }
  }

  func typeErase() -> InvalidItemBehaviour<Any> {
    switch self {
    case .remove: return .remove
    case .fail: return .fail
    case .value(let value): return .value(value)
    case .custom(let closure): return .custom({closure($0).typeErase()})
    }
  }
}

/// The location when an InvalidItemBehaviour occured. Either in an array of dictionary
public enum InvalidItemLocation: Equatable {
  case array(JSONArray, index: Int)
  case dictionary(JSONDictionary, key: String)

  /// The name of the container Either "Array" or "Dictionary"
  public var structureName: String {
    switch self {
    case .array: return "Array"
    case .dictionary: return "Dictionary"
    }
  }

  /// Extracts the value out of the array or dictionary
  public var value: Any? {
    switch self {
    case .array(let array, let index): return index < array.count && index >= 0 ? array[index] : nil
    case .dictionary(let dictionary, let key): return dictionary[key]
    }
  }

  public static func == (lhs: InvalidItemLocation, rhs: InvalidItemLocation) -> Bool {
    switch (lhs, rhs) {
    case (.dictionary(let dictionary1, let key1), .dictionary(let dictionary2, let key2)): return dictionary1.description == dictionary2.description && key1 == key2
    case (.array(let array1, let index1), .array(let array2, let index2)): return array1.description == array2.description && index1 == index2
    default: return false
    }
  }
}

/// Notifies when InvalidItemBehaviours occur
class InvalidItemNotifier {

  typealias ListenerClosure = (Event) -> Void

  /// The event that gets sent to all listeners
  public struct Event {

    public let action: Action
    public let location: InvalidItemLocation
    public let behaviour: InvalidItemBehaviour<Any>
    public let error: DecodingError
  }

  /// The type of event action that occurred
  public enum Action: Equatable {
    /// when an item was removed
    case removed

    /// when an item's value was changed
    case changedValue(Any)

    /// when a failed item cause the whole array or dictionary to fail
    case failed

    public static func == (lhs: Action, rhs: Action) -> Bool {
      switch (lhs, rhs) {
      case (.removed, .removed): return true
      case (.changedValue(let value1), .changedValue(let value2)): return "\(value1)" == "\(value2)"
      case (.failed, .failed): return true
      default: return false
      }
    }
  }

  public class Listener {

    let handler: ListenerClosure

    init(handler: @escaping ListenerClosure) {
      self.handler = handler
    }

    /// stop listening to events
    public func stopListening() {
      InvalidItemNotifier.removeListener(self)
    }
  }

  static var listeners: [Listener] = []

  public static func clearListeners() {
    listeners = []
  }

  /// adds a listener for when InvalidItemBehaviours occur
  public static func addListener(handler: @escaping ListenerClosure) -> Listener {
    let listener = Listener(handler: handler)
    listeners.append(listener)
    return listener
  }

  /// stops a listener from recieving any events. Calling stopListening() on Listener has the same effect
  public static func removeListener(_ listener: Listener) {
    if let index = listeners.index( where: { $0 === listener }) {
      listeners.remove(at: index)
    }
  }

  static func sendEvent<T>(_ action: Action, location: InvalidItemLocation, behaviour: InvalidItemBehaviour<T>, error: DecodingError) {
    let event = Event(action: action, location: location, behaviour: behaviour.typeErase(), error: error)
    listeners.forEach { listener in
      listener.handler(event)
    }
  }
}
