import SwiftUI
import SpriteKit
import AVFoundation
import UIKit

@MainActor
final class GameModel: ObservableObject {
    let scene = GameScene(size: CGSize(width: 390, height: 600))
    @Published private(set) var snapshot = FlightSnapshot(phase: .ready, score: 0, lives: 3, elapsed: 0)
    @Published private(set) var best: Int
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    private var players: [String: AVAudioPlayer] = [:]
    private let feedback = UINotificationFeedbackGenerator()

    init() {
        let defaults = UserDefaults.standard
        best = max(0, defaults.integer(forKey: "bestScore"))
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        scene.scaleMode = .resizeFill
        scene.onSnapshot = { [weak self] value in
            guard let self else { return }
            if self.snapshot != value { self.snapshot = value }
            if value.phase == .over && value.score > self.best {
                self.best = value.score
                defaults.set(value.score, forKey: "bestScore")
            }
        }
        scene.onEvent = { [weak self] event in self?.handle(event) }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        for name in ["start", "star", "hit", "gameOver"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = name == "hit" ? 0.32 : 0.48
            player.prepareToPlay()
            players[name] = player
        }
    }

    var timeText: String {
        let seconds = Int(snapshot.elapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func startOrResume() {
        if snapshot.phase == .paused { scene.resumeFlight() }
        else { scene.startFlight() }
    }

    func pause() {
        scene.pauseFlight()
        players.values.forEach { $0.stop() }
    }

    func resetBest() {
        best = 0
        UserDefaults.standard.set(0, forKey: "bestScore")
    }

    private func handle(_ event: FlightEvent) {
        let sound: String
        switch event {
        case .start: sound = "start"
        case .star: sound = "star"
        case .hit: sound = "hit"
        case .gameOver: sound = "gameOver"
        }
        if soundEnabled, let player = players[sound] {
            player.currentTime = 0
            player.play()
        }
        guard hapticsEnabled else { return }
        switch event {
        case .hit: feedback.notificationOccurred(.warning)
        case .gameOver: feedback.notificationOccurred(.error)
        case .star: UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
        case .start: feedback.prepare()
        }
    }
}
