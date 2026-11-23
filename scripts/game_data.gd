class_name GameData
extends RefCounted

## All the tunable game data lives here: difficulty levels and the word list.

const WORDS_PER_LEVEL := 10

## One entry per difficulty level (index 0 = level 1).
## min_len / max_len: length of the words picked for the level
## missing_min / missing_max: how many letters are taken out of the word
## decoys: how many wrong letters are mixed in on the table
## gaps_visible: true = empty slots show where letters go, false = you must work it out
const LEVELS: Array[Dictionary] = [
	{"min_len": 3, "max_len": 4, "missing_min": 1, "missing_max": 1, "decoys": 2, "gaps_visible": true},
	{"min_len": 3, "max_len": 4, "missing_min": 1, "missing_max": 1, "decoys": 3, "gaps_visible": true},
	{"min_len": 4, "max_len": 5, "missing_min": 1, "missing_max": 2, "decoys": 4, "gaps_visible": true},
	{"min_len": 4, "max_len": 5, "missing_min": 2, "missing_max": 2, "decoys": 4, "gaps_visible": true},
	{"min_len": 5, "max_len": 7, "missing_min": 2, "missing_max": 2, "decoys": 5, "gaps_visible": false},
	{"min_len": 6, "max_len": 7, "missing_min": 2, "missing_max": 2, "decoys": 5, "gaps_visible": false},
	{"min_len": 6, "max_len": 9, "missing_min": 2, "missing_max": 3, "decoys": 6, "gaps_visible": false},
	{"min_len": 7, "max_len": 9, "missing_min": 3, "missing_max": 3, "decoys": 6, "gaps_visible": false},
	{"min_len": 8, "max_len": 11, "missing_min": 3, "missing_max": 4, "decoys": 8, "gaps_visible": false},
	{"min_len": 9, "max_len": 14, "missing_min": 4, "missing_max": 4, "decoys": 8, "gaps_visible": false},
]

## [word, meaning]. Levels pick words by length, so just add words here.
const WORDS: Array = [
	# 3 letters
	["cat", "A small furry pet that purrs and says meow."],
	["dog", "A pet that barks and wags its tail."],
	["sun", "The bright star that lights up our day."],
	["hat", "Something you wear on your head."],
	["cup", "A small container you drink from."],
	["bed", "Where you sleep at night."],
	["pig", "A pink farm animal that says oink."],
	["egg", "Chickens and other birds lay these."],
	["owl", "A wise-looking bird that hoots at night."],
	["bat", "A flying animal that sleeps upside down."],
	["fox", "A clever wild animal with a bushy red tail."],
	["map", "A drawing that shows you the way."],
	["jar", "A glass pot with a lid for storing things."],
	# 4 letters
	["moon", "It shines in the sky at night."],
	["frog", "A green animal that hops and croaks."],
	["star", "A tiny twinkling light in the night sky."],
	["book", "Pages full of stories that you read."],
	["cake", "A sweet treat for birthdays."],
	["fish", "An animal that swims in water and has fins."],
	["tree", "A tall plant with a trunk, branches and leaves."],
	["milk", "A white drink that comes from cows."],
	["rain", "Water that falls from the clouds."],
	["duck", "A bird that swims in ponds and quacks."],
	["lamp", "It gives light in a room."],
	["wand", "A magic stick used for casting spells."],
	# 5 letters
	["broom", "A witch might fly on it, or sweep the floor with it."],
	["witch", "A magical person with a pointy hat."],
	["magic", "Tricks and spells that seem impossible."],
	["apple", "A crunchy red or green fruit."],
	["bread", "Baked food used to make sandwiches."],
	["chair", "Furniture you sit on."],
	["house", "A building where people live."],
	["cloud", "A fluffy white or grey shape in the sky."],
	["snake", "A long animal with no legs that hisses."],
	["smile", "What your face does when you are happy."],
	["spoon", "You eat soup with it."],
	["plant", "A living green thing that grows in soil."],
	["ghost", "A spooky spirit that says boo."],
	# 6-7 letters
	["candle", "A stick of wax that burns to give light."],
	["potion", "A magical drink brewed in a cauldron."],
	["garden", "A place where flowers and vegetables grow."],
	["spider", "A small creature with eight legs that spins webs."],
	["rabbit", "A fluffy animal with long ears that hops."],
	["dragon", "A legendary beast that breathes fire."],
	["window", "A glass opening in a wall to let light in."],
	["pencil", "You write or draw with it."],
	["rhythm", "The beat you can clap along to in music."],
	["pumpkin", "A big orange vegetable carved at Halloween."],
	["kitchen", "The room where food is cooked."],
	["blanket", "A warm, soft cover for your bed."],
	["lantern", "A lamp with a handle that you can carry."],
	["feather", "Birds are covered in these."],
	["library", "A building full of books you can borrow."],
	["giraffe", "The tallest animal, with a very long neck."],
	# 8-9 letters
	["cauldron", "A big pot for brewing potions."],
	["mushroom", "A fungus with a cap, often found in forests."],
	["elephant", "A huge grey animal with a trunk."],
	["umbrella", "It keeps you dry in the rain."],
	["treasure", "Gold and jewels, hidden away."],
	["sandwich", "Two slices of bread with a filling between them."],
	["dinosaur", "A giant reptile that lived millions of years ago."],
	["calendar", "It shows the days, weeks and months of the year."],
	["separate", "To pull things apart, or keep them apart."],
	["february", "The shortest month of the year."],
	["butterfly", "An insect with big, colourful wings."],
	["chocolate", "A sweet brown treat made from cocoa."],
	["adventure", "An exciting journey or experience."],
	["beautiful", "Very pretty to look at."],
	["necessary", "Needed; something you must have."],
	["embarrass", "To make someone feel awkward or ashamed."],
	["wednesday", "The day after Tuesday."],
	["knowledge", "Everything you know and have learned."],
	["lightning", "A flash of light in the sky during a storm."],
	["privilege", "A special right or advantage."],
	["committee", "A group of people chosen to make decisions."],
	# 10+ letters
	["conscience", "The inner voice that tells you right from wrong."],
	["definitely", "Without any doubt."],
	["restaurant", "A place where you pay to eat a meal."],
	["government", "The group of people who run a country."],
	["silhouette", "A dark shape seen against a light background."],
	["millennium", "A period of a thousand years."],
	["apparently", "As far as you can tell; it seems that."],
	["mischievous", "Playfully naughty."],
	["accommodate", "To make room for someone or something."],
	["environment", "The world around us: air, water, land and nature."],
	["occasionally", "Now and then; not very often."],
	["pronunciation", "The way a word is said out loud."],
	["questionnaire", "A list of questions for people to answer."],
]

