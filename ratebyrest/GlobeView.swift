import SceneKit
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct GlobeView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedCity: City?
    @State private var cityPlacesCount: Int?
    @State private var topCityDish: (name: String, count: Int)?
    @State private var isLoadingCityInfo = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Globe")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Text("Find a city's food")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "globe.europe.africa.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                            CountryPicker(countryCode: $model.countryCode)
                                .labelsHidden()
                                .tint(Theme.ink)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white, Color(white: 0.95)],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 180
                                )
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 24, y: 10)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 8)
                        GlobeRepresentable(
                            cities: model.country.cities,
                            selectedID: selectedCity?.id,
                            focusLatitude: countryFocus.latitude,
                            focusLongitude: countryFocus.longitude,
                            cameraDistance: countryFocus.distance,
                            frameKey: model.countryCode,
                            onSelect: { cityID in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedCity = model.country.cities.first { $0.id == cityID }
                                }
                            }
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.country.cities) { city in
                                let isSelected = selectedCity?.id == city.id
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        selectedCity = city
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        if isSelected {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.caption2)
                                        }
                                        Text(city.name)
                                            .font(.subheadline.weight(isSelected ? .bold : .medium))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Theme.accent : Color.white, in: Capsule())
                                    .foregroundStyle(isSelected ? Color.white : Theme.ink)
                                    .overlay(Capsule().stroke(isSelected ? Theme.accent : Theme.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }

                    Spacer(minLength: 160)
                }

                if let selectedCity {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(selectedCity.name)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(Theme.ink)
                                    Text(model.country.name)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.peach, in: Capsule())
                                        .foregroundStyle(Theme.accent)
                                }
                                if let count = cityPlacesCount {
                                    Text(count == 1 ? "1 restaurant" : "\(count) restaurants")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                } else if isLoadingCityInfo {
                                    Text("Looking up places…")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                } else {
                                    Text("See the local picks")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            Spacer()
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.accent)
                        }

                        if let topCityDish {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("TOP DISH IN THIS CITY")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Theme.accent)
                                    Text(topCityDish.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(topCityDish.count == 1 ? "1 vote" : "\(topCityDish.count) votes")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white, in: Capsule())
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(10)
                            .background(Theme.peach, in: RoundedRectangle(cornerRadius: 12))
                        }

                        NavigationLink {
                            CityRestaurantsView(city: selectedCity)
                        } label: {
                            HStack(spacing: 8) {
                                Text("\(selectedCity.name) restaurants")
                                    .font(.headline.weight(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(Color.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                    .shadow(color: Color.black.opacity(0.12), radius: 16, y: -4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if selectedCity == nil {
                    selectedCity = model.country.cities.first
                }
            }
            .onChange(of: model.countryCode) { _, _ in
                withAnimation {
                    selectedCity = model.country.cities.first
                }
            }
            .task(id: selectedCity?.id) {
                await loadCityPreview()
            }
        }
    }

    private func loadCityPreview() async {
        guard let city = selectedCity else {
            cityPlacesCount = nil
            topCityDish = nil
            return
        }
        isLoadingCityInfo = true
        defer { isLoadingCityInfo = false }
        do {
            let found = try await RestaurantSearch.search(city: city, countryName: model.country.name)
            let saved = (try? await Backend.places(city: city.name, countryCode: city.countryCode)) ?? []
            var merged = found
            let keys = Set(found.map(\.placeKey))
            for place in saved where !keys.contains(place.placeKey) {
                merged.append(place)
            }
            cityPlacesCount = merged.count
            let previews = await Backend.dishPreviews(for: Array(merged.prefix(10)))
            var dishCounts: [String: Int] = [:]
            for ranks in previews.values {
                for rank in ranks where rank.votes > 0 {
                    dishCounts[rank.name, default: 0] += rank.votes
                }
            }
            if let best = dishCounts.max(by: { $0.value < $1.value }) {
                topCityDish = (name: best.key, count: best.value)
            } else {
                topCityDish = nil
            }
        } catch {
            cityPlacesCount = nil
            topCityDish = nil
        }
    }

    private var countryFocus: (latitude: Double, longitude: Double, distance: Float) {
        let cities = model.country.cities
        let count = Double(max(cities.count, 1))
        let latitude = cities.map(\.latitude).reduce(0, +) / count
        let longitude = cities.map(\.longitude).reduce(0, +) / count
        let latSpan = (cities.map(\.latitude).max() ?? latitude) - (cities.map(\.latitude).min() ?? latitude)
        let lonSpan = (cities.map(\.longitude).max() ?? longitude) - (cities.map(\.longitude).min() ?? longitude)
        let span = max(latSpan, lonSpan)
        let distance = Float(min(3.35, max(2.95, 3.0 + span / 120)))
        return (latitude, longitude, distance)
    }
}

#if os(macOS)
private struct GlobeRepresentable: NSViewRepresentable {
    var cities: [City]
    var selectedID: String?
    var focusLatitude: Double
    var focusLongitude: Double
    var cameraDistance: Float
    var frameKey: String
    var onSelect: (String) -> Void

    func makeNSView(context: Context) -> SCNView {
        makeGlobeView(context: context)
    }

    func updateNSView(_ view: SCNView, context: Context) {
        updateGlobe(view, context: context)
    }
}
#else
private struct GlobeRepresentable: UIViewRepresentable {
    var cities: [City]
    var selectedID: String?
    var focusLatitude: Double
    var focusLongitude: Double
    var cameraDistance: Float
    var frameKey: String
    var onSelect: (String) -> Void

    func makeUIView(context: Context) -> SCNView {
        makeGlobeView(context: context)
    }

    func updateUIView(_ view: SCNView, context: Context) {
        updateGlobe(view, context: context)
    }
}
#endif

private extension GlobeRepresentable {
    func makeCoordinator() -> GlobeCoordinator {
        GlobeCoordinator()
    }

    func makeGlobeView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = makeScene()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        let gesture: PlatformTap
#if os(macOS)
        gesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(GlobeCoordinator.handleClick(_:)))
#else
        gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(GlobeCoordinator.handleTap(_:)))
#endif
        view.addGestureRecognizer(gesture)
        return view
    }

    func updateGlobe(_ view: SCNView, context: Context) {
        context.coordinator.onSelect = onSelect
        guard let root = view.scene?.rootNode.childNode(withName: "globe", recursively: false),
              let pins = root.childNode(withName: "pins", recursively: false) else { return }
        guard view.bounds.width > 20 else {
            guard context.coordinator.layoutRetries < 8 else { return }
            context.coordinator.layoutRetries += 1
            DispatchQueue.main.async { [self] in
                updateGlobe(view, context: context)
            }
            return
        }

        let key = cities.map(\.id).joined(separator: "|") + "|" + (selectedID ?? "")
        if context.coordinator.pinKey != key {
            pins.enumerateChildNodes { node, _ in node.removeFromParentNode() }
            for city in cities {
                pins.addChildNode(pin(for: city, selected: city.id == selectedID))
            }
            context.coordinator.pinKey = key
        }

        guard let focus = cities.first(where: { $0.id == selectedID }) ?? cities.first else { return }
        let countryChanged = context.coordinator.frameKey != frameKey
        let cityChanged = context.coordinator.framedCityID != focus.id
        guard countryChanged || cityChanged else { return }

        let aim = countryChanged
            ? City(name: "", countryCode: frameKey, latitude: focusLatitude, longitude: focusLongitude)
            : focus
        let point = surfacePosition(latitude: aim.latitude, longitude: aim.longitude, radius: cameraDistance)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.85
        root.eulerAngles = SCNVector3(0, 0, 0)
        if let camera = view.scene?.rootNode.childNode(withName: "camera", recursively: false) {
            camera.position = point
            camera.look(
                at: SCNVector3(0, 0, 0),
                up: SCNVector3(0, 1, 0),
                localFront: SCNVector3(0, 0, -1)
            )
        }
        SCNTransaction.commit()
        context.coordinator.frameKey = frameKey
        context.coordinator.framedCityID = focus.id
    }

    func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = PlatformColor.clear

        let root = SCNNode()
        root.name = "globe"

        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = earthImage() ?? PlatformColor(red: 0.12, green: 0.32, blue: 0.52, alpha: 1)
        material.locksAmbientWithDiffuse = true
        material.specular.contents = PlatformColor(white: 0.22, alpha: 1)
        material.shininess = 0.06
        sphere.materials = [material]
        let sphereNode = SCNNode(geometry: sphere)
        // A textúra közepe a greenwichi délkör. A gömb alapból ezt a +Z felé teszi,
        // a városok hosszúsága viszont a +X-től indul.
        sphereNode.eulerAngles.y = .pi / 2
        root.addChildNode(sphereNode)
        root.addChildNode(atmosphereNode())

        let pins = SCNNode()
        pins.name = "pins"
        root.addChildNode(pins)
        scene.rootNode.addChildNode(root)

        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 42
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 20
        cameraNode.position = SCNVector3(0, 0.15, 3.05)
        scene.rootNode.addChildNode(cameraNode)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 620
        sun.eulerAngles = SCNVector3(-0.6, 0.5, 0)
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 480
        scene.rootNode.addChildNode(ambient)
        return scene
    }

    func pin(for city: City, selected: Bool) -> SCNNode {
        let container = SCNNode()
        container.name = city.id
        container.position = surfacePosition(latitude: city.latitude, longitude: city.longitude, radius: 1.02)

        let sphere = SCNSphere(radius: selected ? 0.024 : 0.012)
        let material = SCNMaterial()
        let color = selected
            ? PlatformColor(red: 0.90, green: 0.15, blue: 0.15, alpha: 1)
            : PlatformColor(red: 0.65, green: 0.20, blue: 0.20, alpha: 0.85)
        material.diffuse.contents = color
        material.emission.contents = color
        sphere.materials = [material]
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.name = city.id
        container.addChildNode(sphereNode)

        if selected {
            let halo = SCNSphere(radius: 0.036)
            let haloMaterial = SCNMaterial()
            let haloColor = PlatformColor(red: 0.95, green: 0.30, blue: 0.25, alpha: 0.35)
            haloMaterial.diffuse.contents = haloColor
            haloMaterial.emission.contents = haloColor
            haloMaterial.isDoubleSided = true
            haloMaterial.blendMode = .add
            halo.materials = [haloMaterial]
            let haloNode = SCNNode(geometry: halo)
            haloNode.name = city.id
            container.addChildNode(haloNode)
        }
        return container
    }

    func surfacePosition(latitude: Double, longitude: Double, radius: Float) -> SCNVector3 {
        let lat = Float(latitude * .pi / 180)
        let lon = Float(longitude * .pi / 180)
        return SCNVector3(
            radius * cos(lat) * cos(lon),
            radius * sin(lat),
            radius * -cos(lat) * sin(lon)
        )
    }

    func atmosphereNode() -> SCNNode {
        let halo = SCNSphere(radius: 1.045)
        halo.segmentCount = 64
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = PlatformColor.black
        material.emission.contents = PlatformColor.black
        material.blendMode = .add
        material.isDoubleSided = false
        material.writesToDepthBuffer = false
        material.shaderModifiers = [
            .surface: """
            float rim = 1.0 - abs(dot(normalize(_surface.view), normalize(_surface.normal)));
            rim = pow(rim, 1.7);
            _surface.emission = vec4(0.55, 0.74, 0.95, 1.0) * rim * 1.35;
            """
        ]
        halo.materials = [material]
        let node = SCNNode(geometry: halo)
        node.name = "atmosphere"
        return node
    }

    func earthImage() -> PlatformImage? {
        guard let url = Bundle.main.url(forResource: "earth", withExtension: "jpg") else { return nil }
#if os(macOS)
        return NSImage(contentsOf: url)
#else
        return UIImage(contentsOfFile: url.path)
#endif
    }
}

#if os(macOS)
private typealias PlatformColor = NSColor
private typealias PlatformImage = NSImage
private typealias PlatformTap = NSClickGestureRecognizer
#else
private typealias PlatformColor = UIColor
private typealias PlatformImage = UIImage
private typealias PlatformTap = UITapGestureRecognizer
#endif

private final class GlobeCoordinator: NSObject {
    var onSelect: (String) -> Void = { _ in }
    var pinKey = ""
    var framedCityID: String?
    var frameKey = ""
    var layoutRetries = 0

#if os(macOS)
    @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard let view = gesture.view as? SCNView else { return }
        pick(at: gesture.location(in: view), in: view)
    }
#else
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view as? SCNView else { return }
        pick(at: gesture.location(in: view), in: view)
    }
#endif

    private func pick(at point: CGPoint, in view: SCNView) {
        let hits = view.hitTest(point, options: [
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue
        ])
        guard let name = hits.compactMap({ hit -> String? in
            var node: SCNNode? = hit.node
            while let current = node {
                if let name = current.name, !name.isEmpty, name != "globe", name != "pins", name != "atmosphere" {
                    return name
                }
                node = current.parent
            }
            return nil
        }).first else {
            return
        }
        onSelect(name)
    }
}
