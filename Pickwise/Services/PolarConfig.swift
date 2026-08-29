import Foundation

/// Public, non-secret Polar identifiers. Safe to commit.
enum PolarConfig {
    static let organizationID = "36a24ca3-4af7-4c52-8fac-7243fb07019a"
    static let checkoutURL = ""      // TODO: Polar checkout link for the Pickwise Pro subscription
    static let price = "$5.99"
    static let period = "month"
    static let freeComparisons = 5
    static let monthlyComparisons = 50
}
