import CoreLocation
import Foundation
import SwiftUI

struct ExploreView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var showSearch = false
    @State private var path = NavigationPath()
    @State private var showAccount = false
    @State private var message: String?
    @State private var selectedCityName = ""
    @State private var nearby: [RestaurantPlace] = []
    @State private var nearbyStats: [String: RestaurantStats] = [:]
    @State private var nearbyDishes: [String: [DishRank]] = [:]
    @State private var loadingNearby = false
    @State private var selectedCategory: CuisineCategory = .all

    private var selectedCity: City? {
        let cities = model.country.cities
        return cities.first { $0.name == selectedCityName } ?? cities.first
    }

    private var rankedNearby: [RestaurantPlace] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = nearby.filter { place in
            let matchesQuery = trimmed.isEmpty || place.name.localizedStandardContains(trimmed)
            return matchesQuery && selectedCategory.matches(place: place)
        }
        return source.sorted { lhs, rhs in
            let left = nearbyStats[lhs.placeKey]
            let right = nearbyStats[rhs.placeKey]
            switch (left, right) {
            case let (left?, right?):
                let leftScore = Self.weightedScore(left)
                let rightScore = Self.weightedScore(right)
                if leftScore != rightScore { return leftScore > rightScore }
                if left.count != right.count { return left.count > right.count }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private var trendingPicks: [DailyPick] {
        let places = rankedNearby.isEmpty && selectedCategory != .all ? nearby : rankedNearby
        return Array(places.prefix(8)).map { place in
            MenuEstimate.pick(
                place: place,
                dishes: nearbyDishes[place.placeKey] ?? [],
                stats: nearbyStats[place.placeKey]
            )
        }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if showSearch {
                        TextField("Restaurant", text: $query)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.94), in: Capsule())
                    }

                    if model.schema == .missing {
                        SchemaBanner()
                    }

                    Text("Don't know what to eat today?")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.ink)

                    Button {
                        Task { await decide() }
                    } label: {
                        Label("Decide for me", systemImage: "dice.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(loadingNearby && nearby.isEmpty)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CuisineCategory.allCases) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Text(category.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category ? Color.black : Color.white, in: Capsule())
                                        .foregroundStyle(selectedCategory == category ? Color.white : Theme.ink)
                                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !trendingPicks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Trending")
                                .font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(trendingPicks, id: \.self) { pick in
                                        Button {
                                            path.append(pick)
                                        } label: {
                                            HomeDishCard(pick: pick)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Nearby restaurants")
                                .font(.headline)
                            Spacer()
                            if let city = selectedCity {
                                NavigationLink(value: city) {
                                    Text("See all")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                        }
                        if loadingNearby && nearby.isEmpty {
                            ProgressView("Looking up restaurants…")
                        } else if rankedNearby.isEmpty {
                            Text(selectedCategory == .all ? "Nothing nearby right now." : "No \(selectedCategory.rawValue) places nearby.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        } else {
                            ForEach(rankedNearby.prefix(4), id: \.id) { place in
                                NavigationLink(value: place) {
                                    HomeRestaurantRow(
                                        place: place,
                                        stats: nearbyStats[place.placeKey]
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if model.favorite?.restaurant != nil {
                        FavoriteCard(path: $path)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife.circle.fill")
                            .foregroundStyle(Theme.accent)
                            .font(.title3)
                        Text("what i eat?")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    
                    Menu {
                        ForEach(model.country.cities) { city in
                            Button(city.name) { selectedCityName = city.name }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedCity?.name ?? "City")
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    }
                    .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                    Button {
                        showSearch.toggle()
                        if !showSearch { query = "" }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(Color.white, in: Circle())
                            .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Theme.background)
            }
            .navigationDestination(for: City.self) { city in
                CityRestaurantsView(city: city)
            }
            .navigationDestination(for: RestaurantPlace.self) { place in
                RestaurantDetailView(place: place)
            }
            .onAppear {
                if selectedCityName.isEmpty {
                    selectedCityName = model.country.cities.first?.name ?? ""
                }
                openDebugCity()
            }
            .onChange(of: model.countryCode) { _, _ in
                selectedCityName = model.country.cities.first?.name ?? ""
            }
            .task(id: "\(selectedCity?.id ?? "")|\(selectedCategory.rawValue)") { await loadNearby() }
            .sheet(isPresented: $showAccount) {
                NavigationStack {
                    AccountView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showAccount = false }
                            }
                        }
                }
            }
            .navigationDestination(for: DailyPick.self) { pick in
                TodaysPickView(pick: pick)
            }
            .alert("Home", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func decide() async {
        if nearby.isEmpty {
            await loadNearby()
        }
        let pick = trendingPicks.first ?? rankedNearby.first.map {
            MenuEstimate.pick(place: $0, dishes: nearbyDishes[$0.placeKey] ?? [], stats: nearbyStats[$0.placeKey])
        }
        guard let pick else {
            message = selectedCategory == .all
                ? "Nothing nearby in this city right now."
                : "Nothing in \(selectedCategory.rawValue) right now."
            return
        }
        path.append(pick)
    }

    private func loadNearby() async {
        guard let city = selectedCity else { return }
        let category = selectedCategory
        loadingNearby = true
        defer { loadingNearby = false }
        do {
            let found = try await RestaurantSearch.search(
                city: city,
                countryName: model.country.name,
                category: category
            )
            let saved = (try? await Backend.places(city: city.name, countryCode: model.country.code)) ?? []
            var merged = found
            let keys = Set(found.map(\.placeKey))
            for place in saved where !keys.contains(place.placeKey) && category.matches(place: place) {
                merged.append(place)
            }
            guard category == selectedCategory else { return }
            nearby = merged
            async let loadedStats = Backend.stats(for: merged)
            async let loadedDishes = Backend.dishPreviews(for: merged)
            nearbyStats = await loadedStats
            nearbyDishes = await loadedDishes
            openDebugPick()
        } catch {
            nearby = []
            nearbyStats = [:]
            nearbyDishes = [:]
            message = error.localizedDescription
        }
    }

    private static func weightedScore(_ stats: RestaurantStats) -> Double {
        let count = Double(stats.count)
        return (count * stats.average + 5 * 3.8) / (count + 5)
    }

    private func openDebugPick() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--todays-pick"),
              path.isEmpty,
              let pick = trendingPicks.first
        else { return }
        path.append(pick)
        #endif
    }

    private func openDebugCity() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--open-budapest"),
              path.isEmpty,
              let city = model.country.cities.first(where: { $0.name == "Budapest" })
        else { return }
        path.append(city)
        #endif
    }
}

private struct HomeDishCard: View {
    let pick: DailyPick

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.peach)
                .frame(width: 176, height: 116)
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.accent.opacity(0.3))
                }
            Text(pick.dishName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(width: 176, alignment: .leading)
            Text(MenuEstimate.priceText(for: pick.dishName))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(pick.place.name)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .frame(width: 176, alignment: .leading)
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}

private struct HomeRestaurantRow: View {
    let place: RestaurantPlace
    let stats: RestaurantStats?

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.peach)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Theme.accent.opacity(0.45))
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let stats {
                    Text(meta(stats))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                } else {
                    Text(place.address)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(white: 0.9), lineWidth: 1)
        )
    }

    private func meta(_ stats: RestaurantStats) -> String {
        let average = stats.average.formatted(
            .number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))
        )
        let count = stats.count.formatted(.number.locale(Locale(identifier: "en_US")))
        return "\(average) ★ (\(count) reviews)"
    }
}

