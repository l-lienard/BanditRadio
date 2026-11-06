-- Bandit Radio - textes des messages radio (MODIFIABLES)
--
-- Chaque type d'événement a jusqu'à 3 niveaux de détail :
--   full    : info complète (faction, effectif, lieu précis)
--   partial : info partielle (pas de faction, lieu approximatif)
--   rumor   : simple rumeur
-- Un niveau peut contenir UNE phrase ou une LISTE de phrases (tirée au hasard).
-- Un niveau manquant se rabat sur le suivant (full -> partial -> rumor).
--
-- Variables disponibles :
--   {n}       effectif du groupe        {pos}    position (avec bâtiment)
--   {area}    zone large (ville)        {from}   point de départ
--   {dest}    destination               {eta}    temps d'arrivée estimé
--   {player}  joueur visé               {lost}   hommes perdus
--   {left}    hommes restants           {other}  autre faction (affrontement)
--   {vehicle} " en véhicule" ou ""      {total}  total d'hommes (rassemblement)
--
-- Ajouter une langue : copie le bloc EN, change la clé ("DE", "ES"...),
-- traduis, et ajoute aussi la langue dans BanditRadio.Strings (BR_Config.lua).
-- Autre mod : BanditRadio.API.addMessages("FR", "mon_event", { full = "..." })

BanditRadio = BanditRadio or {}

