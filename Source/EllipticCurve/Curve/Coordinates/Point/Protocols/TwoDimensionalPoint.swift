//
//  TwoDimensionalPoint.swift
//  EllipticCurveKit
//
//  Created by Alexander Cyon on 2018-08-02.
//  Copyright © 2018 Alexander Cyon. All rights reserved.
//

import Foundation


public protocol TwoDimensionalPoint: Point {
    var x: Number { get }
    var y: Number { get }
}

public extension TwoDimensionalPoint {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.x == rhs.x &&
            lhs.y == rhs.y
    }

    func asAnyTwoDimensionalPoint() -> AnyTwoDimensionalPoint {
        return AnyTwoDimensionalPoint(point: self)
    }
}


public struct AnyTwoDimensionalPoint: TwoDimensionalPoint, Equatable {
    public var x: Number
    public var y: Number

    public init(x: Number, y: Number) {
        self.x = x
        self.y = y
    }
}

public extension AnyTwoDimensionalPoint {
    public init<P>(point: P) where P: TwoDimensionalPoint {
        self.init(x: point.x, y: point.y)
    }
}
