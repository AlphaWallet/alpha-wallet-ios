//
//  AtomicArray.swift
//  AlphaWalletAddress
//
//  Created by Vladyslav Shepitko on 16.05.2022.
//

import Foundation

// https://developer.apple.com/documentation/swift/rangereplaceablecollection
public struct AtomicArray<T>: RangeReplaceableCollection {

    public typealias Element = T
    public typealias Index = Int
    public typealias SubSequence = AtomicArray<T>
    public typealias Indices = Range<Int>
    public var array: [T]
    public var startIndex: Int { return array.startIndex }
    public var endIndex: Int { return array.endIndex }
    public var indices: Range<Int> { return array.indices }
    public func index(after i: Int) -> Int { return array.index(after: i) }
    private var semaphore = DispatchSemaphore(value: 1)
    public func _wait() { semaphore.wait() }
    public func _signal() { semaphore.signal() }
}

// MARK: - Instance Methods
public extension AtomicArray {

    init<S>(_ elements: S) where S: Sequence, AtomicArray.Element == S.Element {
// swiftlint:disable syntactic_sugar
        array = Array<S.Element>(elements)
// swiftlint:enable syntactic_sugar
    }

    init() { self.init([]) }

    init(repeating repeatedValue: AtomicArray.Element, count: Int) {
        let array = Array(repeating: repeatedValue, count: count)
        self.init(array)
    }
}

// MARK: - Instance Methods
public extension AtomicArray {

    public mutating func append(_ newElement: AtomicArray.Element) {
        _wait(); defer { _signal() }
        array.append(newElement)
    }

    public mutating func append<S>(contentsOf newElements: S) where S: Sequence, AtomicArray.Element == S.Element {
        _wait(); defer { _signal() }
        array.append(contentsOf: newElements)
    }

    func filter(_ isIncluded: (AtomicArray.Element) throws -> Bool) rethrows -> AtomicArray {
        _wait(); defer { _signal() }
        let subArray = try array.filter(isIncluded)
        return AtomicArray(subArray)
    }

    public mutating func insert(_ newElement: AtomicArray.Element, at i: AtomicArray.Index) {
        _wait(); defer { _signal() }
        array.insert(newElement, at: i)
    }

    mutating func insert<S>(contentsOf newElements: S, at i: AtomicArray.Index) where S: Collection, AtomicArray.Element == S.Element {
        _wait(); defer { _signal() }
        array.insert(contentsOf: newElements, at: i)
    }

    mutating func popLast() -> AtomicArray.Element? {
        _wait(); defer { _signal() }
        return array.popLast()
    }

    @discardableResult mutating func remove(at i: AtomicArray.Index) -> AtomicArray.Element {
        _wait(); defer { _signal() }
        return array.remove(at: i)
    }

    mutating func removeAll() {
        _wait(); defer { _signal() }
        array.removeAll()
    }

    mutating func removeAll(keepingCapacity keepCapacity: Bool) {
        _wait(); defer { _signal() }
        array.removeAll()
    }

    mutating func removeAll(where shouldBeRemoved: (AtomicArray.Element) throws -> Bool) rethrows {
        _wait(); defer { _signal() }
        try array.removeAll(where: shouldBeRemoved)
    }

    @discardableResult mutating func removeFirst() -> AtomicArray.Element {
        _wait(); defer { _signal() }
        return array.removeFirst()
    }

    mutating func removeFirst(_ k: Int) {
        _wait(); defer { _signal() }
        array.removeFirst(k)
    }

    @discardableResult mutating func removeLast() -> AtomicArray.Element {
        _wait(); defer { _signal() }
        return array.removeLast()
    }

    mutating func removeLast(_ k: Int) {
        _wait(); defer { _signal() }
        array.removeLast(k)
    }

    @inlinable public func forEach(_ body: (Element) throws -> Void) rethrows {
        _wait(); defer { _signal() }
        try array.forEach(body)
    }

    mutating func removeFirstIfExist(where shouldBeRemoved: (AtomicArray.Element) throws -> Bool) {
        _wait(); defer { _signal() }
        guard let index = try? array.firstIndex(where: shouldBeRemoved), let index = index else { return }
        array.remove(at: index)
    }

    mutating func removeSubrange(_ bounds: Range<Int>) {
        _wait(); defer { _signal() }
        array.removeSubrange(bounds)
    }

    mutating func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C: Collection, R: RangeExpression, T == C.Element, AtomicArray<Element>.Index == R.Bound {
        _wait(); defer { _signal() }
        array.replaceSubrange(subrange, with: newElements)
    }

