import SpriteKit
import UIKit

enum FlightPhase: String, Equatable, Sendable {
    case ready, playing, paused, over
}

struct FlightSnapshot: Equatable, Sendable {
    var phase: FlightPhase
    var score: Int
    var lives: Int
    var elapsed: TimeInterval
}

enum FlightEvent: Sendable {
    case start, star, hit, gameOver
}

/// An entirely local, procedural game. UIKit touch locations and SpriteKit share
/// scene coordinates, so relative gestures keep their offset from the ship.
final class GameScene: SKScene {
    var onSnapshot: ((FlightSnapshot) -> Void)?
    var onEvent: ((FlightEvent) -> Void)?
    var reducedMotion = false

    private(set) var phase: FlightPhase = .ready
    private var elapsed: TimeInterval = 0
    private var bonusScore = 0
    private var lives = 3
    private var previousTime: TimeInterval?
    private var ambientTime: TimeInterval = 0
    private var asteroidCountdown: TimeInterval = 0.7
    private var starCountdown: TimeInterval = 1
    private var invulnerability: TimeInterval = 0
    private var effectShake: TimeInterval = 0
    private var lastPublished: FlightSnapshot?
    private var hasBuiltScene = false
    private var activeTouch: UITouch?
    private var previousTouchPosition = CGPoint.zero
    private var touchTarget: CGPoint?
    private var shipPosition = CGPoint.zero
    private var shipLean: CGFloat = 0

    private let ambientLayer = SKNode()
    private let flightLayer = SKNode()
    private let ship = SKNode()
    private let flame = SKShapeNode()
    private let shield = SKShapeNode(circleOfRadius: 27)
    private var backgroundStars: [BackgroundStar] = []
    private var asteroids: [Asteroid] = []
    private var collectibles: [Collectible] = []
    private var sparks: [Spark] = []
    private var bonusLabels: [BonusLabel] = []

    private let ice = UIColor(red: 0.84, green: 0.94, blue: 0.94, alpha: 1)
    private let teal = UIColor(red: 0.40, green: 0.81, blue: 0.80, alpha: 1)
    private let gold = UIColor(red: 0.98, green: 0.81, blue: 0.52, alpha: 1)
    private let coral = UIColor(red: 1, green: 0.49, blue: 0.32, alpha: 1)

