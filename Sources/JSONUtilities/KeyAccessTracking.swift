//
//  KeyAccessTracking.swift
//  JSONUtilities
//

import Foundation

/// A key that was present in a decoded JSON object but never read while decoding it.
public struct UnusedKey: Equatable, Hashable, CustomStringConvertible {

    /// The path to the object that contains the key, e.g. `["targets", "App"]` or `["sources[1]"]`
    public let path: [String]

    /// The unused key itself
    public let key: String

    public init(path: [String], key: String) {
        self.path = path
        self.key = key
    }

    /// The full path to the key, joined with `.`, e.g. `targets.App.resources`
    public var description: String {
        return (path + [key]).joined(separator: ".")
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
/// Scopes are kept per thread, so decoding on several threads at once is supported.
/// A scope started on a thread with no current scope (for example a worker thread) uses the path passed to it.
public enum KeyAccessTracking {

    // MARK: Public API

    /// Runs `body` while recording key reads, and returns its result along with all keys that were never read.
    ///
    /// - Parameters:
    ///   - root: An optional root dictionary to track. Its unused keys are reported with an empty path.
    ///   - body: The decoding to perform.
    /// - Returns: The result of `body`, and the unused keys sorted by their description.
    public static func record<R>(root: JSONDictionary? = nil, _ body: () throws -> R) rethrows -> (R, [UnusedKey]) {
        let session = Session()

        let previousSession = currentSession
        let previousScopes = scopes
        currentSession = session
        scopes = []
        defer {
            currentSession = previousSession
            scopes = previousScopes
        }

        let result: R
        if let root = root {
            result = try scope(root, path: [], body)
        } else {
            result = try body()
        }
        return (result, session.unusedKeys)
    }

    /// Whether key reads are currently being recorded
    public static var isRecording: Bool {
        return currentSession != nil
    }

    /// The path of the innermost scope on the current thread, or nil if there is none.
    /// Capture this before handing work to other threads, and pass it to `scope(_:path:_:)` there.
    public static var currentPath: [String]? {
        return scopes.last?.path
    }

    /// Decodes a nested object in its own scope, with a path relative to the current scope.
    /// The library does this for every object it decodes. Use it for objects you decode yourself.
    ///
    /// - Parameters:
    ///   - dictionary: The dictionary being decoded
    ///   - component: The path component of this object, e.g. a key or `sources[1]`
    ///   - allKeysRead: Pass true when the keys of this dictionary are data rather than known keys
    public static func scope<R>(_ dictionary: JSONDictionary, at component: String, allKeysRead: Bool = false, _ body: () throws -> R) rethrows -> R {
        guard isRecording else { return try body() }
        let path = (currentPath ?? []) + [component]
        return try scope(dictionary, path: path, allKeysRead: allKeysRead, body)
    }

    /// Decodes a nested object in its own scope, with an absolute path.
    public static func scope<R>(_ dictionary: JSONDictionary, path: [String], allKeysRead: Bool = false, _ body: () throws -> R) rethrows -> R {
        guard let session = currentSession else { return try body() }

        let scope = Scope(dictionary: dictionary, path: path, session: session)
        scope.allKeysRead = allKeysRead
        scopes.append(scope)
        defer { scopes.removeLast() }

        let result = try body()
        scope.reportUnusedKeys()
        return result
    }

    /// Marks keys of the current scope as read. Use this for keys read without `json(atKeyPath:)`,
    /// for example `jsonDictionary["key"]`, or keys consumed before decoding.
    public static func markRead(_ keys: String...) {
        markRead(keys)
    }

    /// Marks keys of the current scope as read.
    public static func markRead<S: Sequence>(_ keys: S) where S.Element == String {
        guard let scope = scopes.last else { return }
        scope.readKeys.formUnion(keys)
    }

    /// Marks every key of the current scope as read.
    /// Use this when the keys of the object being decoded are data, for example a dictionary of settings.
    public static func markAllRead() {
        scopes.last?.allKeysRead = true
    }

    // MARK: Internal

    /// Called by `Dictionary.subscript(keyPath:)` for every top level key read
    static func didRead(_ key: String) {
        guard let scope = scopes.last else { return }
        scope.readKeys.insert(key)
    }

    // MARK: Private

    private final class Session {
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
            return keys.sorted { $0.description < $1.description }
        }
    }

    private final class Scope {
        let dictionary: JSONDictionary
        let path: [String]
        let session: Session
        var readKeys: Set<String> = []
        var allKeysRead = false

        init(dictionary: JSONDictionary, path: [String], session: Session) {
            self.dictionary = dictionary
            self.path = path
            self.session = session
        }

        func reportUnusedKeys() {
            guard !allKeysRead else { return }
            let unused = dictionary.keys
                .filter { !readKeys.contains($0) }
                .map { UnusedKey(path: path, key: $0) }
            if !unused.isEmpty {
                session.add(unused)
            }
        }
    }

    private static let sessionLock = NSLock()
    private static var _currentSession: Session?

    private static var currentSession: Session? {
        get {
            sessionLock.lock()
            defer { sessionLock.unlock() }
            return _currentSession
        }
        set {
            sessionLock.lock()
            _currentSession = newValue
            sessionLock.unlock()
        }
    }

    private static let scopesKey = "JSONUtilities.KeyAccessTracking.scopes"

    private static var scopes: [Scope] {
        get {
            return Thread.current.threadDictionary[scopesKey] as? [Scope] ?? []
        }
        set {
            if newValue.isEmpty {
                Thread.current.threadDictionary.removeObject(forKey: scopesKey)
            } else {
                Thread.current.threadDictionary[scopesKey] = newValue
            }
        }
    }
}
