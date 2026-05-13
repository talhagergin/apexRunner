//
//  ShopView.swift
//  apexRunner
//
//  Character skin & passive skill shop with persistent coin currency.
//

import SwiftUI

struct ShopView: View {
    @Binding var isPresented: Bool
    var store = GameProgressStore.shared

    @State private var selectedTab = 0
    @State private var purchaseFeedback: String? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.02, blue: 0.12),
                    Color(red: 0.08, green: 0.03, blue: 0.18)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                shopHeader
                tabPicker.padding(.top, 12)
                shopSummary.padding(.top, 12)
                if selectedTab == 0 { skinGrid } else { skillList }
                Spacer()
            }

            if let msg = purchaseFeedback {
                Text(msg)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 50)
            }
        }
        .animation(.spring(response: 0.4), value: purchaseFeedback ?? "")
    }

    // MARK: - Header

    private var shopHeader: some View {
        HStack {
            Button { isPresented = false } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            Spacer()
            Text("SHOP")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 0.55, green: 0.0, blue: 1.0)],
                    startPoint: .leading, endPoint: .trailing
                ))
            Spacer()
            coinBadge
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    private var coinBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                 startPoint: .top, endPoint: .bottom))
            Text("\(store.totalCoins)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 1.0, green: 0.9, blue: 0.0), .orange],
                    startPoint: .leading, endPoint: .trailing
                ))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var shopSummary: some View {
        HStack(spacing: 10) {
            summaryCell(title: "COINS", value: "\(store.totalCoins)", color: Color(red: 1.0, green: 0.85, blue: 0.0))
            summaryCell(title: "SKINS", value: "\(store.purchasedSkinIds.count)/\(CharacterSkin.all.count)", color: Color(red: 0.0, green: 0.95, blue: 1.0))
            summaryCell(title: "SKILLS", value: "\(store.purchasedSkillIds.count)/\(PassiveSkill.all.count)", color: Color(red: 0.2, green: 1.0, blue: 0.3))
        }
        .padding(.horizontal, 20)
    }

    private func summaryCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.42))
                .tracking(2)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(color.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: "CHARACTERS", index: 0)
            tabButton(title: "SKILLS", index: 1)
        }
        .padding(.horizontal, 20)
    }

    // Fix: avoid ternary with mismatched types by using a single gradient + opacity
    private func tabButton(title: String, index: Int) -> some View {
        let isActive = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.3)) { selectedTab = index }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(isActive ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    // Single gradient whose opacity toggles — avoids ternary type mismatch
                    LinearGradient(
                        colors: [Color(red: 0.0, green: 0.85, blue: 1.0),
                                 Color(red: 0.4, green: 0.0, blue: 1.0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .opacity(isActive ? 0.25 : 0)
                )
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(isActive
                                         ? Color(red: 0.0, green: 0.85, blue: 1.0)
                                         : Color.clear),
                    alignment: .bottom
                )
        }
    }

    // MARK: - Skin Grid

    private var skinGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(CharacterSkin.all) { skin in
                    skinCard(skin)
                }
            }
            .padding(20)
        }
    }

    private func skinCard(_ skin: CharacterSkin) -> some View {
        let owned    = store.purchasedSkinIds.contains(skin.id)
        let selected = store.selectedSkinId == skin.id
        let canAfford = store.totalCoins >= skin.price

        return VStack(spacing: 10) {
            // Preview icon
            ZStack {
                Circle()
                    .fill(skin.previewColor.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle().stroke(
                            selected ? skin.previewColor : Color.white.opacity(0.1),
                            lineWidth: selected ? 2 : 1
                        )
                    )
                Image(systemName: skin.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [skin.previewColor, skin.previewColor.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .shadow(color: skin.previewColor.opacity(0.8), radius: 10)
            }

            Text(skin.displayName)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(2)

            skinActionButton(skin: skin, owned: owned, selected: selected, canAfford: canAfford)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(selected ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            selected ? skin.previewColor.opacity(0.5) : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
    }

    // Extracted to avoid ViewBuilder complexity in skinCard
    @ViewBuilder
    private func skinActionButton(skin: CharacterSkin, owned: Bool, selected: Bool, canAfford: Bool) -> some View {
        if selected {
            Text("EQUIPPED")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(skin.previewColor)
                .tracking(2)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(skin.previewColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if owned {
            Button { store.selectSkin(skin.id) } label: {
                Text("EQUIP")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        } else {
            Button {
                if store.purchaseSkin(skin.id) {
                    store.selectSkin(skin.id)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    showFeedback("✅ \(skin.displayName) unlocked!")
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showFeedback("❌ Not enough coins")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                         startPoint: .top, endPoint: .bottom))
                    Text("\(skin.price)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(canAfford ? .white : .white.opacity(0.35))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    // Both branches are LinearGradient — same type, no ambiguity
                    canAfford
                    ? LinearGradient(colors: [Color(red: 0.0, green: 0.85, blue: 1.0),
                                               Color(red: 0.4, green: 0.0, blue: 1.0)],
                                      startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)],
                                      startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .disabled(!canAfford)
        }
    }

    // MARK: - Skill List

    private var skillList: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(PassiveSkill.all) { skill in
                    skillRow(skill)
                }
            }
            .padding(20)
        }
    }

    private func skillRow(_ skill: PassiveSkill) -> some View {
        let owned     = store.purchasedSkillIds.contains(skill.id)
        let canAfford = store.totalCoins >= skill.price

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(skill.color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: skill.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(skill.color)
                    .shadow(color: skill.color.opacity(0.8), radius: 8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(skill.displayName)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1)
                Text(skill.description)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Text(skillStatusText(skill))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(skill.color.opacity(owned ? 0.85 : 0.55))
                    .tracking(1)
            }

            Spacer()

            skillActionButton(skill: skill, owned: owned, canAfford: canAfford)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(owned ? 0.07 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            owned ? skill.color.opacity(0.4) : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
    }

    @ViewBuilder
    private func skillActionButton(skill: PassiveSkill, owned: Bool, canAfford: Bool) -> some View {
        if owned {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("ACTIVE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1)
            }
            .foregroundColor(skill.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(skill.color.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Button {
                if store.purchaseSkill(skill.id) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    showFeedback("✅ \(skill.displayName) activated!")
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showFeedback("❌ Not enough coins")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                         startPoint: .top, endPoint: .bottom))
                    Text("\(skill.price)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(canAfford ? .white : .white.opacity(0.3))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    canAfford
                    ? LinearGradient(colors: [Color(red: 0.0, green: 0.85, blue: 1.0),
                                               Color(red: 0.4, green: 0.0, blue: 1.0)],
                                      startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.07)],
                                      startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(!canAfford)
        }
    }

    // MARK: - Helpers

    private func showFeedback(_ msg: String) {
        purchaseFeedback = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { purchaseFeedback = nil }
        }
    }

    private func skillStatusText(_ skill: PassiveSkill) -> String {
        switch skill.id {
        case "magnet":
            return "COIN RADIUS 1.0 -> 2.8"
        case "headstart":
            return "START SPEED +5 M/S"
        case "saver":
            return "FIRST HIT BLOCKED"
        default:
            return "PERMANENT"
        }
    }
}