    private struct BackgroundStar {
        let node: SKShapeNode
        let speed: CGFloat
        let phase: CGFloat
    }
    private struct Asteroid {
        let node: SKShapeNode
        let radius: CGFloat
        let speed: CGFloat
        let drift: CGFloat
        let spin: CGFloat
    }
    private struct Collectible {
        let node: SKShapeNode
        let speed: CGFloat
    }
    private struct Spark {
        let node: SKShapeNode
        let velocity: CGVector
        var remaining: TimeInterval
        let lifetime: TimeInterval
    }
    private struct BonusLabel {
        let node: SKLabelNode
        var remaining: TimeInterval
    }

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = UIColor(red: 0.033, green: 0.065, blue: 0.103, alpha: 1)
        scaleMode = .resizeFill
        anchorPoint = .zero
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        anchorPoint = .zero
        isUserInteractionEnabled = true
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        buildSceneIfNeeded()
    }

    private func buildSceneIfNeeded() {
        guard !hasBuiltScene else { return }
        hasBuiltScene = true
        addChild(ambientLayer)
        addChild(flightLayer)
        configureShip()
        rebuildBackground()
        shipPosition = CGPoint(x: size.width / 2, y: size.height * 0.26)
        ship.position = shipPosition
        ship.isHidden = true
        publish(force: true)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard hasBuiltScene, oldSize.width > 0, oldSize.height > 0 else { return }
        func scaled(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x / oldSize.width * size.width,
                    y: point.y / oldSize.height * size.height)
        }
        shipPosition = constrained(scaled(shipPosition))
        ship.position = shipPosition
        for asteroid in asteroids { asteroid.node.position = scaled(asteroid.node.position) }
        for collectible in collectibles { collectible.node.position = scaled(collectible.node.position) }
        for spark in sparks { spark.node.position = scaled(spark.node.position) }
        clearTouch()
        rebuildBackground()
    }

    func startFlight() {
        buildSceneIfNeeded()
        asteroids.forEach { $0.node.removeFromParent() }
        collectibles.forEach { $0.node.removeFromParent() }
        sparks.forEach { $0.node.removeFromParent() }
        bonusLabels.forEach { $0.node.removeFromParent() }
        asteroids.removeAll()
        collectibles.removeAll()
        sparks.removeAll()
        bonusLabels.removeAll()
        elapsed = 0
        bonusScore = 0
        lives = 3
        asteroidCountdown = 0.7
        starCountdown = 1
        invulnerability = 0.9
        effectShake = 0
        shipLean = 0
        shipPosition = constrained(CGPoint(x: size.width / 2, y: size.height * 0.26))
        ship.position = shipPosition
        ship.zRotation = 0
        ship.alpha = 1
        ship.isHidden = false
        flightLayer.position = .zero
        clearTouch()
        previousTime = nil
        phase = .playing
        publish(force: true)
        onEvent?(.start)
    }

    func pauseFlight() {
        guard phase == .playing else { return }
        phase = .paused
        clearTouch()
        previousTime = nil
        flightLayer.position = .zero
        publish(force: true)
    }

    func resumeFlight() {
        guard phase == .paused else { return }
        phase = .playing
        clearTouch()
        previousTime = nil
        publish(force: true)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = min(max(currentTime - (previousTime ?? currentTime), 0), 0.04)
        previousTime = currentTime
        guard phase != .paused else { return }
        ambientTime += dt
        updateBackground(dt)
        updateSparks(dt)
        guard phase == .playing else { return }
        elapsed += dt
        invulnerability = max(0, invulnerability - dt)
        effectShake = max(0, effectShake - dt)
        updateShip(dt)
        updateSpawns(dt)
        updateAsteroids(dt)
        if phase == .playing { updateCollectibles(dt) }
        publish()
    }

    private func updateShip(_ dt: TimeInterval) {
        let previousX = shipPosition.x
        if let target = touchTarget {
            let dx = target.x - shipPosition.x
            let dy = target.y - shipPosition.y
            let distance = hypot(dx, dy)
            let step = min(distance, CGFloat(dt) * 720)
            if distance > 0 {
                shipPosition.x += dx / distance * step
                shipPosition.y += dy / distance * step
            }
        }
        shipPosition = constrained(shipPosition)
        ship.position = shipPosition
        let velocity = (shipPosition.x - previousX) / CGFloat(max(dt, 0.001))
        let desiredLean = -min(max(velocity / 1800, -0.23), 0.23)
        shipLean += (desiredLean - shipLean) * min(CGFloat(dt) * 12, 1)
        ship.zRotation = shipLean
        flame.yScale = reducedMotion ? 1 : 0.8 + CGFloat(sin(ambientTime * 35)) * 0.17
        shield.isHidden = invulnerability <= 0
        shield.alpha = reducedMotion ? 0.3 : 0.3 + CGFloat(sin(ambientTime * 17)) * 0.13
        ship.alpha = invulnerability > 0 ? (reducedMotion ? 0.8 : 0.73 + CGFloat(sin(ambientTime * 29)) * 0.24) : 1
        if effectShake > 0 && !reducedMotion {
            let amount = CGFloat(effectShake) * 13
            flightLayer.position = CGPoint(x: .random(in: -amount...amount), y: .random(in: -amount...amount))
        } else {
            flightLayer.position = .zero
        }
    }

    private func updateSpawns(_ dt: TimeInterval) {
        asteroidCountdown -= dt
        starCountdown -= dt
        if asteroidCountdown <= 0 {
            spawnAsteroid()
            asteroidCountdown = max(0.29, 0.88 - elapsed * 0.006) * .random(in: 0.85...1.15)
        }
        if starCountdown <= 0 {
            spawnCollectible()
            starCountdown = .random(in: 1.1...1.9)
        }
    }

    private func updateAsteroids(_ dt: TimeInterval) {
        var remaining: [Asteroid] = []
        for asteroid in asteroids {
            asteroid.node.position.y -= asteroid.speed * CGFloat(dt)
            asteroid.node.position.x += asteroid.drift * CGFloat(dt)
            asteroid.node.zRotation += asteroid.spin * CGFloat(dt)
            let distance = hypot(asteroid.node.position.x - shipPosition.x,
                                 asteroid.node.position.y - shipPosition.y)
            if phase == .playing && invulnerability <= 0 && distance < asteroid.radius * 0.76 + 11 {
                asteroid.node.removeFromParent()
                lives -= 1
                invulnerability = 1.65
                effectShake = 0.32
                burst(at: shipPosition, color: coral, count: 22)
                onEvent?(.hit)
                if lives == 0 { endFlight() }
            } else if asteroid.node.position.y < -asteroid.radius * 2 {
                asteroid.node.removeFromParent()
            } else {
                remaining.append(asteroid)
            }
        }
        asteroids = remaining
    }

    private func updateCollectibles(_ dt: TimeInterval) {
        var remaining: [Collectible] = []
        for collectible in collectibles {
            collectible.node.position.y -= collectible.speed * CGFloat(dt)
            collectible.node.zRotation += CGFloat(dt) * 0.5
            let distance = hypot(collectible.node.position.x - shipPosition.x,
                                 collectible.node.position.y - shipPosition.y)
            if distance < 27 {
                collectible.node.removeFromParent()
                bonusScore += 50
                burst(at: collectible.node.position, color: gold, count: 15)
                showBonus(at: collectible.node.position)
                onEvent?(.star)
            } else if collectible.node.position.y < -25 {
                collectible.node.removeFromParent()
            } else {
                remaining.append(collectible)
            }
        }
        collectibles = remaining
    }

    private func endFlight() {
        phase = .over
        clearTouch()
        ship.isHidden = true
        flightLayer.position = .zero
        publish(force: true)
        onEvent?(.gameOver)
    }

    private func publish(force: Bool = false) {
        // HUD changes only at score increments or state transitions, not 60 times/s.
        let snapshot = FlightSnapshot(phase: phase, score: Int(elapsed * 8) + bonusScore,
                                      lives: lives, elapsed: elapsed)
        if !force, let previous = lastPublished,
           previous.phase == snapshot.phase, previous.score == snapshot.score,
           previous.lives == snapshot.lives, Int(previous.elapsed) == Int(elapsed) { return }
        lastPublished = snapshot
        onSnapshot?(snapshot)
    }

    private func configureShip() {
        let hull = SKShapeNode(path: polygon([
            CGPoint(x: 0, y: 23), CGPoint(x: 8, y: 1), CGPoint(x: 18, y: -15),
            CGPoint(x: 6, y: -10), CGPoint(x: 0, y: -15), CGPoint(x: -6, y: -10),
            CGPoint(x: -18, y: -15), CGPoint(x: -8, y: 1)
        ]))
        hull.fillColor = ice
        hull.strokeColor = .white
        hull.lineWidth = 0.7
        hull.glowWidth = 1
        ship.addChild(hull)
        let cockpit = SKShapeNode(path: polygon([
            CGPoint(x: 0, y: 12), CGPoint(x: 4, y: -2),
            CGPoint(x: 0, y: -6), CGPoint(x: -4, y: -2)
        ]))
        cockpit.fillColor = UIColor(red: 0.33, green: 0.64, blue: 0.71, alpha: 1)
        cockpit.strokeColor = .clear
        ship.addChild(cockpit)
        flame.path = polygon([CGPoint(x: -4, y: -15), CGPoint(x: 0, y: -37), CGPoint(x: 4, y: -15)])
        flame.fillColor = teal
        flame.strokeColor = .clear
        flame.glowWidth = 4
        flame.zPosition = -1
        ship.addChild(flame)
        shield.fillColor = teal.withAlphaComponent(0.06)
        shield.strokeColor = teal
        shield.lineWidth = 1
        ship.addChild(shield)
        ship.zPosition = 10
        flightLayer.addChild(ship)
    }

    private func rebuildBackground() {
        ambientLayer.removeAllChildren()
        backgroundStars.removeAll()
        let nebula = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.5, height: size.height * 0.8))
        nebula.fillColor = teal.withAlphaComponent(0.025)
        nebula.strokeColor = .clear
        nebula.position = CGPoint(x: size.width * 0.7, y: size.height * 0.8)
        ambientLayer.addChild(nebula)
        let orbit = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.5, height: size.height * 0.86))
        orbit.strokeColor = teal.withAlphaComponent(0.07)
        orbit.fillColor = .clear
        orbit.lineWidth = 0.7
        orbit.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        orbit.zRotation = -0.3
        ambientLayer.addChild(orbit)
        let count = min(130, max(55, Int(size.width * size.height / 3200)))
        for _ in 0..<count {
            let star = SKShapeNode(circleOfRadius: .random(in: 0.5...1.35))
            star.fillColor = ice
            star.strokeColor = .clear
            star.position = CGPoint(x: .random(in: 0...max(size.width, 1)), y: .random(in: 0...max(size.height, 1)))
            ambientLayer.addChild(star)
            backgroundStars.append(BackgroundStar(node: star, speed: .random(in: 6...21), phase: .random(in: 0...(2 * .pi))))
        }
        ambientLayer.zPosition = -10
    }

    private func updateBackground(_ dt: TimeInterval) {
        if reducedMotion {
            for star in backgroundStars { star.node.alpha = 0.4 }
            return
        }
        for star in backgroundStars {
            star.node.position.y -= star.speed * CGFloat(dt)
            if star.node.position.y < -3 { star.node.position.y = size.height + 3 }
            star.node.alpha = 0.35 + CGFloat(sin(ambientTime * 0.8 + Double(star.phase))) * 0.18
        }
    }

    private func spawnAsteroid() {
        let radius = CGFloat.random(in: 15...(size.width < 500 ? 28 : 36))
        let points = (0..<9).map { index -> CGPoint in
            let angle = CGFloat(index) / 9 * 2 * .pi
            let r = radius * .random(in: 0.73...1.12)
            return CGPoint(x: cos(angle) * r, y: sin(angle) * r)
        }
        let rock = SKShapeNode(path: polygon(points))
        rock.fillColor = UIColor(red: 0.24, green: 0.25, blue: 0.30, alpha: 1)
        rock.strokeColor = UIColor(red: 0.53, green: 0.45, blue: 0.44, alpha: 1)
        rock.lineWidth = 1.2
        rock.position = CGPoint(x: randomX(margin: radius + 5), y: size.height + radius * 2)
        rock.zRotation = .random(in: 0...(2 * .pi))
        for offset in [CGPoint(x: -radius * 0.25, y: radius * 0.2), CGPoint(x: radius * 0.3, y: -radius * 0.3)] {
            let crater = SKShapeNode(circleOfRadius: radius * 0.17)
            crater.fillColor = UIColor(white: 0.035, alpha: 0.35)
            crater.strokeColor = .clear
            crater.position = offset
            rock.addChild(crater)
        }
        flightLayer.addChild(rock)
        asteroids.append(Asteroid(node: rock, radius: radius,
                                  speed: .random(in: 92...142) + CGFloat(min(elapsed * 1.7, 145)),
                                  drift: .random(in: -16...16), spin: .random(in: -0.65...0.65)))
    }

    private func spawnCollectible() {
        let points = (0..<8).map { index -> CGPoint in
            let angle = CGFloat(index) / 8 * 2 * .pi
            let radius: CGFloat = index.isMultiple(of: 2) ? 11 : 4
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        let star = SKShapeNode(path: polygon(points))
        star.fillColor = gold
        star.strokeColor = .clear
        star.glowWidth = 3
        star.position = CGPoint(x: randomX(margin: 27), y: size.height + 25)
        let halo = SKShapeNode(circleOfRadius: 18)
        halo.strokeColor = gold.withAlphaComponent(0.17)
        halo.fillColor = .clear
        halo.lineWidth = 0.7
        star.addChild(halo)
        flightLayer.addChild(star)
        collectibles.append(Collectible(node: star, speed: .random(in: 78...110)))
    }

    private func burst(at position: CGPoint, color: UIColor, count: Int) {
        for _ in 0..<(reducedMotion ? min(count, 6) : count) {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 35...145)
            let dot = SKShapeNode(circleOfRadius: .random(in: 1.3...3))
            dot.fillColor = color
            dot.strokeColor = .clear
            dot.position = position
            dot.zPosition = 20
            flightLayer.addChild(dot)
            let lifetime = TimeInterval.random(in: 0.3...0.75)
            sparks.append(Spark(node: dot, velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                                remaining: lifetime, lifetime: lifetime))
        }
    }

    private func showBonus(at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "+50"
        label.fontSize = 14
        label.fontColor = gold
        label.position = position
        label.zPosition = 22
        flightLayer.addChild(label)
        bonusLabels.append(BonusLabel(node: label, remaining: 0.65))
    }

    private func updateSparks(_ dt: TimeInterval) {
        bonusLabels = bonusLabels.compactMap { label in
            var updated = label
            updated.remaining -= dt
            guard updated.remaining > 0 else { updated.node.removeFromParent(); return nil }
            updated.node.position.y += CGFloat(dt) * 43
            updated.node.alpha = CGFloat(updated.remaining / 0.65)
            return updated
        }
        sparks = sparks.compactMap { spark in
            var updated = spark
            updated.remaining -= dt
            guard updated.remaining > 0 else { updated.node.removeFromParent(); return nil }
            updated.node.position.x += updated.velocity.dx * CGFloat(dt)
            updated.node.position.y += updated.velocity.dy * CGFloat(dt)
            updated.node.alpha = CGFloat(updated.remaining / updated.lifetime)
            updated.node.setScale(CGFloat(updated.remaining / updated.lifetime))
            return updated
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .playing, activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        previousTouchPosition = touch.location(in: self)
        touchTarget = shipPosition
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .playing, let activeTouch,
              touches.contains(activeTouch), let target = touchTarget else { return }
        let position = activeTouch.location(in: self)
        touchTarget = constrained(CGPoint(x: target.x + position.x - previousTouchPosition.x,
                                         y: target.y + position.y - previousTouchPosition.y))
        previousTouchPosition = position
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let activeTouch, touches.contains(activeTouch) { clearTouch() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let activeTouch, touches.contains(activeTouch) { clearTouch() }
    }

    private func clearTouch() {
        activeTouch = nil
        touchTarget = nil
    }

    private func constrained(_ position: CGPoint) -> CGPoint {
        CGPoint(x: min(max(position.x, 24), max(24, size.width - 24)),
                y: min(max(position.y, 40), max(40, size.height - 40)))
    }

    private func randomX(margin: CGFloat) -> CGFloat {
        .random(in: min(margin, size.width / 2)...max(margin, size.width - margin))
    }

    private func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        if let first = points.first {
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
        }
        return path
    }
}
