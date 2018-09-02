//
//  Equation+BigInt+IntegerNumberExpressible.swift
//  EllipticCurveKit
//
//  Created by Alexander Cyon on 2018-08-31.
//  Copyright © 2018 Alexander Cyon. All rights reserved.
//

import Foundation

import EquationKit
import BigInt

extension BigInt: IntegerNumberExpressible {}
public extension BigInt {
    var isNegative: Bool {
        return self < 0
    }

    var isPositive: Bool {
        return self > 0
    }

    func absolute() -> BigInt {
        return BigInt(sign: .plus, magnitude: magnitude)
    }

    func raised(to exponent: BigInt) -> BigInt {
        guard exponent.bitWidth <= Int.bitWidth else { fatalError("to big") }
        return power(Int(exponent))
    }

    static var zero: BigInt {
        return 0
    }

    static var one: BigInt {
        return 1
    }

    var shortFormat: String {
        return description
    }

    func negated() -> BigInt {
        return BigInt(sign: sign == .plus ? .minus : .plus, magnitude: magnitude)
    }
}
