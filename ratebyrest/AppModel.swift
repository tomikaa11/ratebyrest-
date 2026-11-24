import Foundation
import Observation

@Observable
final class AppModel {
    var countryCode = "HU"
    var userID: UUID?
    var userEmail: String?
    var schema: SchemaState = .unknown
    var favorite: Favorite?
    private var appliedFavoriteCountry = false

    var country: Country {
        CountryCatalog.country(code: countryCode)
    }

    var isSignedIn: Bool { userID != nil }

    func refreshSession() async {
        let session = await Backend.refreshSession()
        userID = session?.id
        userEmail = session?.email
        if userID == nil {
            favorite = nil
            return
        }
        if let stored = try? await Backend.fetchFavorite() {
            favorite = stored
            if !appliedFavoriteCountry, let code = stored.countryCode, CountryCatalog.all.contains(where: { $0.code == code }) {
                countryCode = code
                appliedFavoriteCountry = true
            }
        }
    }

    func saveFavoriteCountry(_ code: String) async throws {
        favorite = try await Backend.saveFavoriteCountry(code, keeping: favorite)
        appliedFavoriteCountry = true
    }

    func saveFavoriteRestaurant(_ place: RestaurantPlace) async throws {
        favorite = try await Backend.saveFavoriteRestaurant(place, keeping: favorite)
    }

    func refreshSchema() async {
        schema = await Backend.pingSchema()
    }
}