## The vague picture that rises in the brew after a while.
## Placeholder: Windows emoji for now. Later these can point to real drawings.
const PICTURES := {
	"cat": "🐱", "dog": "🐶", "sun": "🌞", "hat": "🎩", "cup": "☕", "bed": "🛏", "pig": "🐷",
	"egg": "🥚", "owl": "🦉", "bat": "🦇", "fox": "🦊", "map": "🗺", "jar": "🏺",
	"moon": "🌙", "frog": "🐸", "star": "⭐", "book": "📖", "cake": "🎂", "fish": "🐟",
	"tree": "🌳", "milk": "🥛", "rain": "🌧", "duck": "🦆", "lamp": "💡", "wand": "✨",
	"broom": "🧹", "witch": "🧙", "magic": "🔮", "apple": "🍎", "bread": "🍞", "chair": "💺",
	"house": "🏠", "cloud": "☁", "snake": "🐍", "smile": "😊", "spoon": "🥄", "plant": "🌱",
	"ghost": "👻", "candle": "🕯", "potion": "🧪", "garden": "🌷", "spider": "🕷", "rabbit": "🐰",
	"dragon": "🐉", "window": "🖼", "pencil": "✏", "rhythm": "🥁", "pumpkin": "🎃",
	"kitchen": "🍳", "blanket": "🛌", "lantern": "🏮", "feather": "🕊", "library": "📚",
	"giraffe": "🦒", "cauldron": "🍲", "mushroom": "🍄", "elephant": "🐘", "umbrella": "☂",
	"treasure": "💎", "sandwich": "🥪", "dinosaur": "🦕", "calendar": "📅", "separate": "✂",
	"february": "❄", "butterfly": "🦋", "chocolate": "🍫", "adventure": "🧭", "beautiful": "🌸",
	"necessary": "❗", "embarrass": "😳", "wednesday": "📆", "knowledge": "🧠", "lightning": "⚡",
	"privilege": "👑", "committee": "👥", "conscience": "😇", "definitely": "👍",
	"restaurant": "🍽", "government": "🏛", "silhouette": "👤", "millennium": "⏳",
	"apparently": "🤷", "mischievous": "😈", "accommodate": "🏨", "environment": "🌍",
	"occasionally": "🔁", "pronunciation": "🗣", "questionnaire": "📋",
}

## Extra common words. They are never asked, but the puzzle maker checks them
## so decoy letters never accidentally spell a *different* real word.
const CHECK_WORDS := """
cat cot cut can cap car cab bat bag bad bed bet bit but bus bun bud big bog dog dig dug den dot
fan fat fig fin fit fix fox fun fur gap gas get got gum hat had ham has hen hid him hip his hit
hog hop hot hug hum hut jam jar jet jog jug kid kit lap leg let lid lip lit log lot mad man map
mat men met mix mop mud mug nap net nod not nut pan pat pen pet pig pin pit pot pup rag ram ran
rat red rib rid rip rod rot rub rug run sad sat sit six sob sun tag tan tap ten tin tip top tub
tug van vet wag web wet win wig yes yet zip bar far tar war saw paw raw jaw law cow how now row
bow low owl egg eye sky try fly dry cry why cop hop mop pop sop toy boy joy ice age ape art arm
ant ask ate air ago aid ear eat end elf elm ink inn ion odd oil old one our out own use
moon moan mood soon noon book look cook took hook nook cake bake lake make rake sake take wake
fake fish dish wish tree free milk silk rain pain main gain vain duck luck tuck suck lamp camp
damp ramp star scar stir frog from crow grow brow wand band hand land sand bend wind
broom groom bloom witch pitch ditch hitch magic apple bread broad chair charm house mouse cloud
proud snake shake smile spoon spool plant slant ghost host most post toast boast
candle handle potion motion garden harden spider rabbit dragon window pencil
"""
