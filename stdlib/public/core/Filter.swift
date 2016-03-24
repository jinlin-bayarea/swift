//===--- Filter.swift -----------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// An iterator over the elements traversed by some base iterator that also
/// satisfy a given predicate.
///
/// - Note: This is the associated `Iterator` of `LazyFilterSequence`
/// and `LazyFilterCollection`.
public struct LazyFilterIterator<
  Base : IteratorProtocol
> : IteratorProtocol, Sequence {
  /// Advances to the next element and returns it, or `nil` if no next
  /// element exists.
  ///
  /// - Precondition: `next()` has not been applied to a copy of `self`
  ///   since the copy was made, and no preceding call to `self.next()`
  ///   has returned `nil`.
  public mutating func next() -> Base.Element? {
    while let n = _base.next() {
      if _predicate(n) {
        return n
      }
    }
    return nil
  }

  /// Creates an instance that produces the elements `x` of `base`
  /// for which `predicate(x) == true`.
  internal init(
    _base: Base,
    whereElementsSatisfy predicate: (Base.Element) -> Bool
  ) {
    self._base = _base
    self._predicate = predicate
  }

  /// The underlying iterator whose elements are being filtered.
  public var base: Base { return _base }

  internal var _base: Base
  
  /// The predicate used to determine which elements produced by
  /// `base` are also produced by `self`.
  internal let _predicate: (Base.Element) -> Bool
}

/// A sequence whose elements consist of the elements of some base
/// sequence that also satisfy a given predicate.
///
/// - Note: `s.lazy.filter { ... }`, for an arbitrary sequence `s`,
///   is a `LazyFilterSequence`.
public struct LazyFilterSequence<Base : Sequence>
  : LazySequenceProtocol {
  
  /// Returns an iterator over the elements of this sequence.
  ///
  /// - Complexity: O(1).
  public func makeIterator() -> LazyFilterIterator<Base.Iterator> {
    return LazyFilterIterator(
      _base: base.makeIterator(), whereElementsSatisfy: _include)
  }

  /// Creates an instance consisting of the elements `x` of `base` for
  /// which `predicate(x) == true`.
  public // @testable
  init(
    _base base: Base,
    whereElementsSatisfy predicate: (Base.Iterator.Element) -> Bool
  ) {
    self.base = base
    self._include = predicate
  }

  /// The underlying sequence whose elements are being filtered
  public let base: Base

  /// The predicate used to determine which elements of `base` are
  /// also elements of `self`.
  internal let _include: (Base.Iterator.Element) -> Bool
}

/// The `Index` used for subscripting a `LazyFilterCollection`.
///
/// The positions of a `LazyFilterIndex` correspond to those positions
/// `p` in its underlying collection `c` such that `c[p]`
/// satisfies the predicate with which the `LazyFilterIndex` was
/// initialized.
/// 
/// - Note: The performance of advancing a `LazyFilterIndex`
///   depends on how sparsely the filtering predicate is satisfied,
///   and may not offer the usual performance given by models of
///   `Collection`.
public struct LazyFilterIndex<Base : Collection> : Comparable {

  /// The position corresponding to `self` in the underlying collection.
  public let base: Base.Index
}

@warn_unused_result
public func == <Base : Collection>(
  lhs: LazyFilterIndex<Base>,
  rhs: LazyFilterIndex<Base>
) -> Bool {
  return lhs.base == rhs.base
}

@warn_unused_result
public func != <Base : Collection>(
  lhs: LazyFilterIndex<Base>,
  rhs: LazyFilterIndex<Base>
) -> Bool {
  return lhs.base != rhs.base
}

@warn_unused_result
public func < <Base : Collection>(
  lhs: LazyFilterIndex<Base>,
  rhs: LazyFilterIndex<Base>
) -> Bool {
  return lhs.base < rhs.base
}

@warn_unused_result
public func <= <Base : Collection>(
  lhs: LazyFilterIndex<Base>,
  rhs: LazyFilterIndex<Base>
) -> Bool {
  return lhs.base <= rhs.base
}

