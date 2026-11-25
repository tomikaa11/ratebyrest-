import Foundation

struct DailyPick: Hashable {
    let place: RestaurantPlace
    let dishName: String
    let voteCount: Int
    let reason: String
    let isEstimate: Bool
}

enum MenuEstimate {
    static func price(for name: String) -> Int {
        let steps = [1_890, 2_490, 2_890, 3_490, 3_990, 4_490, 5_290]
        var hash = 0
        for byte in name.lowercased().utf8 {
            hash = (hash &* 31 &+ Int(byte)) & 0x7fff_ffff
        }
        return steps[hash % steps.count]
    }

    static func priceText(for name: String) -> String {
        let value = price(for: name)
        let formatted = value.formatted(.number.locale(Locale(identifier: "en_US")))
        return "\(formatted) Ft"
    }

    static func signatureDish(for place: RestaurantPlace) -> String {
        let options = [
            "House burger",
            "Chef's pasta",
            "Grilled chicken plate",
            "Seasonal bowl",
            "Signature steak",
            "Crispy sandwich"
        ]
        var hash = 0
        for byte in place.placeKey.utf8 {
            hash = (hash &* 17 &+ Int(byte)) & 0x7fff_ffff
        }
        return options[hash % options.count]
    }

    static func blurb(for dishName: String, place: RestaurantPlace) -> String {
        "A \(dishName.lowercased()) at \(place.name). A straightforward pick in \(place.city) when you don't want to scroll."
    }

    static func pick(place: RestaurantPlace, dishes: [DishRank], stats: RestaurantStats?) -> DailyPick {
        if let dish = dishes.max(by: { $0.votes < $1.votes }) {
            let reason: String
            if let stats {
                let average = stats.average.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
                reason = "\(dish.votes) votes, and the place is rated \(average) from \(stats.count) reviews."
            } else {
                reason = "\(dish.votes) people voted for this dish nearby."
            }
            return DailyPick(
                place: place,
                dishName: dish.name,
                voteCount: dish.votes,
                reason: reason,
                isEstimate: false
            )
        }
        let dishName = signatureDish(for: place)
        let reason: String
        if let stats {
            let average = stats.average.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
            reason = "No dish votes yet. \(place.name) is rated \(average) from \(stats.count) reviews, so this is a starter suggestion."
        } else {
            reason = "No dish votes yet. A starter suggestion from a nearby place in \(place.city)."
        }
        return DailyPick(
            place: place,
            dishName: dishName,
            voteCount: 0,
            reason: reason,
            isEstimate: true
        )
    }
}
