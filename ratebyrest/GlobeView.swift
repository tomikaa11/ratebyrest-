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

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    CountryPicker(countryCode: $model.countryCode)
                        .labelsHidden()
                        .tint(Theme.accent)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                GlobeRepresentable(
                    cities: model.country.cities,
                    selectedID: selectedCity?.id,
                    focusLatitude: countryFocus.latitude,
                    focusLongitude: countryFocus.longitude,
                    cameraDistance: countryFocus.distance,
                    frameKey: model.countryCode,
                    onSelect: { cityID in
                        selectedCity = model.country.cities.first { $0.id == cityID }
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 380)

                Text("Válassz országot, a gömb odanagyít. Koppints egy városra.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .padding(.bottom, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.country.cities) { city in
                            Button {
                                selectedCity = city
                            } label: {
                                Text(city.name)
                                    .font(.subheadline.weight(selectedCity?.id == city.id ? .bold : .regular))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedCity?.id == city.id ? Theme.accent : Color.white, in: Capsule())
                                    .foregroundStyle(selectedCity?.id == city.id ? Color.white : Theme.accent)
                                    .overlay(
                                        Capsule().stroke(Theme.accent, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                if let selectedCity {
                    NavigationLink {
                        CityRestaurantsView(city: selectedCity)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedCity.name)
                                    .font(.headline)
                                Text("Éttermek megnyitása")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.muted)
                        }
                        .padding()
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding()
                } else {
                    Text("Válassz várost.")
                        .foregroundStyle(Theme.muted)
                        .padding()
                }
                Spacer(minLength: 0)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Földgömb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onAppear {
                if selectedCity == nil {
                    selectedCity = model.country.cities.first
                }
            }
            .onChange(of: model.countryCode) { _, _ in
                selectedCity = model.country.cities.first
            }
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
        let distance = Float(min(2.65, max(2.15, 2.05 + span / 55)))
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
        view.backgroundColor = .white
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
        sphere.segmentCount = 64
        let material = SCNMaterial()
        material.diffuse.contents = earthImage() ?? PlatformColor(red: 0.12, green: 0.32, blue: 0.52, alpha: 1)
        material.specular.contents = PlatformColor(white: 0.15, alpha: 1)
        material.shininess = 0.1
        sphere.materials = [material]
        let sphereNode = SCNNode(geometry: sphere)
        // A textúra közepe a greenwichi délkör. A gömb alapból ezt a +Z felé teszi,
        // a városok hosszúsága viszont a +X-től indul.
        sphereNode.eulerAngles.y = .pi / 2
        root.addChildNode(sphereNode)

        let pins = SCNNode()
        pins.name = "pins"
        root.addChildNode(pins)
        scene.rootNode.addChildNode(root)

        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 32
        cameraNode.position = SCNVector3(0, 0.15, 3.05)
        scene.rootNode.addChildNode(cameraNode)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 280
        scene.rootNode.addChildNode(ambient)
        return scene
    }

    func pin(for city: City, selected: Bool) -> SCNNode {
        let radius: CGFloat = selected ? 0.028 : 0.016
        let node = SCNNode(geometry: SCNSphere(radius: radius))
        node.name = city.id
        node.position = surfacePosition(latitude: city.latitude, longitude: city.longitude, radius: 1.02)
        let material = SCNMaterial()
        let color = selected
            ? PlatformColor(red: 0.80, green: 0.07, blue: 0.11, alpha: 1)
            : PlatformColor(red: 0.55, green: 0.04, blue: 0.08, alpha: 1)
        material.diffuse.contents = color
        material.emission.contents = color
        node.geometry?.materials = [material]
        return node
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
        guard let name = hits.compactMap(\.node.name).first(where: { !$0.isEmpty && $0 != "globe" && $0 != "pins" }) else {
            return
        }
        onSelect(name)
    }
}