@warn_unused_result
public func >= <Base : Collection>(
  lhs: LazyFilterIndex<Base>,
  rhs: LazyFilterIndex<Base>
) -> Bool {
  return lhs.base >= rhs.base
}

@warn_unused_result
public func > <Base : Collection>(
  lhs: LazyFilterIndex<Base>,
  rhs: LazyFilterIndex<Base>
) -> Bool {
  return lhs.base > rhs.base
}

/// A lazy `Collection` wrapper that includes the elements of an
/// underlying collection that satisfy a predicate.
///
/// - Note: The performance of accessing `startIndex`, `first`, any methods
///   that depend on `startIndex`, or of advancing a `LazyFilterIndex` depends
///   on how sparsely the filtering predicate is satisfied, and may not offer
///   the usual performance given by `Collection`. Be aware, therefore, that 
///   general operations on `LazyFilterCollection` instances may not have the
///   documented complexity.
public struct LazyFilterCollection<
  Base : Collection
> : LazyCollectionProtocol {

  /// A type that represents a valid position in the collection.
  ///
  /// Valid indices consist of the position of every element and a
  /// "past the end" position that's not valid for use as a subscript.
  public typealias Index = LazyFilterIndex<Base>

  public typealias IndexDistance = Base.IndexDistance

  /// Construct an instance containing the elements of `base` that
  /// satisfy `predicate`.
  public // @testable
  init(
    _base: Base,
    whereElementsSatisfy predicate: (Base.Iterator.Element) -> Bool
  ) {
    self._base = _base
    self._predicate = predicate
  }

  /// The position of the first element in a non-empty collection.
  ///
  /// In an empty collection, `startIndex == endIndex`.
  ///
  /// - Complexity: O(N), where N is the ratio between unfiltered and
  ///   filtered collection counts.
  public var startIndex: Index {
    return LazyFilterIndex(base: _nextFiltered(_base.startIndex))
  }

  /// The collection's "past the end" position.
  ///
  /// `endIndex` is not a valid argument to `subscript`, and is always
  /// reachable from `startIndex` by zero or more applications of
  /// `successor()`.
  ///
  /// - Complexity: O(1).
  public var endIndex: Index {
    return LazyFilterIndex(base: _base.endIndex)
  }

  // TODO: swift-3-indexing-model - add docs
  @warn_unused_result
  public func successor(of i: Index) -> Index {
    // TODO: swift-3-indexing-model: _failEarlyRangeCheck i?
    return LazyFilterIndex(base: _nextFiltered(i.base))
  }

  // TODO: swift-3-indexing-model - add docs
  @warn_unused_result
  public func advance(i: Index, by n: IndexDistance) -> Index {
    _precondition(n >= 0,
      "Only BidirectionalCollections can be advanced by a negative amount")
    // TODO: swift-3-indexing-model: _failEarlyRangeCheck i?

    var index = i.base
    for _ in 0..<n {
      if _nextFilteredInPlace(&index) {
        break
      }
    }
    return LazyFilterIndex(base: index)
  }

  // TODO: swift-3-indexing-model - add docs
  @warn_unused_result
  public func advance(i: Index, by n: IndexDistance, limit: Index) -> Index {
    _precondition(n >= 0,
      "Only BidirectionalCollections can be advanced by a negative amount")
    // TODO: swift-3-indexing-model: _failEarlyRangeCheck i?

    var index = i.base
    for _ in 0..<n {
      if _nextFilteredInPlace(&index, limit: limit.base) {
        break
      }
    }
    return LazyFilterIndex(base: index)
  }

  /// Returns the next `index` of an element that `self._predicate` matches
  /// otherwise `self._base.endIndex`
  @inline(__always)
  internal func _nextFiltered(index: Base.Index) -> Base.Index {
    var index = index
    _nextFilteredInPlace(&index)
    return index
  }

  /// Advances `index` until one of the following:
  ///   `self._predicate` matches on related element
  ///   `index` equals `self._base.endIndex`
  /// Returns `true` iff at `self._base.endIndex`
  @inline(__always)
  internal func _nextFilteredInPlace(index: inout Base.Index) -> Bool {
    while index != _base.endIndex {
      if _predicate(_base[index]) {
        return false
      }
      _base.formSuccessor(&index)
    }
    return true
  }

  /// Advances `index` until one of the following:
  ///   `self._predicate` matches on related element
  ///   `index` equals `self._base.endIndex`
  ///   `index` equals `limit`
  /// Returns `true` iff at `self._base.endIndex` or `limit`
  @inline(__always)
  internal func _nextFilteredInPlace(
    index: inout Base.Index,
    limit: Base.Index
  ) -> Bool {
    while index != limit && index != _base.endIndex {
      if _predicate(_base[index]) {
        return false
      }
      _base.formSuccessor(&index)
    }
    return true
  }

  /// Access the element at `position`.
  ///
  /// - Precondition: `position` is a valid position in `self` and
  /// `position != endIndex`.
  public subscript(position: Index) -> Base.Iterator.Element {
    return _base[position.base]
  }

  /// Returns an iterator over the elements of this sequence.
  ///
  /// - Complexity: O(1).
  public func makeIterator() -> LazyFilterIterator<Base.Iterator> {
    return LazyFilterIterator(
      _base: _base.makeIterator(), whereElementsSatisfy: _predicate)
  }

  var _base: Base
  let _predicate: (Base.Iterator.Element) -> Bool
}

