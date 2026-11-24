//
//  KeyAccessTracking.swift
//  JSONUtilities
//

import Foundation

/// One step in the path to a JSON value: a dictionary key, or an array index
public enum JSONPathComponent: Hashable, Comparable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
    case key(String)
    case index(Int)

    public init(stringLiteral value: String) {
        self = .key(value)
    }

    public init(integerLiteral value: Int) {
        self = .index(value)
    }

    /// `key` for a key, or `[index]` for an index
    public var description: String {
        switch self {
        case let .key(key): return key
        case let .index(index): return "[\(index)]"
        }
    }

    /// Keys sort before indexes, keys sort alphabetically and indexes numerically
    public static func < (lhs: JSONPathComponent, rhs: JSONPathComponent) -> Bool {
        switch (lhs, rhs) {
        case let (.key(lhs), .key(rhs)): return lhs < rhs
        case let (.index(lhs), .index(rhs)): return lhs < rhs
        case (.key, .index): return true
        case (.index, .key): return false
        }
    }

    /// Formats a path like `targets.App.sources[1]`
    public static func format(_ path: [JSONPathComponent]) -> String {
        var string = ""
        for component in path {
            switch component {
            case let .key(key):
                if !string.isEmpty { string += "." }
                string += key
            case .index:
                string += component.description
            }
        }
        return string
    }
}

/// A key that was present in a decoded JSON object but never read while decoding it.
public struct UnusedKey: Hashable, Comparable, Sendable, CustomStringConvertible {

    /// The path to the object that contains the key, e.g. `[.key("targets"), .key("App")]` or `[.key("sources"), .index(1)]`
    public let path: [JSONPathComponent]

    /// The unused key itself
    public let key: String

    public init(path: [JSONPathComponent], key: String) {
        self.path = path
        self.key = key
    }

    /// The full path to the key, e.g. `targets.App.resources` or `sources[1].buildphase`
    public var description: String {
        return JSONPathComponent.format(path + [.key(key)])
    }

    /// Sorts by path, with array indexes in numeric order
    public static func < (lhs: UnusedKey, rhs: UnusedKey) -> Bool {
        return (lhs.path + [.key(lhs.key)]).lexicographicallyPrecedes(rhs.path + [.key(rhs.key)])
    }
}

/// Records which keys are read while decoding JSON objects, so that keys that were never read can be reported.
///
/// Recording is opt-in and only happens inside `KeyAccessTracking.record`. Outside of it, every call here is a no-op.
///
/// While recording, every `JSONObjectConvertible` decoded through the `json(atKeyPath:)` functions gets its own scope.
/// Each key read through `json(atKeyPath:)` is marked as read in the innermost scope. When a scope finishes decoding
/// successfully, the keys of its dictionary that were never read are reported as `UnusedKey`s.
///
/// The current scope is a task local value, so separate recordings never interfere with each other, and child tasks
/// continue the recording of their parent. Threads that aren't child tasks, like those of
/// `DispatchQueue.concurrentPerform`, don't inherit it: capture `currentContext` and continue it with `withContext`.
public enum KeyAccessTracking {

    // MARK: Public API

    /// Runs `body` while recording key reads, and returns its result along with all keys that were never read.
    ///
    /// - Parameters:
    ///   - root: An optional root dictionary to track. Its unused keys are reported with an empty path.
    ///   - body: The decoding to perform.
    /// - Returns: The result of `body`, and the unused keys sorted by path.
    public static func record<R>(root: JSONDictionary? = nil, _ body: () throws -> R) rethrows -> (R, [UnusedKey]) {
        let session = Session()
        let rootScope = Scope(session: session, path: [], dictionary: root ?? [:], allKeysRead: root == nil)
        let result = try $current.withValue(rootScope, operation: body)
        rootScope.reportUnusedKeys()
        return (result, session.unusedKeys)
    }

    /// Whether key reads are currently being recorded
    public static var isRecording: Bool {
        return current != nil
    }

    /// The path of the current scope, or nil when not recording
    public static var currentPath: [JSONPathComponent]? {
        return current?.path
    }

    /// A handle to the current scope, for continuing the recording on threads that don't inherit it
    public struct Context: @unchecked Sendable {
        fileprivate let scope: Scope
    }

