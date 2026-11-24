import SwiftUI

struct RestaurantDetailView: View {
    @Environment(AppModel.self) private var model
    let place: RestaurantPlace

    @State private var row: RestaurantRow?
    @State private var ratings: [RatingRow] = []
    @State private var dishes: [DishRow] = []
    @State private var dishName = ""
    @State private var isWorking = false
    @State private var status: String?
    @State private var showAccount = false
    @State private var showReport = false
    @State private var reportDishID: UUID?

    private var average: RestaurantStats? {
        guard !ratings.isEmpty else { return nil }
        let total = ratings.reduce(0) { $0 + $1.stars }
        return RestaurantStats(average: Double(total) / Double(ratings.count), count: ratings.count)
    }

    private var myStars: Int {
        guard let userID = model.userID else { return 0 }
        return ratings.first { $0.userID == userID }?.stars ?? 0
    }

    private var topDishes: [DishRank] {
        var buckets: [String: (title: String, votes: Int, mine: UUID?)] = [:]
        for dish in dishes {
            let key = dish.name
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "hu_HU"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            var bucket = buckets[key] ?? (dish.name, 0, nil)
            bucket.votes += 1
            if dish.userID == model.userID {
                bucket.mine = dish.id
            }
            if dish.name.count > bucket.title.count {
                bucket.title = dish.name
            }
            buckets[key] = bucket
        }
        return buckets.values
            .map { DishRank(name: $0.title, votes: $0.votes, myDishID: $0.mine) }
            .sorted { lhs, rhs in
                if lhs.votes == rhs.votes {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.votes > rhs.votes
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(place.address)
                        .foregroundStyle(Theme.muted)
                    Text("\(place.city), \(place.countryName)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    if let average {
                        AverageLabel(stats: average)
                    } else {
                        Text("Még nincs értékelés.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }

            Section {
                if model.isSignedIn {
                    StarRating(value: myStars, interactive: true) { star in
                        Task { await rate(star) }
                    }
                    Text(myStars == 0 ? "Koppints a csillagokra." : "A te értékelésed: \(myStars)/5")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                } else {
                    Button("Jelentkezz be az értékeléshez") { showAccount = true }
                }
                NavigationLink {
                    RouteView(place: place)
                } label: {
                    Label("Útvonal", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }
                Button {
                    Task { await markFavorite() }
                } label: {
                    Label(
                        model.favorite?.placeKey == place.placeKey ? "Kedvenc hely" : "Kedvenc helynek jelölöm",
                        systemImage: model.favorite?.placeKey == place.placeKey ? "heart.fill" : "heart"
                    )
                }
                .foregroundStyle(Theme.accent)
            } header: {
                Text("Értékelés")
            }

            Section {
                if topDishes.isEmpty {
                    Text("Még nincs étel. Add hozzá az elsőt, amit itt érdemes megkóstolni.")
                        .foregroundStyle(Theme.muted)
                } else {
                    ForEach(Array(topDishes.enumerated()), id: \.element.id) { index, dish in
                        HStack {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dish.name)
                                Text(dish.votes == 1 ? "1 szavazat" : "\(dish.votes) szavazat")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if dish.myDishID != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .swipeActions {
                            if let id = dish.myDishID {
                                Button("Visszavonás", role: .destructive) {
                                    Task { await removeDish(id) }
                                }
                            }
                            Button("Jelentés") {
                                reportDishID = dish.myDishID == nil ? dishes.first { $0.name == dish.name }?.id : dish.myDishID
                                showReport = true
                            }
                            .tint(.orange)
                        }
                    }
                }
            } header: {
                Text("Top 5 étel")
            } footer: {
                Text("Az ételeket a vendégek adják hozzá. A legtöbb szavazatot kapott öt jelenik meg.")
            }

            Section("Étel hozzáadása") {
                TextField("Például gulyásleves", text: $dishName)
                Button(isWorking ? "Mentés…" : "Hozzáadás") {
                    Task { await addDish() }
                }
                .disabled(isWorking || dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section {
                Button("Étterem jelentése", role: .destructive) {
                    reportDishID = nil
                    showReport = true
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(isPresented: $showAccount, onDismiss: { Task { await reload() } }) {
            NavigationStack {
                AccountView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Bezárás") { showAccount = false }
                        }
                    }
            }
        }
        .confirmationDialog("Mit jelentesz?", isPresented: $showReport, titleVisibility: .visible) {
            Button("Nem ide illik") { Task { await sendReport("Nem ide illik") } }
            Button("Sértő tartalom") { Task { await sendReport("Sértő tartalom") } }
            Button("Téves információ") { Task { await sendReport("Téves információ") } }
            Button("Mégse", role: .cancel) {}
        }
        .alert("Értesítés", isPresented: Binding(
            get: { status != nil },
            set: { if !$0 { status = nil } }
        )) {
            Button("Rendben", role: .cancel) {}
        } message: {
            Text(status ?? "")
        }
    }

    private func markFavorite() async {
        guard model.isSignedIn else {
            showAccount = true
            return
        }
        do {
            try await model.saveFavoriteRestaurant(place)
            status = "Elmentve a fiókod kedvenc helyeként."
        } catch {
            status = error.localizedDescription
        }
    }

    private func reload() async {
        do {
            guard let existing = try await Backend.restaurant(placeKey: place.placeKey) else {
                row = nil
                ratings = []
                dishes = []
                return
            }
            row = existing
            ratings = try await Backend.ratings(restaurantID: existing.id)
            dishes = try await Backend.dishes(restaurantID: existing.id)
        } catch let error as BackendError {
            if case .schemaMissing = error { return }
            status = error.localizedDescription
        } catch {
            status = error.localizedDescription
        }
    }

    private func rate(_ stars: Int) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let saved = try await Backend.ensureRestaurant(place)
            row = saved
            try await Backend.saveRating(restaurantID: saved.id, stars: stars)
            ratings = try await Backend.ratings(restaurantID: saved.id)
        } catch {
            status = error.localizedDescription
        }
    }

    private func addDish() async {
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if !model.isSignedIn {
            showAccount = true
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let saved = try await Backend.ensureRestaurant(place)
            row = saved
            try await Backend.addDish(restaurantID: saved.id, name: name)
            dishName = ""
            dishes = try await Backend.dishes(restaurantID: saved.id)
        } catch {
            status = error.localizedDescription
        }
    }

    private func removeDish(_ id: UUID) async {
        do {
            try await Backend.deleteDish(id: id)
            if let restaurantID = row?.id {
                dishes = try await Backend.dishes(restaurantID: restaurantID)
            }
        } catch {
            status = error.localizedDescription
        }
    }

    private func sendReport(_ reason: String) async {
        guard model.isSignedIn else {
            showAccount = true
            return
        }
        do {
            let saved = try await Backend.ensureRestaurant(place)
            row = saved
            try await Backend.report(restaurantID: saved.id, dishID: reportDishID, reason: reason)
            status = "Köszönjük, a jelentés megérkezett."
        } catch {
            status = error.localizedDescription
        }
    }
}
