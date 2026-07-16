//
//  EmojiData.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/4/25.
//

import Foundation
import SwiftUI

struct EmojiData {
    static let emojiCategories: [String: [String]] = [
        
        "Reacciones":
            ["👍", "👎", "❤️", "🔥", "😂", "🥰", "👏", "😡", "😢", "😮",
             "🤯", "😍", "🤩", "😭", "😤", "🤢", "🤮", "🤠", "🥵", "🥶",
             "😈", "👻", "🫠", "🫡", "🫢", "🫣", "🤨", "🥹"],
        
        "Caras Felices":
            ["😀", "😃", "😄", "😁", "😆", "😅", "😊", "😇", "🙂", "🙃",
             "😺", "😸", "😹", "😻", "😼", "😽", "🤑", "🤗", "🤪", "😋",
             "😛", "😌", "😉", "🤭", "🥴", "😏"],
        
        "Caras Tristes":
            ["🙁", "☹️", "😞", "😔", "😩", "😫", "🥺", "😿", "😓", "😥",
             "😰", "😨", "😱", "🤧", "😷", "🤒", "🤕", "😵", "😵‍💫", "😾"],
        
        "Gestos":
            ["🙌", "🙏", "🤝", "✌️", "🤟", "👌", "👋", "👊", "🖐️", "✋",
             "🤙", "💪", "🤞", "🤘", "🤏", "👈", "👉", "👆", "👇", "☝️",
             "✊", "🤛", "🤜", "🦾", "🫶", "🤌", "🫳", "🫴", "🫲", "🫱"],
        
        "Objetos":
            ["🎁", "📱", "💡", "🔔", "💣", "💎", "🎯", "📌", "🖊️", "📚",
             "🧯", "🔋", "🔌", "💻", "⌚️", "📷", "🔦", "🕯️", "🧷", "📎",
             "✂️", "🔒", "🔑", "🧲", "⚗️", "🧪", "🧫", "🧬", "🪫", "🪩",
             "🛜", "🪬", "📿", "🪮"],
        
        "Animales":
            ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐸",
             "🦁", "🐷", "🐮", "🐔", "🦄", "🐝", "🐞", "🐍", "🦖", "🦕",
             "🐬", "🦭", "🦦", "🦥", "🦔", "🦇", "🦉", "🦚", "🦜", "🦢",
             "🦩", "🦫", "🦤", "🪿", "🪼"],
        
        "Naturaleza":
            ["🌞", "🌝", "🌧️", "⛄️", "🌈", "🌪️", "🌊", "🍃", "🌸", "🌻",
             "🌵", "🌴", "⛰️", "🌋", "🪐", "🌍", "🌎", "🌏", "🌕", "🌖",
             "🌗", "🌘", "🌑", "🌒", "🌓", "🌔", "🌙", "⭐️", "🌟", "💫",
             "☄️", "🫧", "🪸","🪨", "🪷"],
        
        "Comida":
            ["🍏", "🍎", "🍔", "🍕", "🍟", "🌭", "🍣", "🍩", "🍪", "🍫",
             "🍿", "🍞", "🍗", "🍖", "🍜", "🍛", "🥗", "🍉", "🍇", "🍒",
             "🍓", "🥝", "🍑", "🍍", "🥥", "🥑", "🍆", "🥦", "🥐", "🥨",
             "🧀", "🍚", "🍤", "🥮", "🍡", "🫘", "🫒", "🫑", "🫓"],
        
        "Celebración":
            ["🎉", "🎊", "🎈", "🥳", "🎂", "🍰", "🍾", "🥂", "🍻", "🎇",
             "🎆", "🎶", "🎵", "🎷", "🎸", "🎹", "🎺", "🎻", "🥁", "🎤",
             "🎧", "🎼", "🎭", "🎪", "🤹", "🎲", "🎳", "🎮", "🪅","🪆",
             "🎐"],
        
        "Símbolos":
            ["💔", "❣️", "💕", "💞", "💯", "⚠️", "✅", "❌", "💬", "♻️",
             "🚫", "⭕️", "❓", "❔", "‼️", "⁉️", "🔅", "🔆", "🔱", "⚜️",
             "🔰", "☢️", "☣️", "⚛️", "🕉️", "✡️", "☸️", "☮️", "🆚", "🩷",
             "🩵", "🩶", "🫷", "🫸"],
        