extension LazySequenceProtocol {
  /// Returns the elements of `self` that satisfy `predicate`.
  ///
  /// - Note: The elements of the result are computed on-demand, as
  ///   the result is used. No buffering storage is allocated and each
  ///   traversal step invokes `predicate` on one or more underlying
  ///   elements.
  @warn_unused_result
  public func filter(
    predicate: (Elements.Iterator.Element) -> Bool
  ) -> LazyFilterSequence<Self.Elements> {
    return LazyFilterSequence(
      _base: self.elements, whereElementsSatisfy: predicate)
  }
}

extension LazyCollectionProtocol {
  /// Returns the elements of `self` that satisfy `predicate`.
  ///
  /// - Note: The elements of the result are computed on-demand, as
  ///   the result is used. No buffering storage is allocated and each
  ///   traversal step invokes `predicate` on one or more underlying
  ///   elements.
  @warn_unused_result
  public func filter(
    predicate: (Elements.Iterator.Element) -> Bool
  ) -> LazyFilterCollection<Self.Elements> {
    return LazyFilterCollection(
      _base: self.elements, whereElementsSatisfy: predicate)
  }
}

@available(*, unavailable, renamed: "LazyFilterIterator")
public struct LazyFilterGenerator<Base : IteratorProtocol> {}

extension LazyFilterIterator {
  @available(*, unavailable, message: "use '.lazy.filter' on the sequence")
  public init(
    _ base: Base,
    whereElementsSatisfy predicate: (Base.Element) -> Bool
  ) {
    fatalError("unavailable function can't be called")
  }
}

extension LazyFilterSequence {
  @available(*, unavailable, message: "use '.lazy.filter' on the sequence")
  public init(
    _ base: Base,
    whereElementsSatisfy predicate: (Base.Iterator.Element) -> Bool
  ) {
    fatalError("unavailable function can't be called")
  }

  @available(*, unavailable, renamed: "iterator")
  public func generate() -> LazyFilterIterator<Base.Iterator> {
    fatalError("unavailable function can't be called")
  }
}

extension LazyFilterCollection {
  @available(*, unavailable, message: "use '.lazy.filter' on the collection")
  public init(
    _ base: Base,
    whereElementsSatisfy predicate: (Base.Iterator.Element) -> Bool
  ) {
    fatalError("unavailable function can't be called")
  }

  @available(*, unavailable, renamed: "iterator")
  public func generate() -> LazyFilterIterator<Base.Iterator> {
    fatalError("unavailable function can't be called")
  }
}

// ${'Local Variables'}:
// eval: (read-only-mode 1)
// End:
