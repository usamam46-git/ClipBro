import Foundation

struct Emoji: Identifiable {
    let symbol: String
    let name: String
    let category: String
    var id: String { symbol }
    func matches(_ query: String) -> Bool { query.isEmpty || name.localizedStandardContains(query) || symbol.contains(query) || category.localizedStandardContains(query) }
    // A curated local Unicode collection; descriptions authored for this app.
    static let all: [Emoji] = {
        let groups: [(String, String)] = [
            ("Smileys", "😀|grinning happy;😃|smile happy;😄|laugh smile;😁|beaming grin;😆|laughing;😅|sweat smile;😂|tears joy laugh;🤣|rolling laughter;🙂|slight smile;🙃|upside down;😉|wink;😊|blush happy;😇|angel;🥰|love hearts;😍|heart eyes;🤩|star eyes;😘|kiss;😋|delicious;😎|cool sunglasses;🥳|party celebrate;🤔|thinking;🫡|salute;🤗|hug;🤫|quiet;🫠|melting;😴|sleep;😭|cry;😤|frustrated;😡|angry;🤯|mind blown;🥺|pleading;😬|grimace;🙄|eye roll"),
            ("People", "👩‍💻|woman technologist developer;👨‍💻|man technologist developer;🧑‍💻|technologist coder;👩🏽‍💻|woman technologist medium skin;🧑‍🎨|artist;🧑‍🚀|astronaut;🧑‍🔬|scientist;👨‍👩‍👧‍👦|family;🧑‍🤝‍🧑|people holding hands;🦸|superhero;🧘|meditation"),
            ("Gestures", "👍|thumbs up yes;👍🏻|thumbs up light;👍🏽|thumbs up medium;👍🏿|thumbs up dark;👎|thumbs down;👏|clap applause;🙌|raised hands celebration;🤝|handshake deal;🙏|thanks pray;💪|strong muscle;✌️|peace victory;🤞|fingers crossed;👋|wave hello;👌|okay;🤌|pinched fingers;🫶|heart hands;👉|point right;👈|point left;☝️|point up"),
            ("Animals", "🐶|dog;🐱|cat;🐭|mouse;🐹|hamster;🐰|rabbit;🦊|fox;🐻|bear;🐼|panda;🐨|koala;🐯|tiger;🦁|lion;🐮|cow;🐷|pig;🐸|frog;🐵|monkey;🐧|penguin;🦋|butterfly;🐝|bee;🐢|turtle;🐙|octopus;🐬|dolphin;🦄|unicorn"),
            ("Food", "🍎|apple;🍌|banana;🍓|strawberry;🥑|avocado;🍕|pizza;🍔|burger;🍟|fries;🌮|taco;🍜|noodles;🍣|sushi;🍩|donut;🍪|cookie;🎂|birthday cake;☕️|coffee;🍵|tea;🧋|bubble tea;🥤|drink;🍿|popcorn"),
            ("Travel", "🚀|rocket launch;✈️|airplane flight;🚗|car;🚕|taxi;🚌|bus;🚲|bicycle;🚆|train;🚢|ship;🏠|house home;🏢|office;🏖️|beach;🏔️|mountain;🌍|earth world;🌙|moon;☀️|sun;🌈|rainbow;⭐️|star;🌧️|rain"),
            ("Objects", "💻|laptop computer;⌨️|keyboard;📱|phone mobile;💡|idea lightbulb;🔧|wrench fix;⚙️|gear settings;🛠️|tools;🔒|lock secure;🔑|key;📌|pin;📎|paperclip;📋|clipboard;📝|memo notes;📚|books;📦|package;🎁|gift;🎉|party celebration;🏆|trophy win;💰|money;📊|chart;📈|growth;🔍|search;🧪|test experiment"),
            ("Symbols", "❤️|red heart love;🧡|orange heart;💛|yellow heart;💚|green heart;💙|blue heart;💜|purple heart;🖤|black heart;🤍|white heart;✅|check done;❌|cross no;⚠️|warning;❓|question;❗️|important exclamation;💯|hundred perfect;🔥|fire;✨|sparkles;⚡️|lightning fast;💤|sleep;♻️|recycle;➕|plus;➖|minus;➡️|arrow right;⬅️|arrow left;🔴|red circle;🟢|green circle;🔵|blue circle"),
            ("Flags", "🇵🇰|Pakistan;🇺🇸|United States USA;🇬🇧|United Kingdom UK;🇨🇦|Canada;🇦🇺|Australia;🇩🇪|Germany;🇫🇷|France;🇯🇵|Japan;🇮🇳|India;🇦🇪|United Arab Emirates UAE;🇸🇦|Saudi Arabia;🇹🇷|Turkey;🇨🇳|China;🇧🇷|Brazil;🇪🇺|European Union;🏳️‍🌈|rainbow pride;🏁|checkered finish")
        ]
        return groups.flatMap { category, data in data.split(separator: ";").map { part in
            let pair = part.split(separator: "|", maxSplits: 1)
            return Emoji(symbol: String(pair[0]), name: String(pair[1]), category: category)
        } }
    }()
}
