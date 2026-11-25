import SwiftUI

struct TodaysPickView: View {
    let pick: DailyPick

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("TODAY'S PICK")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)

                RoundedRectangle(cornerRadius: 22)
                    .fill(Theme.peach)
                    .frame(height: 190)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.accent.opacity(0.35))
                    }

                HStack(alignment: .firstTextBaseline) {
                    Text(pick.dishName)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 12)
                    Text(MenuEstimate.priceText(for: pick.dishName))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }

                if pick.isEstimate {
                    Text("Sample price, not from a menu.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Restaurant")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    Text(pick.place.name)
                        .font(.headline)
                    Text(pick.place.address)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Why this")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    Text(pick.reason)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                }

                NavigationLink {
                    RestaurantDetailView(place: pick.place)
                } label: {
                    Text("I'll eat this")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RestaurantDetailView(place: pick.place)
                } label: {
                    Text("See the restaurant")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Today's pick")
        .navigationBarTitleDisplayMode(.inline)
    }
}
