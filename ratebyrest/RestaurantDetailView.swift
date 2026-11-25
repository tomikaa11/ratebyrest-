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
    @State private var voteOverride: [String: Bool] = [:]
    @State private var votingKey: String?

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
        DishRank.ranked(from: dishes, userID: model.userID, limit: 5)
    }

    private var voteSummary: String {
        if dishes.isEmpty { return "No votes yet" }
        return dishes.count == 1 ? "1 vote" : "\(dishes.count) votes"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.85), Color(red: 0.15, green: 0.10, blue: 0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 160)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.white.opacity(0.15))
                                .offset(x: 100, y: -20)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RESTAURANT")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(Theme.gold)
                            .tracking(1.5)
                        Text(place.name)
                            .font(.title2.weight(.black))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                    }
                    .padding(16)
                }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            Task { await markFavorite() }
                        } label: {
                            Image(systemName: model.favorite?.placeKey == place.placeKey ? "heart.fill" : "heart")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 36, height: 36)
                                .background(Color.white, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }

                HStack(spacing: 8) {
                    Text("Top 5")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.94), in: Capsule())
                    NavigationLink {
                        RouteView(place: place)
                    } label: {
                        Text("Directions")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white, in: Capsule())
                            .overlay(Capsule().stroke(Color(white: 0.82), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                Text(place.address)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                if model.isSignedIn {
                    StarRating(value: myStars, interactive: true) { star in
                        Task { await rate(star) }
                    }
                    Text(myStars == 0 ? "Tap the stars to rate." : "Your rating: \(myStars)/5")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                } else {
                    Button("Sign in to rate") { showAccount = true }
                        .font(.subheadline.weight(.semibold))
                    if let average {
                        AverageLabel(stats: average)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Top 5 dishes")
                        .font(.title3.weight(.bold))
                    Text(voteSummary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    if let dish = topDishes.first {
                        Text(MenuEstimate.blurb(for: dish.name, place: place))
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                }

                if topDishes.isEmpty {
                    Text("No dishes yet. Suggest the first thing worth ordering.")
                        .foregroundStyle(Theme.muted)
                } else {
                    ForEach(Array(topDishes.enumerated()), id: \.element.id) { index, dish in
                        DishVoteRow(
                            dish: dish,
                            rank: index + 1,
                            votes: displayedVotes(dish),
                            voted: isVoted(dish),
                            isBusy: votingKey == DishRank.normalize(dish.name),
                            onVote: { Task { await toggleVote(dish) } },
                            onReport: {
                                reportDishID = dish.myDishID ?? dishes.first {
                                    DishRank.normalize($0.name) == DishRank.normalize(dish.name)
                                }?.id
                                showReport = true
                            }
                        )
                    }
                }

                if model.tier.canAddDish {
                    TextField("For example, goulash soup", text: $dishName)
                        .padding(12)
                        .background(Color(white: 0.95), in: RoundedRectangle(cornerRadius: 12))
                    Button(isWorking ? "Saving…" : "+ Suggest a new dish") {
                        Task { await addDish() }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black, in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .disabled(isWorking || dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else if model.isSignedIn {
                    Text("You can suggest a new dish from level 3. \(model.tier.nextHint)")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("Sign in to vote on a dish. Suggesting a new one starts at level 3.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }

                Button("Report this restaurant") {
                    reportDishID = nil
                    showReport = true
                }
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(isPresented: $showAccount, onDismiss: { Task { await reload() } }) {
            NavigationStack {
                AccountView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showAccount = false }
                        }
                    }
            }
        }
        .confirmationDialog("What are you reporting?", isPresented: $showReport, titleVisibility: .visible) {
            Button("Doesn't belong here") { Task { await sendReport("Doesn't belong here") } }
            Button("Offensive content") { Task { await sendReport("Offensive content") } }
            Button("Wrong information") { Task { await sendReport("Wrong information") } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Notice", isPresented: Binding(
            get: { status != nil },
            set: { if !$0 { status = nil } }
        )) {
            Button("OK", role: .cancel) {}
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
            status = "Saved as your favorite place."
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
            await model.refreshTier()
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
        guard model.tier.canAddDish else {
            status = model.tier.nextHint
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

    private func isVoted(_ dish: DishRank) -> Bool {
        if let override = voteOverride[DishRank.normalize(dish.name)] {
            return override
        }
        return dish.myDishID != nil
    }

    private func displayedVotes(_ dish: DishRank) -> Int {
        let saved = dish.myDishID != nil
        let current = isVoted(dish)
        if saved == current { return dish.votes }
        return current ? dish.votes + 1 : max(0, dish.votes - 1)
    }

    private func toggleVote(_ dish: DishRank) async {
        guard model.isSignedIn else {
            showAccount = true
            return
        }
        let key = DishRank.normalize(dish.name)
        guard votingKey == nil else { return }
        let voted = isVoted(dish)
        votingKey = key
        voteOverride[key] = !voted
        defer { votingKey = nil }
        do {
            let saved = try await Backend.ensureRestaurant(place)
            row = saved
            if voted {
                let id = dish.myDishID ?? dishes.first {
                    $0.userID == model.userID && DishRank.normalize($0.name) == key
                }?.id
                if let id {
                    try await Backend.deleteDish(id: id)
                }
            } else {
                try await Backend.addDish(restaurantID: saved.id, name: dish.name)
            }
            dishes = try await Backend.dishes(restaurantID: saved.id)
            voteOverride[key] = nil
        } catch {
            voteOverride[key] = nil
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
            status = "Thanks, the report was sent."
        } catch {
            status = error.localizedDescription
        }
    }
}

private struct DishVoteRow: View {
    let dish: DishRank
    let rank: Int
    let votes: Int
    let voted: Bool
    let isBusy: Bool
    let onVote: () -> Void
    let onReport: () -> Void

    private var isFirst: Bool { rank == 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Felső sor: Helyezés badge és fogásnév
            HStack(alignment: .top, spacing: 12) {
                Text(isFirst ? "#1" : "#\(rank)")
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isFirst ? Theme.accent : Color(white: 0.92), in: Capsule())
                    .foregroundStyle(isFirst ? Color.white : Theme.ink)

                VStack(alignment: .leading, spacing: 4) {
                    Text(dish.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    
                    Text(MenuEstimate.priceText(for: dish.name) + " · estimate")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }

                Spacer(minLength: 8)
            }

            // Alsó sor: Szavazatszám és az interaktív egyérintéses gomb
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                    Text("\(votes) votes")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Button(action: onVote) {
                    HStack(spacing: 6) {
                        Image(systemName: voted ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                            .font(.subheadline.weight(.bold))
                        Text(voted ? "Voted (\(votes))" : "I recommend this (\(votes))")
                            .font(.subheadline.weight(.bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(voted ? Color.white : Theme.accent)
                    .background(voted ? Theme.accent : Color.white, in: Capsule())
                    .overlay(Capsule().stroke(Theme.accent, lineWidth: 1.5))
                    .shadow(color: voted ? Theme.accent.opacity(0.35) : Color.clear, radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }

            HStack {
                Spacer()
                Button("Report", action: onReport)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted.opacity(0.8))
                    .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(isFirst ? Theme.peach : Color.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(isFirst ? Theme.accent : Theme.line, lineWidth: isFirst ? 1.5 : 1)
        )
        .shadow(color: isFirst ? Theme.accent.opacity(0.12) : Color.black.opacity(0.04), radius: 10, y: 4)
    }
}