    /// The current scope, or nil when not recording. Pass it to `withContext` on another thread.
    public static var currentContext: Context? {
        return current.map(Context.init)
    }

    /// Runs `body` in the given context, so that its decoding is recorded as part of that context's scope.
    public static func withContext<R>(_ context: Context?, _ body: () throws -> R) rethrows -> R {
        guard let context = context else { return try body() }
        return try $current.withValue(context.scope, operation: body)
    }

    /// Decodes a nested object in its own scope, with a path relative to the current scope.
    /// The library does this for every object it decodes. Use it for objects you decode yourself.
    ///
    /// - Parameters:
    ///   - dictionary: The dictionary being decoded
    ///   - component: The path of this object relative to the current scope, e.g. `"settings"`
    ///   - allKeysRead: Pass true when the keys of this dictionary are data rather than known keys
    public static func scope<R>(_ dictionary: JSONDictionary, at component: JSONPathComponent, allKeysRead: Bool = false, _ body: () throws -> R) rethrows -> R {
        return try scope(dictionary, at: [component], allKeysRead: allKeysRead, body)
    }

    /// Decodes a nested object in its own scope, with a path relative to the current scope,
    /// e.g. `["sources", .index(1)]` for an array element.
    public static func scope<R>(_ dictionary: JSONDictionary, at path: [JSONPathComponent], allKeysRead: Bool = false, _ body: () throws -> R) rethrows -> R {
        guard let parent = current else { return try body() }

        let scope = Scope(session: parent.session, path: parent.path + path, dictionary: dictionary, allKeysRead: allKeysRead)
        let result = try $current.withValue(scope, operation: body)
        scope.reportUnusedKeys()
        return result
    }

    /// Marks keys of the current scope as read. Use this for keys read without `json(atKeyPath:)`,
    /// for example `jsonDictionary["key"]`, or keys consumed before decoding.
    public static func markRead(_ keys: String...) {
        current?.markRead(keys)
    }

    /// Marks keys of the current scope as read.
    public static func markRead<S: Sequence>(_ keys: S) where S.Element == String {
        current?.markRead(keys)
    }

    /// Marks every key of the current scope as read.
    /// Use this when the keys of the object being decoded are data, for example a dictionary of settings.
    public static func markAllRead() {
        current?.markAllRead()
    }

    // MARK: Internal

    /// Called by `Dictionary.subscript(keyPath:)` for every top level key read
    static func didRead(_ key: String) {
        current?.markRead(CollectionOfOne(key))
    }

    // MARK: Private

    @TaskLocal private static var current: Scope?

    fileprivate final class Session: @unchecked Sendable {
        private let lock = NSLock()
        private var keys: [UnusedKey] = []

        func add(_ newKeys: [UnusedKey]) {
            lock.lock()
            keys.append(contentsOf: newKeys)
            lock.unlock()
        }

        var unusedKeys: [UnusedKey] {
            lock.lock()
            defer { lock.unlock() }
            return keys.sorted()
        }
    }

    // Reads can come from several threads at once when a context is shared, so state is behind a lock
    fileprivate final class Scope: @unchecked Sendable {
        let session: Session
        let path: [JSONPathComponent]
        private let dictionary: JSONDictionary
        private let lock = NSLock()
        private var readKeys: Set<String> = []
        private var allKeysRead: Bool

        init(session: Session, path: [JSONPathComponent], dictionary: JSONDictionary, allKeysRead: Bool) {
            self.session = session
            self.path = path
            self.dictionary = dictionary
            self.allKeysRead = allKeysRead
        }

        func markRead<S: Sequence>(_ keys: S) where S.Element == String {
            lock.lock()
            readKeys.formUnion(keys)
            lock.unlock()
        }

        func markAllRead() {
            lock.lock()
            allKeysRead = true
            lock.unlock()
        }

        func reportUnusedKeys() {
            lock.lock()
            let unused = allKeysRead ? [] : dictionary.keys
                .filter { !readKeys.contains($0) }
                .map { UnusedKey(path: path, key: $0) }
            lock.unlock()
            if !unused.isEmpty {
                session.add(unused)
            }
        }
    }
}
