import Foundation

public struct CurrencyHelper {
    public static let shared = CurrencyHelper()

    private let standardFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private let wholeRupeeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private let exactTwoDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    public func format(_ amount: Decimal, forceDecimals: Bool = false) -> String {
        let nsNumber = NSDecimalNumber(decimal: amount)
        if forceDecimals {
            return exactTwoDecimalFormatter.string(from: nsNumber) ?? "₹\(nsNumber.stringValue)"
        }
        return standardFormatter.string(from: nsNumber) ?? "₹\(nsNumber.stringValue)"
    }

    public func formatWhole(_ amount: Decimal) -> String {
        let nsNumber = NSDecimalNumber(decimal: amount)
        return wholeRupeeFormatter.string(from: nsNumber) ?? "₹\(nsNumber.intValue)"
    }

    public func format(_ amount: Double, forceDecimals: Bool = false) -> String {
        return format(Decimal(amount), forceDecimals: forceDecimals)
    }

    public func parseDecimal(from string: String) -> Decimal? {
        let sanitized = string
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle commas in Indian formatting (e.g. 1,50,000.50 -> 150000.50)
        // If there is a dot as decimal separator, strip commas
        if sanitized.contains(".") {
            let withoutCommas = sanitized.replacingOccurrences(of: ",", with: "")
            return Decimal(string: withoutCommas)
        } else if sanitized.contains(",") {
            // Check if comma might be used as a decimal separator (European) or grouping
            let parts = sanitized.split(separator: ",")
            if parts.count == 2 && parts[1].count <= 2 {
                // Probable decimal comma
                let standardized = sanitized.replacingOccurrences(of: ",", with: ".")
                return Decimal(string: standardized)
            } else {
                let withoutCommas = sanitized.replacingOccurrences(of: ",", with: "")
                return Decimal(string: withoutCommas)
            }
        }
        return Decimal(string: sanitized)
    }
}
