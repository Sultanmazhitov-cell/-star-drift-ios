import SwiftUI
import SpriteKit

private enum Palette {
    static let paper = Color(red: 0.956, green: 0.953, blue: 0.929)
    static let ink = Color(red: 0.10, green: 0.16, blue: 0.19)
    static let space = Color(red: 0.031, green: 0.059, blue: 0.106)
    static let coral = Color(red: 0.953, green: 0.424, blue: 0.259)
    static let teal = Color(red: 0.45, green: 0.76, blue: 0.73)
}

@MainActor
struct GameView: View {
    @StateObject private var model = GameModel()
    @Environment(\.scenePhase) private var appPhase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var showingSettings = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 14) {
                header
                VStack(spacing: 0) {
                    flightHUD
                    ZStack {
                        SpriteView(scene: model.scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                            .accessibilityHidden(true)
                        if model.snapshot.phase != .playing { flightOverlay }
                    }
                    .clipped()
                }
                .background(Palette.space)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Palette.ink.opacity(0.12), radius: 16, y: 8)
                footer
            }
            .padding(.horizontal, geometry.size.width > 600 ? 32 : 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.paper.ignoresSafeArea())
        }
        .preferredColorScheme(.light)
        .onAppear { model.scene.reducedMotion = reducedMotion }
        .onChange(of: reducedMotion) { _, value in model.scene.reducedMotion = value }
        .sheet(isPresented: $showingSettings) { SettingsView(model: model) }
        .onChange(of: appPhase) { _, phase in
            if phase != .active { model.pause() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ОРБИТА / ИГРАЕМ")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(2).foregroundStyle(Palette.coral)
                Text("Звёздный рейс.")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 8)
            Button {
                model.pause()
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.7), in: Circle())
            }
            .accessibilityLabel("Настройки")
            .accessibilityIdentifier("open-settings")
        }
    }

    private var flightHUD: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ТВОЙ СЧЁТ").font(.system(size: 8, weight: .medium)).tracking(1.6)
                    .foregroundStyle(.white.opacity(0.45))
                Text(model.snapshot.score.formatted())
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .monospacedDigit().foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Счёт: \(model.snapshot.score)")
            .accessibilityIdentifier("game-score")
            Spacer(minLength: 5)
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < model.snapshot.lives ? "heart.fill" : "heart")
                            .font(.system(size: 12)).foregroundStyle(Palette.coral)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Щиты: \(model.snapshot.lives) из 3")
                Text(model.timeText).font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Button {
                if model.snapshot.phase == .paused { model.startOrResume() }
                else { model.pause() }
            } label: {
                Image(systemName: model.snapshot.phase == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 15)).foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
            }
            .disabled(model.snapshot.phase == .ready || model.snapshot.phase == .over)
            .opacity(model.snapshot.phase == .ready || model.snapshot.phase == .over ? 0.3 : 1)
            .accessibilityLabel(model.snapshot.phase == .paused ? "Продолжить полёт" : "Пауза")
            .accessibilityIdentifier("pause-flight")
        }
        .padding(.leading, 20).padding(.trailing, 8).padding(.vertical, 15)
        .background(Color.white.opacity(0.035))
    }

    private var flightOverlay: some View {
        ScrollView {
            VStack(spacing: 17) {
                Image(systemName: overlaySymbol)
                    .font(.system(size: 34, weight: .light)).foregroundStyle(Palette.teal)
                    .accessibilityHidden(true)
                Text(overlayEyebrow).font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(2).foregroundStyle(Palette.teal)
                Text(overlayTitle)
                    .font(.system(size: 33, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white).multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
                Text(overlayDescription)
                    .font(.system(size: 13)).lineSpacing(4).foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button { model.startOrResume() } label: {
                    HStack(spacing: 28) {
                        Text(model.snapshot.phase == .paused ? "Продолжить" : model.snapshot.phase == .over ? "Ещё один рейс" : "Начать полёт")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white).padding(.horizontal, 25).frame(height: 53)
                    .background(Palette.coral, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("start-flight")
            }
            .padding(25)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.space.opacity(0.7))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("flight-overlay")
    }

    private var footer: some View {
        HStack {
            Label(model.best.formatted(), systemImage: "sparkle")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.ink.opacity(0.7))
                .accessibilityLabel("Личный рекорд: \(model.best)")
            Spacer()
            Text("Веди пальцем под ракетой")
                .font(.system(size: 10)).foregroundStyle(Palette.ink.opacity(0.55))
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .padding(.horizontal, 4)
    }

    private var overlaySymbol: String {
        switch model.snapshot.phase {
        case .ready: return "paperplane"
        case .paused: return "pause.circle"
        case .over: return "sparkles"
        case .playing: return "paperplane"
        }
    }
    private var overlayEyebrow: String {
        switch model.snapshot.phase {
        case .ready: return "КАПИТАН, ВСЁ ГОТОВО"
        case .paused: return "НЕБОЛЬШАЯ ПЕРЕДЫШКА"
        case .over: return "ПОЛЁТ ЗАВЕРШЁН"
        case .playing: return ""
        }
    }
    private var overlayTitle: String {
        switch model.snapshot.phase {
        case .ready: return "До звёзд —\nодин старт."
        case .paused: return "Космос\nподождёт."
        case .over: return "Ещё немного\nкосмоса?"
        case .playing: return ""
        }
    }
    private var overlayDescription: String {
        switch model.snapshot.phase {
        case .ready: return "Собирай звёзды и обходи метеориты.\nКоснись поля ниже ракеты и двигай пальцем."
        case .paused: return "Продолжи полёт, когда будешь готов.\nТвои очки и щиты сохранены."
        case .over: return "Твой счёт: \(model.snapshot.score). Время: \(model.timeText).\nКаждая звезда — ещё 50 очков."
        case .playing: return ""
        }
    }
}

@MainActor
private struct SettingsView: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Твой полёт") {
                    Toggle("Звуковые эффекты", isOn: $model.soundEnabled)
                        .accessibilityIdentifier("toggle-sound")
                    Toggle("Тактильный отклик", isOn: $model.hapticsEnabled)
                        .accessibilityIdentifier("toggle-haptics")
                    LabeledContent("Личный рекорд", value: model.best.formatted())
                    Button("Сбросить рекорд", role: .destructive) { confirmReset = true }
                }
                Section("Как играть") {
                    Text("Коснись любого места поля и двигай пальцем. Ракета повторяет движения, сохраняя расстояние от пальца. Можно убрать палец и продолжить управление из другого места — ракета не прыгнет.")
                    Text("Звезда даёт 50 очков. За каждую секунду полёта — ещё 8. У тебя три щита; после попадания действует короткая защита.")
                    Text("При сворачивании приложения полёт встаёт на паузу. Завершённый рекорд и настройки сохраняются на этом устройстве. Незавершённый полёт после закрытия приложения не восстанавливается.")
                }
                Section("О приложении") {
                    LabeledContent("Версия", value: "1.0 (1)")
                    Text("Бесплатная игра без рекламы и покупок. Работает без интернета.")
                    NavigationLink("Конфиденциальность") { PrivacyView() }
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .accessibilityIdentifier("close-settings")
                }
            }
            .alert("Сбросить личный рекорд?", isPresented: $confirmReset) {
                Button("Отмена", role: .cancel) {}
                Button("Сбросить", role: .destructive) { model.resetBest() }
            } message: { Text("Это действие нельзя отменить.") }
        }
    }
}

private struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Твои данные остаются у тебя.").font(.title2.bold())
                Text("Звёздный рейс не собирает и не передаёт личные данные. В приложении нет аккаунтов, рекламы, аналитики и отслеживания.")
                Text("Рекорд, настройки звука и вибрации хранятся на устройстве. Рекорд можно сбросить в настройках. Данные приложения удаляются при его удалении; системные резервные копии управляются настройками iOS.")
                Text("Приложение не обращается к камере, микрофону, контактам или геолокации и не делает сетевых запросов.")
                Text("Диагностика и резервное копирование, которые выполняет сама iOS, регулируются настройками устройства и политикой Apple.")
            }
            .font(.body).padding(24)
        }
        .navigationTitle("Конфиденциальность").navigationBarTitleDisplayMode(.inline)
    }
}
