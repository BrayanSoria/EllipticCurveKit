//
//  MontgomeryCurve.swift
//  SwiftCrypto
//
//  Created by Alexander Cyon on 2018-08-02.
//  Copyright © 2018 Alexander Cyon. All rights reserved.
//

import Foundation

///     𝑀: 𝑏𝑦² = 𝑥(𝑥² + 𝑎𝑥 + 1)
/// - Requires: `𝑏(𝑎² - 𝟜) ≠ 𝟘 in 𝔽_𝑝` (or equivalently: `𝑏 ≠ 𝟘` and `𝑎² ≠ 𝟜`)
public struct MontgomeryCurve: ExpressibleByAffineCoordinates, OverGaloisField, CustomStringConvertible {
    public let curveId: SpecificCurve


    /// https://www.hyperelliptic.org/EFD/g1p/auto-montgom-xz.html
    public struct MontgomeryPoint: TwoDimensionalPoint, Equatable {
        public var x: Number
        public var y: Number

        var z: Number {
            get { return y }
            set { y = newValue }
        }

        fileprivate init(x: Number, z: Number, over field: Field) {
                self.x = field.mod(x)
                self.y = field.mod(z)
        }

        fileprivate init(affine: Affine, over field: Field) {
            self.init(
                x: affine.x,
                z: 1,
                over: field)
        }
    }

    public let order: Number
    public let generator: TwoDimensionalPoint

    public let cofactor: Number

    public let galoisField: Field
    private let a: Number
    private let b: Number

    // For Curve25519: a = 486662, thus `a24` = `121666`, in some code bases you might see the number `121666`.
    let a24: Number
    public let equation: TwoDimensionalBalancedEquation

    init?(
        a: Number,
        b: Number,
        galoisField field: Field,
        generator: TwoDimensionalPoint,
        cofactor: Number,
        order: Number,
        curveId: SpecificCurve,
        equation: TwoDimensionalBalancedEquation
        ) {

        guard Requirements.areFullfilled(a: a, b: b, over: field) else { return nil }

        self.a = a
        self.b = b
        self.a24 = field.mod((a + 2)/4)
        self.generator = generator
        self.cofactor = cofactor
        self.galoisField = field
        self.order = order
        self.curveId = curveId
        self.equation = equation
    }

    init?(
        a: Number,
        b: Number,
        parameters: CurveParameterExpressible,
        equation: TwoDimensionalBalancedEquation) {
        self.init(
            a: a,
            b: b,
            galoisField: parameters.galoisField,
            generator: parameters.generator,
            cofactor: parameters.cofactor,
            order: parameters.order,
            curveId: parameters.curveId,
            equation: equation
        )
    }

    struct Requirements {
        static func areFullfilled(a: Number, b: Number, over field: Field) -> Bool {
            return field.mod { b*(a**2 - 4) } != 0
        }
    }

    init?(
        a: Number,
        b: Number,
        parameters: CurveParameterExpressible
        ) {

        let field = parameters.galoisField

        self.init(
            a: a,
            b: b,
            parameters: parameters,
            equation: TwoDimensionalBalancedEquation(lhs: { x in
                field.mod { x * (x**2 + a*x + 1) }
            }, rhs: { y in
                field.mod { b * y**2 }
            }, yFromX: { x in
                field.squareRoots(of: x).map { field.modInverse($0, b) }
            })
        )
    }

    /// Returns a list of the y-coordinates on the curve at given x.
    func getY(fromX x: Number) -> [Number] {
       return equation.getYFrom(x: x)
    }
}

private extension MontgomeryCurve {