        "Banderas":
            ["🏳️", "🏴", "🏁", "🚩", "🏳️‍🌈", "🏳️‍⚧️", "🇪🇸", "🇺🇸", "🇫🇷", "🇩🇪",
             "🇮🇹", "🇬🇧", "🇨🇳", "🇯🇵", "🇧🇷", "🇷🇺", "🇮🇳", "🇨🇦", "🇦🇺", "🇰🇷",
             "🇲🇽", "🇦🇷", "🇨🇴", "🇿🇦", "🇳🇬", "🇪🇬", "🇹🇷", "🇸🇦", "🇮🇱", "🇸🇪",
             "🇳🇴", "🇩🇰", "🇫🇮", "🇵🇹", "🇬🇷", "🇮🇪", "🇳🇱", "🇧🇪", "🇨🇭", "🇦🇹",
             "🇵🇱", "🇨🇿", "🇸🇰", "🇭🇺", "🇷🇴", "🇧🇬", "🇭🇷", "🇷🇸", "🇺🇦", "🇧🇾",
             "🇰🇿", "🇦🇪", "🇸🇬", "🇲🇾", "🇮🇩", "🇵🇭", "🇹🇭", "🇻🇳", "🇳🇿", "🇪🇨",
             "🇵🇪", "🇨🇱", "🇵🇦", "🇨🇷", "🇺🇾", "🇵🇷", "🇯🇲", "🇹🇹", "🇧🇧", "🇧🇴",
             "🇵🇾", "🇸🇻", "🇭🇳", "🇬🇹", "🇳🇮", "🇨🇺", "🇩🇴", "🇭🇹", "🇧🇸", "🇦🇬",
             "🇻🇨", "🇬🇩", "🇰🇳", "🇱🇨", "🇲🇹", "🇨🇾", "🇱🇺", "🇲🇨", "🇦🇩", "🇸🇲",
             "🇱🇮", "🇻🇦", "🇮🇸", "🇫🇴", "🇬🇱", "🇦🇽", "🇨🇼", "🇦🇼", "🇸🇽", "🇧🇶",
             "🇲🇫", "🇵🇲", "🇹🇫", "🇳🇨", "🇵🇫", "🇧🇱", "🇲🇸", "🇬🇵", "🇲🇶", "🇷🇪",
             "🇾🇹", "🇹🇨", "🇧🇲", "🇰🇾", "🇻🇬", "🇨🇨", "🇨🇰", "🇸🇭", "🇵🇳", "🇳🇺",
             "🇵🇼", "🇦🇶", "🇹🇦", "🇮🇴", "🇩🇬", "🇦🇸", "🇻🇮", "🇲🇵", "🇬🇺", "🇼🇸",
             "🇫🇲", "🇲🇭", "🇰🇲", "🇳🇷", "🇵🇸", "🇹🇱", "🇺🇳"],
        
        "Profesiones":
            ["👨‍⚕️", "👩‍⚕️", "👨‍🍳", "👩‍🍳", "👨‍🎓", "👩‍🎓", "👨‍🏫", "👩‍🏫", "👨‍⚖️", "👩‍⚖️",
             "👨‍🌾", "👩‍🌾", "👨‍🔧", "👩‍🔧", "👨‍🚀", "👩‍🚀", "👨‍✈️", "👩‍✈️", "👨‍🔬", "👩‍🔬",
             "🧑‍🎨", "🧑‍🚒", "🧑‍✈️", "🧑‍🚀", "🧑‍⚕️", "🧑‍🍳"],
        
        "Deportes":
            ["⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱",
             "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳",
             "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷",
             "⛸️", "🥌", "🎯", "🪂"],
        
        "Transporte":
            ["🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐",
             "🛻", "🚚", "🚛", "🚜", "🛵", "🏍️", "🛺", "🚔", "🚍", "🚘",
             "🚖", "🚡", "🚠", "🚟", "🚃", "🚋", "🚞", "🚝", "🚄", "🚅",
             "🚈", "🚂", "🚆", "🚇", "🚊", "🚉", "✈️", "🛫", "🛬", "🛩️",
             "💺", "🛰️", "🚀", "🛸", "🚁", "🛶", "⛵", "🚤", "🛥️", "🛳️",
             "⛴️", "🚢", "🚧", "⛽", "🛞", "🚏", "🗺️", "🛑", "🚦"]
    ]
}

/// Selector común para todos los chats. El desplazamiento horizontal permite
/// acceder a todas las reacciones sin que iOS recorte el menú contextual.
struct MessageReactionPicker: View {
    let selectedEmoji: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EmojiData.emojiCategories["Reacciones"] ?? [], id: \.self) { emoji in
                    Button { onSelect(emoji) } label: {
                        Text(emoji)
                            .font(.system(size: 25))
                            .frame(width: 38, height: 38)
                            .background(
                                selectedEmoji == emoji ? Color.accentColor.opacity(0.28) : Color.clear,
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reaccionar con \(emoji)")
                }
            }
            .padding(6)
        }
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.secondary.opacity(0.25)))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .padding(.horizontal, 8)
    }
}

/// Resume todas las reacciones sin perder las repetidas: un emoji usado por
/// varias personas muestra su contador y la fila puede desplazarse.
struct MessageReactionSummary: View {
    let reactions: [String: String]

    private var grouped: [(emoji: String, count: Int)] {
        let counts = Dictionary(grouping: reactions.values, by: { $0 }).mapValues(\.count)
        return counts.map { ($0.key, $0.value) }.sorted {
            $0.count == $1.count ? $0.emoji < $1.emoji : $0.count > $1.count
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(grouped, id: \.emoji) { item in
                    HStack(spacing: 3) {
                        Text(item.emoji).font(.callout)
                        if item.count > 1 {
                            Text("\(item.count)").font(.caption2.bold()).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.secondary.opacity(0.2)))
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: 230, alignment: .leading)
        .accessibilityLabel("\(reactions.count) reacciones")
    }
}