    mutating func reserveCapacity(_ n: Int) {
        _wait(); defer { _signal() }
        array.reserveCapacity(n)
    }

    public var count: Int {
        _wait(); defer { _signal() }
        return array.count
    }

    public var isEmpty: Bool {
        _wait(); defer { _signal() }
        return array.isEmpty
    }
}

// MARK: - Get/Set
extension AtomicArray {

    // Single  action
    public func get() -> [T] {
        _wait(); defer { _signal() }
        return array
    }

    public mutating func set(array: [T]) {
        _wait(); defer { _signal() }
        self.array = array
    }

    // Multy actions
    public mutating func get(closure: ([T]) -> Void) {
        _wait(); defer { _signal() }
        closure(array)
    }

    public mutating func set(closure: ([T]) -> ([T])) {
        _wait(); defer { _signal() }
        array = closure(array)
    }
}

// MARK: - Subscripts

extension AtomicArray {

    public subscript(bounds: Range<AtomicArray.Index>) -> AtomicArray.SubSequence {
        _wait(); defer { _signal() }
        return AtomicArray(array[bounds])
    }

    public subscript(bounds: AtomicArray.Index) -> AtomicArray.Element {
        get {
            _wait(); defer { _signal() }
            return array[bounds]
        }
        set(value) {
            _wait(); defer { _signal() }
            array[bounds] = value
        }
    }
}

// MARK: - Operator Functions

extension AtomicArray {

    static func + <Other>(lhs: Other, rhs: AtomicArray) -> AtomicArray where Other: Sequence, AtomicArray.Element == Other.Element {
        return AtomicArray(lhs + rhs.get())
    }

    static func + <Other>(lhs: AtomicArray, rhs: Other) -> AtomicArray where Other: Sequence, AtomicArray.Element == Other.Element {
        return AtomicArray(lhs.get() + rhs)
    }

    static func + <Other>(lhs: AtomicArray, rhs: Other) -> AtomicArray where Other: RangeReplaceableCollection, AtomicArray.Element == Other.Element {
        return AtomicArray(lhs.get() + rhs)
    }

    static func + (lhs: AtomicArray<Element>, rhs: AtomicArray<Element>) -> AtomicArray {
        return AtomicArray(lhs.get() + rhs.get())
    }

    static func += <Other>(lhs: inout AtomicArray, rhs: Other) where Other: Sequence, AtomicArray.Element == Other.Element {
        lhs._wait(); defer { lhs._signal() }
        lhs.array += rhs
    }
}

// MARK: - CustomStringConvertible

extension AtomicArray: CustomStringConvertible {
    public var description: String {
        _wait(); defer { _signal() }
        return "\(array)"
    }
}

// MARK: - Equatable

extension AtomicArray where Element: Equatable {

    func split(separator: Element, maxSplits: Int, omittingEmptySubsequences: Bool) -> [ArraySlice<Element>] {
        _wait(); defer { _signal() }
        return array.split(separator: separator, maxSplits: maxSplits, omittingEmptySubsequences: omittingEmptySubsequences)
    }

    func firstIndex(of element: Element) -> Int? {
        _wait(); defer { _signal() }
        return array.firstIndex(of: element)
    }

    func lastIndex(of element: Element) -> Int? {
        _wait(); defer { _signal() }
        return array.lastIndex(of: element)
    }

    func starts<PossiblePrefix>(with possiblePrefix: PossiblePrefix) -> Bool where PossiblePrefix: Sequence, Element == PossiblePrefix.Element {
        _wait(); defer { _signal() }
        return array.starts(with: possiblePrefix)
    }

    func elementsEqual<OtherSequence>(_ other: OtherSequence) -> Bool where OtherSequence: Sequence, Element == OtherSequence.Element {
        _wait(); defer { _signal() }
        return array.elementsEqual(other)
    }

    func contains(_ element: Element) -> Bool {
        _wait(); defer { _signal() }
        return array.contains(element)
    }

    static func != (lhs: AtomicArray<Element>, rhs: AtomicArray<Element>) -> Bool {
        lhs._wait(); defer { lhs._signal() }
        rhs._wait(); defer { rhs._signal() }
        return lhs.array != rhs.array
    }

    static func == (lhs: AtomicArray<Element>, rhs: AtomicArray<Element>) -> Bool {
        lhs._wait(); defer { lhs._signal() }
        rhs._wait(); defer { rhs._signal() }
        return lhs.array == rhs.array
    }
}