private struct FavoriteCard: View {
    @Environment(AppModel.self) private var model
    @Binding var path: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Favorite place", systemImage: "heart.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            if let place = model.favorite?.restaurant {
                Button {
                    path.append(place)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text("\(place.city), \(place.countryName)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else if model.isSignedIn {
                Text("No favorite restaurant yet. Open a place and save it.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                Text("Sign in to save a favorite restaurant.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            if let favorite = model.favorite, !favorite.countries.isEmpty {
                Text("Favorite countries: \(favorite.countries.map(\.name).joined(separator: ", "))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.accent, lineWidth: 1.5)
        )
    }
}

struct CityRestaurantsView: View {
    @Environment(AppModel.self) private var model
    let city: City

    @State private var places: [RestaurantPlace] = []
    @State private var stats: [String: RestaurantStats] = [:]
    @State private var dishPreviews: [String: [DishRank]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAdd = false
    @State private var decideTarget: RestaurantPlace?
    @State private var cityPick: DailyPick?
    @State private var locator = LocationHelper()
    @State private var query = ""
    @State private var selectedCategory: CuisineCategory = .all

    private var visiblePlaces: [RankedPlace] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return rankedPlaces.filter { item in
            let matchesQuery = trimmed.isEmpty || item.place.name.localizedStandardContains(trimmed)
            return matchesQuery && selectedCategory.matches(place: item.place)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.muted)
                        TextField("Search restaurants", text: $query)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.94), in: Capsule())

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CuisineCategory.allCases) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Text(category.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category ? Color.black : Color.white, in: Capsule())
                                        .foregroundStyle(selectedCategory == category ? Color.white : Theme.ink)
                                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if isLoading && places.isEmpty {
                        ProgressView("Looking up restaurants…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if let errorMessage, places.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage)
                            Button("Try again") { Task { await load() } }
                        }
                    } else if visiblePlaces.isEmpty {
                        Text(places.isEmpty ? "No restaurants in this area." : "No \(selectedCategory.rawValue) restaurants.")
                            .foregroundStyle(Theme.muted)
                    } else {
                        ForEach(visiblePlaces) { item in
                            NavigationLink(value: item.place) {
                                RestaurantCard(
                                    place: item.place,
                                    rank: item.rank,
                                    stats: stats[item.place.placeKey],
                                    dishes: dishPreviews[item.place.placeKey] ?? [],
                                    distance: distanceText(to: item.place)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if model.tier.canAddRestaurant {
                        Button("Add a restaurant") { showAdd = true }
                            .font(.subheadline.weight(.semibold))
                    } else if model.isSignedIn {
                        Text("You can add your own restaurant at level 4.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .refreshable { await load() }

            if let best = visiblePlaces.first {
                Button("Decide for me") {
                    cityPick = MenuEstimate.pick(
                        place: best.place,
                        dishes: dishPreviews[best.place.placeKey] ?? [],
                        stats: stats[best.place.placeKey]
                    )
                }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black, in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
            }
        }
        .background(Theme.background)
        .navigationTitle(city.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: RestaurantPlace.self) { place in
            RestaurantDetailView(place: place)
        }
        .task(id: "\(city.id)|\(selectedCategory.rawValue)") { await load() }
        .navigationDestination(item: $decideTarget) { place in
            RestaurantDetailView(place: place)
        }
        .navigationDestination(item: $cityPick) { pick in
            TodaysPickView(pick: pick)
        }
        .sheet(isPresented: $showAdd) {
            AddRestaurantSheet(city: city, country: model.country) { place in
                if !places.contains(where: { $0.placeKey == place.placeKey }) {
                    places.append(place)
                }
            }
        }
    }

    private var rankedPlaces: [RankedPlace] {
        let rated = places.filter { stats[$0.placeKey] != nil }
        let unrated = places.filter { stats[$0.placeKey] == nil }
        let sortedRated = rated.sorted { lhs, rhs in
            let left = stats[lhs.placeKey]!
            let right = stats[rhs.placeKey]!
            let leftScore = Self.weightedScore(left)
            let rightScore = Self.weightedScore(right)
            if leftScore != rightScore { return leftScore > rightScore }
            if left.count != right.count { return left.count > right.count }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        let sortedUnrated = unrated.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        let ranked = sortedRated.enumerated().map { index, place in
            RankedPlace(place: place, rank: index + 1)
        }
        let rest = sortedUnrated.map { RankedPlace(place: $0, rank: nil) }
        return ranked + rest
    }

    /// Több szavazat közelebb húzza a pontot a valódi átlaghoz. Kevés szavazat óvatos marad.
    private static func weightedScore(_ stats: RestaurantStats) -> Double {
        let priorWeight = 5.0
        let priorAverage = 3.8
        let count = Double(stats.count)
        return (count * stats.average + priorWeight * priorAverage) / (count + priorWeight)
    }

    private func openDebugRestaurant() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--open-restaurant"),
              decideTarget == nil,
              let place = rankedPlaces.first?.place
        else { return }
        decideTarget = place
        #endif
    }

    private func distanceText(to place: RestaurantPlace) -> String? {
        guard let latitude = locator.latitude, let longitude = locator.longitude else { return nil }
        let meters = CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        let kilometers = (meters / 1000).formatted(
            .number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))
        )
        return "\(kilometers) km"
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        locator.request()
        do {
            let found = try await RestaurantSearch.search(
                city: city,
                countryName: model.country.name,
                category: selectedCategory
            )
            let saved = (try? await Backend.places(city: city.name, countryCode: model.country.code)) ?? []
            var merged = found
            let keys = Set(found.map(\.placeKey))
            for place in saved where !keys.contains(place.placeKey) {
                merged.append(place)
            }
            places = merged
            async let loadedStats = Backend.stats(for: merged)
            async let loadedDishes = Backend.dishPreviews(for: merged)
            stats = await loadedStats
            dishPreviews = await loadedDishes
            openDebugRestaurant()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct RestaurantCard: View {
    let place: RestaurantPlace
    let rank: Int?
    let stats: RestaurantStats?
    let dishes: [DishRank]
    let distance: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let line = metaLine {
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            HStack(alignment: .firstTextBaseline) {
                if let rank {
                    Text("#\(rank)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }
                Text(place.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }
            Text("Top dishes here")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            let shown = dishes.isEmpty ? [DishRank(name: MenuEstimate.signatureDish(for: place), votes: 0, myDishID: nil)] : dishes
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, dish in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                        .frame(width: 14, alignment: .leading)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.peach)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dish.name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(MenuEstimate.priceText(for: dish.name))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Text(dish.votes == 0 ? "new" : "\(dish.votes)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }
            }
            HStack {
                Text("See the top 5 and vote")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Theme.accent, lineWidth: 1.5))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(white: 0.9), lineWidth: 1)
        )
    }

    private var metaLine: String? {
        var parts: [String] = []
        if let distance {
            parts.append(distance)
        }
        if let stats {
            let average = stats.average.formatted(
                .number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))
            )
            let count = stats.count.formatted(.number.locale(Locale(identifier: "en_US")))
            parts.append("\(average) ★ (\(count) reviews)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct RankedPlace: Identifiable {
    let place: RestaurantPlace
    let rank: Int?

    var id: String { place.id }
}

private struct AddRestaurantSheet: View {
    let city: City
    let country: Country
    var onSave: (RestaurantPlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Restaurant name", text: $name)
                TextField("Address", text: $address)
                Text("\(city.name), \(country.name)")
                    .foregroundStyle(Theme.muted)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                }
            }
            .navigationTitle("New restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        let place = RestaurantPlace(
            placeKey: "manual|" + RestaurantPlace.makeKey(
                name: trimmed,
                latitude: city.latitude,
                longitude: city.longitude
            ),
            name: trimmed,
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.name,
            countryCode: country.code,
            countryName: country.name,
            latitude: city.latitude,
            longitude: city.longitude
        )
        do {
            _ = try await Backend.ensureRestaurant(place)
            onSave(place)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