BanditRadio.Messages = {
    EN = {
        _prefix = { full = "[{faction}] ", partial = "[???] ", rumor = "(rumor) " },
        _vehicle = " by vehicle",
        _eta_min = "~{m} min", _eta_h = "~{h}h",

        contact = {
            full = "New contact: {n} men spotted {pos}.",
            partial = "A group was spotted {area}.",
            rumor = "Someone saw armed people {area}.",
        },
        move = {
            full = "Group of {n} leaving {from}{vehicle}, heading to {dest}. ETA {eta}.",
            partial = "A group is moving{vehicle} toward {dest}.",
            rumor = { "Word is someone is on the road to {dest}.", "Movement reported toward {dest}." },
        },
        move_dir = {
            full = "Group of {n} on the move{vehicle} {pos}, heading {dir}.",
            partial = "A group is moving {area}.",
            rumor = "Footsteps heard {area}...",
        },
        arrive = {
            full = "Group of {n} has arrived {pos}.",
            partial = "A group just showed up {area}.",
            rumor = "New faces {area}, apparently.",
        },
        loot = {
            full = "{n} men are looting {pos}.",
            partial = "Someone is looting {pos}.",
            rumor = { "Heard breaking glass {area}.", "Looks like a place got ransacked {area}." },
        },
        camp = {
            full = "Group of {n} has set up camp {pos}.",
            partial = "A group seems to be settling {area}.",
            rumor = "Campfire smoke seen {area}.",
        },
        rest = {
            full = "Group of {n} is resting {pos}. Few guards.",
            partial = "A group is lying low {area}.",
            rumor = "It's quiet {area}... too quiet.",
        },
        gunfire = {
            full = { "Gunshots! {n} armed men firing {pos}.", "Firefight {pos}, {n} shooters." },
            partial = "Gunshots heard {pos}.",
            rumor = "Distant shots echoed {area}.",
        },
        fight_zombies = {
            full = "Group of {n} fighting the dead {pos}.",
            partial = "A group is fighting zombies {area}.",
            rumor = "Screams and noise {area}.",
        },
        overrun = {
            full = "Group is being overrun by a horde {pos}! {left} still standing.",
            partial = "A group is getting overrun {area}!",
            rumor = "Sounds like someone got swarmed {area}.",
        },
        hunt = {
            full = "Group of {n} is hunting {player}! Last heard {pos}.",
            partial = "Someone is tracking {player}.",
            rumor = "They're talking about a lone survivor {area}...",
        },
        approach = {
            full = "Group of {n} closing in on {player}, now {pos}. ETA {eta}.",
            partial = "A group is getting closer to {player}.",
            rumor = "They mention a survivor nearby {area}...",
        },
        clash = {
            full = "Clash between {faction} and {other} {pos}!",
            partial = "Two gangs are fighting {area}.",
            rumor = "Gang trouble {area}, they say.",
        },
        loss = {
            full = "Lost {lost} men {pos}. {left} left.",
            partial = "A group took losses {area}.",
            rumor = "Someone didn't make it {area}.",
        },
        wiped = {
            full = "Group wiped out {pos}. Bodies and gear left behind.",
            partial = "A whole group was wiped out {area}.",
            rumor = "Nobody's answering {area} anymore...",
        },
        gone = {
            full = "Group went silent. Last known position: {pos}.",
            partial = "Lost contact with a group {area}.",
        },
        reinforced = {
            full = "Reinforcements arrived {pos}: now {n} men.",
            partial = "A group got bigger {area}.",
            rumor = "More of them {area}...",
        },
        gathering = {
            full = "{total} men gathering {area}. Something big is coming.",
            partial = "Several groups gathering {area}.",
            rumor = "Lots of chatter about {area} tonight.",
        },
        ambient = {
            rumor = {
                "...anyone copy? ...kzzt...",
                "Keep the channel clear.",
                "Saw fires in the woods {area}.",
                "Stay low tonight, the dead are restless.",
                "...repeat, the bridge is... kzzt...",
                "Who took the last batteries?!",
                "Heard a helicopter {area}. Probably nothing.",
            },
        },
    },

    FR = {
        _prefix = { full = "[{faction}] ", partial = "[???] ", rumor = "(rumeur) " },
        _vehicle = " en véhicule",
        _eta_min = "~{m} min", _eta_h = "~{h}h",

        contact = {
            full = "Nouveau contact : {n} hommes repérés {pos}.",
            partial = "Un groupe a été repéré {area}.",
            rumor = "Quelqu'un a vu des gens armés {area}.",
        },
        move = {
            full = "Groupe de {n} parti de {from}{vehicle}, direction {dest}. Arrivée {eta}.",
            partial = "Un groupe se déplace{vehicle} vers {dest}.",
            rumor = { "Il paraît que des types sont en route vers {dest}.", "On signale du mouvement vers {dest}." },
        },
        move_dir = {
            full = "Groupe de {n} en mouvement{vehicle} {pos}, cap {dir}.",
            partial = "Un groupe bouge {area}.",
            rumor = "Des bruits de pas {area}...",
        },
        arrive = {
            full = "Groupe de {n} arrivé {pos}.",
            partial = "Un groupe vient d'arriver {area}.",
            rumor = "Des nouvelles têtes {area}, apparemment.",
        },
        loot = {
            full = "{n} hommes pillent {pos}.",
            partial = "Quelqu'un pille {pos}.",
            rumor = { "Des bruits de verre brisé {area}.", "On dirait qu'un endroit a été retourné {area}." },
        },
        camp = {
            full = "Groupe de {n} installé en camp {pos}.",
            partial = "Un groupe semble s'installer {area}.",
            rumor = "De la fumée de feu de camp {area}.",
        },
        rest = {
            full = "Groupe de {n} au repos {pos}. Peu de gardes.",
            partial = "Un groupe se fait discret {area}.",
            rumor = "C'est calme {area}... trop calme.",
        },
        gunfire = {
            full = { "Coups de feu ! {n} hommes armés tirent {pos}.", "Fusillade {pos}, {n} tireurs." },
            partial = "Des coups de feu ont été entendus {pos}.",
            rumor = "Des tirs au loin {area}.",
        },
        fight_zombies = {
            full = "Groupe de {n} aux prises avec des zombies {pos}.",
            partial = "Un groupe se bat contre des zombies {area}.",
            rumor = "Des cris et du bruit {area}.",
        },
        overrun = {
            full = "Groupe submergé par une horde {pos} ! Plus que {left} debout.",
            partial = "Un groupe se fait déborder {area} !",
            rumor = "On dirait que quelqu'un s'est fait encercler {area}.",
        },
        hunt = {
            full = "Groupe de {n} sur la piste de {player} ! Dernière position {pos}.",
            partial = "Quelqu'un traque {player}.",
            rumor = "Ils parlent d'un survivant seul {area}...",
        },
        approach = {
            full = "Groupe de {n} se rapproche de {player}, actuellement {pos}. Arrivée {eta}.",
            partial = "Un groupe se rapproche de {player}.",
            rumor = "Ils mentionnent un survivant pas loin {area}...",
        },
        clash = {
            full = "Affrontement entre {faction} et {other} {pos} !",
            partial = "Deux bandes s'affrontent {area}.",
            rumor = "Ça règle des comptes {area}, paraît-il.",
        },
        loss = {
            full = "{lost} hommes perdus {pos}. Il en reste {left}.",
            partial = "Un groupe a subi des pertes {area}.",
            rumor = "Quelqu'un n'a pas survécu {area}.",
        },
        wiped = {
            full = "Groupe anéanti {pos}. Corps et équipement sur place.",
            partial = "Un groupe entier a été anéanti {area}.",
            rumor = "Plus personne ne répond {area}...",
        },
        gone = {
            full = "Le groupe ne répond plus. Dernière position : {pos}.",
            partial = "Contact perdu avec un groupe {area}.",
        },
        reinforced = {
            full = "Des renforts sont arrivés {pos} : {n} hommes maintenant.",
            partial = "Un groupe s'est agrandi {area}.",
            rumor = "Ils sont de plus en plus nombreux {area}...",
        },
        gathering = {
            full = "{total} hommes se rassemblent {area}. Ça prépare un gros coup.",
            partial = "Plusieurs groupes se rassemblent {area}.",
            rumor = "Beaucoup de bavardages à propos de {area} ce soir.",
        },
        ambient = {
            rumor = {
                "...quelqu'un me reçoit ? ...kzzt...",
                "Libérez le canal.",
                "J'ai vu des feux dans les bois {area}.",
                "Faites-vous discrets ce soir, les morts sont agités.",
                "...je répète, le pont est... kzzt...",
                "Qui a pris les dernières piles ?!",
                "Entendu un hélico {area}. Sûrement rien.",
            },
        },
    },
}