    /*
     * Conditionally swap `n1` and `n2`, without leaking information
     * about whether the swap was made or not.
     * Here it is not ok to simply swap the pointers, which whould lead to
     * different memory access patterns when `n1` and `n2`, are used afterwards.
     */
    /// C CODE: https://github.com/wolfeidau/mbedtls/blob/4c7eb1131c185cb44d76d43342398882c5c485db/source/bignum.c#L256-285
    /// PYTHON CODE v1:
//    def swap(P,Q,m):
//        l = max(len(bin(P.X)),len(bin(P.Z)),len(bin(Q.X)),len(bin(Q.Z))) - 2
//        d = (m<<(l+2)) - m
//        notd = ~d
//        px = P.X & d
//        pz = P.Z & d
//        qx = Q.X & notd
//        qz = Q.Z & notd
//        return Point(px+qx,pz+qz)
    //
    /// PYTHON CODE v2: https://gist.github.com/natmchugh/87c03e82a85219e1fb6d#L55-L57
//    def cswap(self, a, b, c):
//        mask = c * self.mask
//        return (a & ~mask) | (b & mask)  , (b & ~mask) | (a & mask)
    //
    /// JAVA CODE: https://github.com/google/tink/blob/master/java/src/main/java/com/google/crypto/tink/subtle/Curve25519.java#L230-L237
//    static void swapConditional(long[] a, long[] b, int iswap) {
//        int swap = -iswap;
//        for (int i = 0; i < Field25519.LIMB_CNT; i++) {
//            int x = swap & (((int) a[i]) ^ ((int) b[i]));
//            a[i] = ((int) a[i]) ^ x;
//            b[i] = ((int) b[i]) ^ x;
//        }
//    }
    func safeConditionalSwap(_ n1: inout Number, and n2: inout Number, `if` shouldSwap: Bool) {
        guard n1 != n2 else { fatalError("n1 and n2 cannot be same number") }
        var XORed = n1
        XORed ^= n2
        let negatedSwap: Number = {
            let signed: Int8 = shouldSwap ? 0x1 : 0x0
            let negated = -signed
            let negatedByte = Byte(negated)
            return Number(data: Data(negatedByte))
        }()
        let swapDiff = negatedSwap & XORed
        n1 ^= swapDiff
        n2 ^= swapDiff
    }

    func affineToMontomery(point: Affine) -> MontgomeryPoint {
        return MontgomeryPoint(affine: point, over: galoisField)
    }

    func montgomeryToAffine(point: MontgomeryPoint) -> Affine {
        let xM = point.x
        let zM = point.z
        guard zM != 0 else { return identityPointAffine }
        let xA = modInverseP(xM, zM)
        guard let zA = equation.getYFrom(x: xA).first else { fatalError() }
        return Affine(x: xA, y: zA)
    }

    func doubleMontgomery(point: MontgomeryPoint) -> MontgomeryPoint {
        let X = point.x
        let Z = point.z
        let ZZ = Z**2
        let XX = X**2
        let x2 = (XX - ZZ) ** 2
        let XZ = X * Z
        let z2 = (4 * XZ) * (XX + (a * XZ) + ZZ)

        return MontgomeryPoint(x: x2, z: z2, over: galoisField)
    }

    /// "mladd-1987-m-3"
    ///  http://www.hyperelliptic.org/EFD/g1p/auto-code/montgom/xz/ladder/mladd-1987-m.op3
    /// - Requires: `𝟜 * 𝑎𝟚𝟜 = 𝑎 + 𝟚` AND `Z1 = D.z = 1`
    /// Inspiration1 in C: https://github.com/wolfeidau/mbedtls/blob/master/source/ecp.c#L1492-L1544
    /// Inspiration2 in Python: https://gist.github.com/natmchugh/87c03e82a85219e1fb6d
    /// Inspiration3 in Python: https://github.com/edufoursans/INF568_ECC/blob/master/src/montgomery.py
    /// Inspiration4 in Java: https://github.com/google/tink/blob/master/java/src/main/java/com/google/crypto/tink/subtle/Curve25519.java#L257-L311
    func ladderAddMontgomeryPoints(R: inout MontgomeryPoint, S: inout MontgomeryPoint, P: MontgomeryPoint, Q: MontgomeryPoint, D: MontgomeryPoint) {

        precondition(4 * a24 == a + 2)
        precondition(D.z == 1)

        let X1 = D.x
        let Z1 = D.z // must be 1

        let X2 = P.x
        let Z2 = P.z

        let X3 = Q.x
        let Z3 = Q.z

        let A, AA, B, BB, E, C, D, DA, CB: Number

        A = X2 + Z2
        AA = A**2
        B = X2 - Z2
        BB = B**2
        E = AA - BB
        C = X3 + Z3
        D = X3 - Z3
        DA = D * A
        CB = C * B
        S.x = Z1 * (DA + CB)**2
        S.z = X1 * (DA - CB)**2
        R.x = AA * BB
        R.z = E * (BB + a24 * E)
    }


