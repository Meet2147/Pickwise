import Foundation

/// Public, non-secret Polar identifiers. Safe to commit.
enum PolarConfig {
    static let organizationID = ""   // TODO: Polar organization ID (also set POLAR_ORG_ID on the server)
    static let checkoutURL = ""      // TODO: Polar checkout link for the Pickwise Pro subscription
    static let price = "$5.99"
    static let period = "month"
    static let freeComparisons = 5
    static let monthlyComparisons = 50
}
