//
//  DateFormatter+.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import Foundation

extension DateFormatter {
    static let match: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return dateFormatter
    }()
}
