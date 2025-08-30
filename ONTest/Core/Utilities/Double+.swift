//
//  Double+.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import Foundation

extension Double {
    func rounded(to digits: Int) -> Double {
        let p = pow(10.0, Double(digits))
        return (self * p).rounded() / p
    }
}

extension Double {
    var oddsDisplay: String {
        guard isFinite else { return "—" }
        return String(format: "%.2f", self)
    }
}
