import Foundation

struct TierProgress: Equatable, Sendable {
    var ratingCount = 0
    var goodRatingCount = 0
    var favoriteCountryCount = 0

    var level: Int {
        if ratingCount >= 40 && goodRatingCount >= 20 { return 4 }
        if ratingCount >= 20 && goodRatingCount >= 10 { return 3 }
        if ratingCount >= 10 && goodRatingCount >= 5 && favoriteCountryCount >= 3 { return 2 }
        if ratingCount >= 3 && favoriteCountryCount >= 1 { return 1 }
        return 0
    }

    var title: String {
        switch level {
        case 0: "Starter"
        case 1: "Level 1"
        case 2: "Level 2"
        case 3: "Level 3"
        default: "Level 4"
        }
    }

    /// Bejelentkezve a kezdő is értékelhet és egy országot menthet, különben a létra nem indul el.
    var maxFavoriteCountries: Int {
        switch level {
        case 0: 1
        case 1: 3
        default: 10
        }
    }

    var canAddDish: Bool { level >= 3 }
    var canAddRestaurant: Bool { level >= 4 }

    var nextHint: String {
        switch level {
        case 0:
            let ratingsLeft = max(0, 3 - ratingCount)
            let favoritesLeft = max(0, 1 - favoriteCountryCount)
            return "\(ratingsLeft) more ratings and \(favoritesLeft) favorite country to reach level 1. You can rate now and save 1 country."
        case 1:
            let ratingsLeft = max(0, 10 - ratingCount)
            let goodLeft = max(0, 5 - goodRatingCount)
            let favoritesLeft = max(0, 3 - favoriteCountryCount)
            return "\(ratingsLeft) more ratings, \(goodLeft) of them at least 4 stars, and \(favoritesLeft) favorite countries to reach level 2. You can save 3 countries now."
        case 2:
            let ratingsLeft = max(0, 20 - ratingCount)
            let goodLeft = max(0, 10 - goodRatingCount)
            return "\(ratingsLeft) more ratings, \(goodLeft) of them at least 4 stars, to reach level 3. Then you can add dishes. You can save 10 countries now."
        case 3:
            let ratingsLeft = max(0, 40 - ratingCount)
            let goodLeft = max(0, 20 - goodRatingCount)
            return "\(ratingsLeft) more ratings, \(goodLeft) of them at least 4 stars, to reach level 4. Then you can add your own restaurant."
        default:
            return "You have every right: ratings, 10 favorite countries, dishes, and your own restaurant."
        }
    }
}