    /// Multiplication with Montgomery ladder in x/z coordinates, for curves in Montgomery form
    func ladderMultiplyMontgomery(point P: MontgomeryPoint, by n: Number, deterministicRP rp: MontgomeryPoint? = nil) -> MontgomeryPoint {

        precondition(P.z == 1)

        /* Save P before writing to R, in case P == R */
        let d = P

        /* Set R to zero in modified x/z coordinates */
        var r = MontgomeryPoint(x: 1, z: 0, over: galoisField)

        /* Randomize coordinates of the starting point */
        var rp = rp ?? randomMontgomeryPoint(from: P)
        assert(rp.x < galoisField.modulus)

        /* Loop invariant: R = result so far, RP = R + P */
        /* one past the (zero-based) most significant bit */
        for i in 0..<n.bitWidth-2 {
            let b = n.magnitude[bitAt: i]
            func swapX() {
                safeConditionalSwap(&r.x, and: &rp.x, if: b)
            }
            func swapZ() {
                safeConditionalSwap(&r.z, and: &rp.z, if: b)
            }
            func swap() {
                swapX()
                swapZ()
            }
            /*
             *  if (b) R = 2R + P else R = 2R,
             * which is:
             *  if (b) double_add( RP, R, RP, R )
             *  else   double_add( R, RP, R, RP )
             * but using safe conditional swaps to avoid leaks
             */

            swap()
            ladderAddMontgomeryPoints(R: &r, S: &rp, P: P, Q: rp, D: d)
            swap()
        }

        return normalize(point: r)
    }


    /*
     * Normalize Montgomery x/z coordinates: X = X/Z, Z = 1
     * Cost: 1M + 1I
     */
    func normalize(point: MontgomeryPoint) -> MontgomeryPoint {
        let x = galoisField.modInverse(point.x, point.z)
        return MontgomeryPoint(x: x, z: 1, over: galoisField)
    }

    /*
     * Randomize projective x/z coordinates:
     * (X, Z) -> (`l` X, `l` Z) for random `l`
     * This is sort of the reverse operation of ecp_normalize_mxz().
     *
     * This countermeasure was first suggested in CORON, Jean-S'ebastien. Resistance against differential power analysis
     *     for elliptic curve cryptosystems. In : Cryptographic Hardware and
     *     Embedded Systems. Springer Berlin Heidelberg, 1999. p. 292-302.
     *     <http://link.springer.com/chapter/10.1007/3-540-48059-5_25>.
     * Cost: 2M
     */
    private func randomMontgomeryPoint(from P: MontgomeryPoint) -> MontgomeryPoint {

        let byteCount = (order - 1).as256bitLongData().bytes.count

        var l: Number!

        let p = galoisField.modulus

        while l == nil {
            guard let randomBytes = try? securelyRandomizeBytes(count: byteCount) else { continue }
            var randomNumber = Number(data: Data(bytes: randomBytes))
            guard randomNumber > 1 else { continue }

            while randomNumber > p {
                randomNumber = randomNumber >> 1
            }

            assert(randomNumber < p)
            l = randomNumber
        }

        let x = galoisField.mod { P.x * l }
        let z = galoisField.mod { P.z * l }

        return MontgomeryPoint(x: x, z: z, over: galoisField)

    }

//    /// "dadd-1987-m-3"
//    /// https://www.hyperelliptic.org/EFD/g1p/data/montgom/xz/diffadd/dadd-1987-m-3
//    /// Code: https://www.hyperelliptic.org/EFD/g1p/auto-code/montgom/xz/diffadd/dadd-1987-m-3.op3
//    func diffAddMontgomeryPoints(_ p1: MontgomeryPoint, _ p2: MontgomeryPoint) -> MontgomeryPoint {
//        let X2 = p1.x
//
//        let A, B, C, D, DA, CB, X5, Z5: Number
//
//        A = X2+Z2
//        B = X2-Z2
//        C = X3+Z3
//        D = X3-Z3
//        DA = D*A
//        CB = C*B
//        X5 = Z1*(DA+CB)**2
//        Z5 = X1*(DA-CB)**2
//    }
}

public extension MontgomeryCurve {
    static let identityPointAffine: Affine = .infinity
}

public extension MontgomeryCurve {
    var description: String {
        return "MontgomeryCurve"
    }
}

public extension MontgomeryCurve {

    func isIdentity<P>(point: P) -> Bool where P : Point {
        fatalError()
    }

    func addAffine(point p1: Affine, to p2: Affine) -> Affine {
        fatalError()
    }

    func doubleAffine(point: Affine) -> Affine {
        fatalError()
    }

    func invertAffine(point: Affine) -> Affine {
        fatalError()
    }

     func containsPoint<P>(_ point: P) -> Bool where P: Point {
        fatalError()
    }

}
