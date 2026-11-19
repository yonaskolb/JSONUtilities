//
//  KeyAccessTracking.swift
//  JSONUtilities
//

import Foundation

/// A key that was present in a decoded JSON object but never read while decoding it.
public struct UnusedKey: Equatable, Hashable, Sendable, CustomStringConvertible {

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
    /// - Returns: The result of `body`, and the unused keys sorted by their description.
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
    public static var currentPath: [String]? {
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
    ///   - component: The path component of this object, e.g. a key or `sources[1]`
    ///   - allKeysRead: Pass true when the keys of this dictionary are data rather than known keys
    public static func scope<R>(_ dictionary: JSONDictionary, at component: String, allKeysRead: Bool = false, _ body: () throws -> R) rethrows -> R {
        guard let parent = current else { return try body() }

        let scope = Scope(session: parent.session, path: parent.path + [component], dictionary: dictionary, allKeysRead: allKeysRead)
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
            return keys.sorted { $0.description < $1.description }
        }
    }

    // Reads can come from several threads at once when a context is shared, so state is behind a lock
    fileprivate final class Scope: @unchecked Sendable {
        let session: Session
        let path: [String]
        private let dictionary: JSONDictionary
        private let lock = NSLock()
        private var readKeys: Set<String> = []
        private var allKeysRead: Bool

        init(session: Session, path: [String], dictionary: JSONDictionary, allKeysRead: Bool) {
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
