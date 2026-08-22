import Foundation

/// Public, non-secret Polar identifiers. Safe to commit.
/// (Polar's customer-portal license endpoints are gated by organization ID only.)
enum PolarConfig {
    static let organizationID = ""   // TODO: set to your Polar organization ID
    static let checkoutURL = ""      // TODO: set to your Polar checkout link
    static let price = "$29"
}
