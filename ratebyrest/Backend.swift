import Auth
import Foundation
import PostgREST
import Supabase

enum SchemaState: Equatable {
    case unknown
    case ready
    case missing
}

enum BackendError: LocalizedError {
    case notSignedIn
    case schemaMissing
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            "Az értékeléshez jelentkezz be a Fiók lapon."
        case .schemaMissing:
            "A Supabase táblák még hiányoznak. Az SQL Editorban futtasd a projekt supabase/schema.sql fájlját."
        case .message(let text):
            text
        }
    }
}

enum SupabaseConfig {
    static let url = URL(string: "https://tmwihyxxajrhoxzfddoz.supabase.co")!
    static let publishableKey = "sb_publishable_wg2ToPzfempenD-OLbDfyA_BzhuCj-3"
}

enum Backend {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.publishableKey
    )

    static func refreshSession() async -> (id: UUID, email: String?)? {
        do {
            let session = try await client.auth.session
            return (session.user.id, session.user.email)
        } catch {
            return nil
        }
    }

    static func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    /// Igaz, ha a fiók azonnal használható. Hamis, ha előbb meg kell erősíteni az e-mailt.
    static func signUp(email: String, password: String) async throws -> Bool {
        let response = try await client.auth.signUp(email: email, password: password)
        return response.session != nil
    }

    static func signOut() async throws {
        try await client.auth.signOut()
    }

    static func deleteAccount() async throws {
        do {
            try await client.rpc("delete_own_account").execute()
        } catch {
            throw map(error)
        }
        try await client.auth.signOut()
    }

    static func pingSchema() async -> SchemaState {
        do {
            let _: [FavoriteIDRow] = try await client
                .from("favorites")
                .select("user_id")
                .limit(1)
                .execute()
                .value
            return .ready
        } catch {
            return isMissingSchema(error) ? .missing : .unknown
        }
    }

    static func fetchFavorite() async throws -> Favorite? {
        guard let userID = await refreshSession()?.id else { return nil }
        do {
            let rows: [FavoriteRow] = try await client
                .from("favorites")
                .select()
                .eq("user_id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value
            return rows.first?.favorite
        } catch {
            throw map(error)
        }
    }

    static func saveFavoriteCountry(_ code: String, keeping current: Favorite?) async throws -> Favorite {
        let next = Favorite(
            countryCode: code,
            placeKey: current?.placeKey,
            name: current?.name,
            city: current?.city,
            countryName: current?.countryName,
            address: current?.address,
            latitude: current?.latitude,
            longitude: current?.longitude
        )
        try await upsert(next)
        return next
    }

    static func saveFavoriteRestaurant(_ place: RestaurantPlace, keeping current: Favorite?) async throws -> Favorite {
        let next = Favorite(
            countryCode: current?.countryCode ?? place.countryCode,
            placeKey: place.placeKey,
            name: place.name,
            city: place.city,
            countryName: place.countryName,
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude
        )
        try await upsert(next)
        return next
    }

    private static func upsert(_ favorite: Favorite) async throws {
        guard let userID = await refreshSession()?.id else {
            throw BackendError.notSignedIn
        }
        let payload = FavoriteWrite(userID: userID, favorite: favorite)
        do {
            try await client
                .from("favorites")
                .upsert(payload, onConflict: "user_id", returning: .minimal)
                .execute()
        } catch {
            throw map(error)
        }
    }

    static func restaurant(placeKey: String) async throws -> RestaurantRow? {
        do {
            let rows: [RestaurantRow] = try await client
                .from("restaurants")
                .select()
                .eq("place_key", value: placeKey)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw map(error)
        }
    }

    static func ensureRestaurant(_ place: RestaurantPlace) async throws -> RestaurantRow {
        guard let userID = await refreshSession()?.id else {
            throw BackendError.notSignedIn
        }
        _ = userID
        if let existing = try await restaurant(placeKey: place.placeKey) {
            return existing
        }
        let payload = RestaurantInsert(
            placeKey: place.placeKey,
            name: place.name,
            city: place.city,
            countryCode: place.countryCode,
            countryName: place.countryName,
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude
        )
        do {
            let created: [RestaurantRow] = try await client
                .from("restaurants")
                .insert(payload)
                .select()
                .execute()
                .value
            if let row = created.first {
                return row
            }
        } catch {
            if let existing = try? await restaurant(placeKey: place.placeKey) {
                return existing
            }
            throw map(error)
        }
        throw BackendError.message("Az éttermet nem sikerült menteni.")
    }

    static func ratings(restaurantID: UUID) async throws -> [RatingRow] {
        do {
            let rows: [RatingRow] = try await client
                .from("ratings")
                .select()
                .eq("restaurant_id", value: restaurantID.uuidString)
                .execute()
                .value
            return rows
        } catch {
            throw map(error)
        }
    }

    static func dishes(restaurantID: UUID) async throws -> [DishRow] {
        do {
            let rows: [DishRow] = try await client
                .from("dishes")
                .select()
                .eq("restaurant_id", value: restaurantID.uuidString)
                .execute()
                .value
            return rows
        } catch {
            throw map(error)
        }
    }

    static func saveRating(restaurantID: UUID, stars: Int) async throws {
        guard let userID = await refreshSession()?.id else {
            throw BackendError.notSignedIn
        }
        let payload = RatingInsert(restaurantID: restaurantID, userID: userID, stars: stars)
        do {
            try await client
                .from("ratings")
                .upsert(payload, onConflict: "restaurant_id,user_id", returning: .minimal)
                .execute()
        } catch {
            throw map(error)
        }
    }

    static func addDish(restaurantID: UUID, name: String) async throws {
        guard let userID = await refreshSession()?.id else {
            throw BackendError.notSignedIn
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else {
            throw BackendError.message("Az étel neve 1–80 karakter lehet.")
        }
        let payload = DishInsert(restaurantID: restaurantID, userID: userID, name: trimmed)
        do {
            try await client
                .from("dishes")
                .insert(payload, returning: .minimal)
                .execute()
        } catch {
            let text = String(describing: error).lowercased()
            if text.contains("duplicate") || text.contains("23505") || text.contains("dishes_one_vote") {
                throw BackendError.message("Ezt az ételt már hozzáadtad.")
            }
            throw map(error)
        }
    }

    static func deleteDish(id: UUID) async throws {
        guard let userID = await refreshSession()?.id else {
            throw BackendError.notSignedIn
        }
        do {
            try await client
                .from("dishes")
                .delete(returning: .minimal)
                .eq("id", value: id.uuidString)
                .eq("user_id", value: userID.uuidString)
                .execute()
        } catch {
            throw map(error)
        }
    }

    static func report(restaurantID: UUID, dishID: UUID?, reason: String) async throws {
        guard let userID = await refreshSession()?.id else {
            throw BackendError.notSignedIn
        }
        let payload = ReportInsert(
            userID: userID,
            restaurantID: restaurantID,
            dishID: dishID,
            reason: reason
        )
        do {
            try await client
                .from("reports")
                .insert(payload, returning: .minimal)
                .execute()
        } catch {
            throw map(error)
        }
    }

    static func stats(for places: [RestaurantPlace]) async -> [String: RestaurantStats] {
        let keys = places.map(\.placeKey)
        guard !keys.isEmpty else { return [:] }
        do {
            let restaurants: [RestaurantRow] = try await client
                .from("restaurants")
                .select()
                .in("place_key", values: keys)
                .execute()
                .value
            guard !restaurants.isEmpty else { return [:] }
            let ids = restaurants.map(\.id.uuidString)
            let ratings: [RatingRow] = try await client
                .from("ratings")
                .select()
                .in("restaurant_id", values: ids)
                .execute()
                .value
            var byRestaurant: [UUID: [Int]] = [:]
            for rating in ratings {
                byRestaurant[rating.restaurantID, default: []].append(rating.stars)
            }
            var result: [String: RestaurantStats] = [:]
            for restaurant in restaurants {
                let stars = byRestaurant[restaurant.id] ?? []
                guard !stars.isEmpty else { continue }
                let total = stars.reduce(0, +)
                result[restaurant.placeKey] = RestaurantStats(
                    average: Double(total) / Double(stars.count),
                    count: stars.count
                )
            }
            return result
        } catch {
            return [:]
        }
    }

    private static func map(_ error: Error) -> Error {
        if isMissingSchema(error) {
            return BackendError.schemaMissing
        }
        return error
    }

    private static func isMissingSchema(_ error: Error) -> Bool {
        let text = String(describing: error).lowercased()
        return text.contains("pgrst205")
            || text.contains("schema cache")
            || text.contains("could not find the table")
            || text.contains("does not exist")
    }
}

private struct IdRow: Decodable, Sendable {
    let id: UUID
}

private struct FavoriteIDRow: Decodable, Sendable {
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}

private struct FavoriteRow: Decodable, Sendable {
    let userID: UUID
    let countryCode: String?
    let placeKey: String?
    let name: String?
    let city: String?
    let countryName: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?

    var favorite: Favorite {
        Favorite(
            countryCode: countryCode,
            placeKey: placeKey,
            name: name,
            city: city,
            countryName: countryName,
            address: address,
            latitude: latitude,
            longitude: longitude
        )
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case countryCode = "country_code"
        case placeKey = "place_key"
        case name
        case city
        case countryName = "country_name"
        case address
        case latitude
        case longitude
    }
}

private struct FavoriteWrite: Encodable, Sendable {
    let userID: UUID
    let countryCode: String?
    let placeKey: String?
    let name: String?
    let city: String?
    let countryName: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?

    init(userID: UUID, favorite: Favorite) {
        self.userID = userID
        countryCode = favorite.countryCode
        placeKey = favorite.placeKey
        name = favorite.name
        city = favorite.city
        countryName = favorite.countryName
        address = favorite.address
        latitude = favorite.latitude
        longitude = favorite.longitude
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case countryCode = "country_code"
        case placeKey = "place_key"
        case name
        case city
        case countryName = "country_name"
        case address
        case latitude
        case longitude
    }
}

private struct RestaurantInsert: Encodable, Sendable {
    let placeKey: String
    let name: String
    let city: String
    let countryCode: String
    let countryName: String
    let address: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case placeKey = "place_key"
        case name
        case city
        case countryCode = "country_code"
        case countryName = "country_name"
        case address
        case latitude
        case longitude
    }
}

private struct RatingInsert: Encodable, Sendable {
    let restaurantID: UUID
    let userID: UUID
    let stars: Int

    enum CodingKeys: String, CodingKey {
        case restaurantID = "restaurant_id"
        case userID = "user_id"
        case stars
    }
}

private struct DishInsert: Encodable, Sendable {
    let restaurantID: UUID
    let userID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case restaurantID = "restaurant_id"
        case userID = "user_id"
        case name
    }
}

private struct ReportInsert: Encodable, Sendable {
    let userID: UUID
    let restaurantID: UUID
    let dishID: UUID?
    let reason: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case restaurantID = "restaurant_id"
        case dishID = "dish_id"
        case reason
    }
}
