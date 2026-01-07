import Foundation

/// DoorDash integration for reward fulfillment
/// Uses DoorDash Gift Card API or direct ordering
@MainActor
class DoorDashService: ObservableObject {
    static let shared = DoorDashService()

    @Published var isProcessing = false
    @Published var lastError: String?

    // In production, these would be from secure storage
    private var apiKey: String?
    private var merchantId: String?

    // MARK: - Gift Card Delivery

    /// Send a DoorDash gift card to an employee's email
    func sendGiftCard(
        amount: Double,
        recipientEmail: String,
        recipientName: String,
        senderName: String,
        message: String
    ) async throws -> GiftCardResult {
        isProcessing = true
        defer { isProcessing = false }

        // For MVP: Generate a gift card purchase link
        // In production: Use DoorDash Gift Card API

        // Option 1: Direct the manager to purchase a gift card
        let purchaseURL = "https://www.doordash.com/gift-cards/"

        // Option 2: Use Tremendous or similar gift card API
        // This allows programmatic gift card delivery

        // For now, create a pending reward that manager fulfills
        return GiftCardResult(
            success: true,
            giftCardCode: nil, // Would be populated by API
            purchaseURL: purchaseURL,
            amount: amount,
            recipientEmail: recipientEmail,
            message: "Gift card request created. Manager will fulfill via \(purchaseURL)"
        )
    }

    /// For teams with DoorDash for Work - order directly
    func orderForEmployee(
        employeeAddress: String,
        maxAmount: Double,
        deliveryInstructions: String?
    ) async throws -> OrderResult {
        isProcessing = true
        defer { isProcessing = false }

        // DoorDash Drive API integration
        // This would require business account setup
        let driveOrderURL = "https://www.doordash.com/drive/"

        return OrderResult(
            success: true,
            orderId: nil,
            trackingURL: nil,
            setupURL: driveOrderURL,
            message: "DoorDash for Work integration available at \(driveOrderURL)"
        )
    }

    // MARK: - Manager Configuration

    /// Configure DoorDash API credentials (for enterprises)
    func configure(apiKey: String, merchantId: String) {
        self.apiKey = apiKey
        self.merchantId = merchantId
    }

    /// Check if DoorDash is configured for automatic fulfillment
    var isConfigured: Bool {
        apiKey != nil && merchantId != nil
    }

    // MARK: - Convenience Methods

    /// Generate a shareable DoorDash link with credit
    func generateOrderLink(amount: Double, promoCode: String?) -> String {
        var link = "https://www.doordash.com/"
        if let promo = promoCode {
            link += "?promo=\(promo)"
        }
        return link
    }
}

// MARK: - Result Types

struct GiftCardResult {
    let success: Bool
    let giftCardCode: String?
    let purchaseURL: String
    let amount: Double
    let recipientEmail: String
    let message: String
}

struct OrderResult {
    let success: Bool
    let orderId: String?
    let trackingURL: String?
    let setupURL: String?
    let message: String
}

// MARK: - Integration with Rewards System

extension RewardsService {
    /// Fulfill a DoorDash reward
    func fulfillDoorDashReward(
        _ redemption: RewardRedemption,
        recipientEmail: String,
        recipientName: String,
        amount: Double
    ) async {
        do {
            let result = try await DoorDashService.shared.sendGiftCard(
                amount: amount,
                recipientEmail: recipientEmail,
                recipientName: recipientName,
                senderName: "Your Manager",
                message: "Great work! Enjoy your meal on us. 🎉"
            )

            if result.success {
                // Mark as fulfilled in the rewards system
                fulfillRedemption(redemption)

                // Log to conversation
                let message = "DoorDash reward sent to \(recipientName)! $\(Int(amount)) credit for completing tasks."
                ConversationService.shared.addAssistantMessage(message)
            }
        } catch {
            print("❌ Failed to fulfill DoorDash reward: \(error)")
        }
    }
}

// MARK: - Third-Party Gift Card Services

/// For production, integrate with gift card APIs like:
/// - Tremendous (tremendous.com) - Universal gift cards
/// - Tango Card (tangocard.com) - Gift card as a service
/// - Runa (runa.io) - Digital rewards platform
///
/// These allow:
/// 1. Bulk gift card purchases at discount
/// 2. API-based delivery to recipient email
/// 3. Support for DoorDash, Uber Eats, Amazon, etc.
/// 4. Automatic fulfillment without manager intervention

struct TremendousIntegration {
    // Example integration structure
    static let apiEndpoint = "https://testflight.tremendous.com/api/v2/"

    struct Campaign: Codable {
        let id: String
        let name: String
        let products: [String] // ["DOORDASH", "UBEREATS", "AMAZON"]
    }

    struct Order: Codable {
        let campaignId: String
        let recipients: [Recipient]
    }

    struct Recipient: Codable {
        let name: String
        let email: String
        let value: Int // cents
        let products: [String]
        let delivery: DeliveryMethod

        enum DeliveryMethod: String, Codable {
            case email = "EMAIL"
            case link = "LINK"
        }
    }
}
