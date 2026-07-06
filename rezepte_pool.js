// =====================================================
// FamilyRoots — KOCHBUCH-Rezept-Pool (statisch, read-only, mehrsprachig)
// Wird wie i18n.js VOR dem Haupt-Script geladen (definiert globale const REZEPT_POOL).
// Speist den Filter „Kochbuch" UND das „Gericht des Tages" (deterministisch nach Datum,
// rein clientseitig — kein Backend).
//
// STRUKTUR je Rezept:
//   {
//     id, kueche, portionen, dauer_min,
//     titel:  { de, sr, hr, ba, en },
//     zutaten: [ { menge:Number|null, einheit:'<code>', name:{ de,sr,hr,ba,en } }, … ],
//     schritte:{ de:[…], sr:[…], hr:[…], ba:[…], en:[…] }
//   }
// Anzeige in der AKTUELLEN App-Sprache; fehlt eine Sprache -> Fallback + Hinweis.
//
// EINHEITEN-CODES (werden im Frontend lokalisiert, halten die Datei schlank):
//   g, kg, ml, l, stk (Stück), el (EL), tl (TL), prise, kopf, bund, zehe, ng (nach Geschmack)
//
// RECHT: eigenständig formulierte Rezepte (Gerichtsnamen wie „Sarma" sind nicht schützbar).
// =====================================================

const REZEPT_POOL = [

  // ---- BALKAN --------------------------------------------------------------
  {
    id: 'sarma', kueche: 'balkan', portionen: 6, dauer_min: 150,
    titel: { de: 'Sarma (Kohlrouladen)', sr: 'Сарма', hr: 'Sarma', ba: 'Sarma', en: 'Sarma (stuffed cabbage rolls)' },
    zutaten: [
      { menge: 1,   einheit: 'kopf', name: { de: 'Saurer Kohl (ganzer Kopf)', sr: 'кисели купус (цела глава)', hr: 'kiseli kupus (cijela glava)', ba: 'kiseli kupus (cijela glava)', en: 'sour cabbage (whole head)' } },
      { menge: 500, einheit: 'g',    name: { de: 'gemischtes Hackfleisch', sr: 'мешано млевено месо', hr: 'miješano mljeveno meso', ba: 'miješano mljeveno meso', en: 'mixed ground meat' } },
      { menge: 150, einheit: 'g',    name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 2,   einheit: 'stk',  name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 100, einheit: 'g',    name: { de: 'geräucherter Speck', sr: 'сува сланина', hr: 'suha slanina', ba: 'suha slanina', en: 'smoked bacon' } },
      { menge: 2,   einheit: 'el',   name: { de: 'Tomatenmark', sr: 'паста од парадајза', hr: 'pasta od rajčice', ba: 'pasta od rajčice', en: 'tomato paste' } },
      { menge: 1,   einheit: 'tl',   name: { de: 'Paprikapulver (edelsüß)', sr: 'алева паприка', hr: 'crvena mljevena paprika', ba: 'crvena mljevena paprika', en: 'sweet paprika' } },
      { menge: 1,   einheit: 'stk',  name: { de: 'Lorbeerblatt', sr: 'ловоров лист', hr: 'lovorov list', ba: 'lovorov list', en: 'bay leaf' } },
      { menge: null, einheit: 'ng',  name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } }
    ],
    schritte: {
      de: [
        'Reis kurz in Wasser einweichen und abtropfen lassen.',
        'Zwiebel fein hacken und in etwas Öl glasig anbraten.',
        'Hackfleisch mit Reis, Zwiebel, Paprikapulver, Salz und Pfeffer vermengen.',
        'Kohlblätter vom Kopf lösen, dicke Rippen flach schneiden. Je 1–2 EL Füllung aufrollen, Enden einschlagen.',
        'Topfboden mit gehacktem Kohl und Speck auslegen, die Rouladen dicht einschichten.',
        'Tomatenmark in Wasser verrühren, mit Lorbeer angießen bis knapp bedeckt.',
        'Zugedeckt bei schwacher Hitze ca. 2 Stunden schmoren; über Nacht ziehen lassen schmeckt am besten.'
      ],
      sr: [
        'Пиринач кратко потопити у воду и оцедити.',
        'Црни лук ситно исецкати и продинстати на мало уља.',
        'Млевено месо помешати са пиринчем, луком, алевом паприком, сољу и бибером.',
        'Одвојити листове купуса, задебљале жиле стањити. На сваки лист ставити 1–2 кашике фила и чврсто уролати.',
        'Дно шерпе обложити сецканим купусом и сланином, сарме густо сложити.',
        'Пасту од парадајза размутити у води, залити са ловоровим листом да једва прекрије.',
        'Поклопљено динстати на тихој ватри око 2 сата; најбоље је да одстоји преко ноћи.'
      ],
      hr: [
        'Rižu kratko namočiti u vodi i ocijediti.',
        'Luk sitno nasjeckati i pirjati na malo ulja dok ne omekša.',
        'Mljeveno meso pomiješati s rižom, lukom, paprikom, soli i paprom.',
        'Odvojiti listove kupusa, deblje žile stanjiti. Na svaki list staviti 1–2 žlice nadjeva i čvrsto zamotati.',
        'Dno lonca obložiti nasjeckanim kupusom i slaninom, sarme gusto složiti.',
        'Pastu od rajčice razmutiti u vodi, preliti s lovorom da jedva prekrije.',
        'Poklopljeno pirjati na laganoj vatri oko 2 sata; najbolje je da odstoji preko noći.'
      ],
      ba: [
        'Rižu kratko namočiti u vodi i ocijediti.',
        'Luk sitno nasjeckati i dinstati na malo ulja dok ne omekša.',
        'Mljeveno meso pomiješati sa rižom, lukom, paprikom, soli i biberom.',
        'Odvojiti listove kupusa, deblje žile stanjiti. Na svaki list staviti 1–2 kašike nadjeva i čvrsto zamotati.',
        'Dno lonca obložiti nasjeckanim kupusom i slaninom, sarme gusto složiti.',
        'Pastu od rajčice razmutiti u vodi, preliti sa lovorom da jedva prekrije.',
        'Poklopljeno dinstati na laganoj vatri oko 2 sata; najbolje je da odstoji preko noći.'
      ],
      en: [
        'Briefly soak the rice in water and drain.',
        'Finely chop the onion and sauté in a little oil until soft.',
        'Mix the ground meat with rice, onion, paprika, salt and pepper.',
        'Separate the cabbage leaves, thin out thick ribs. Put 1–2 tbsp filling on each leaf and roll up tightly.',
        'Line the pot base with chopped cabbage and bacon, layer the rolls tightly.',
        'Stir tomato paste into water, pour over with the bay leaf until just covered.',
        'Cover and simmer on low heat for about 2 hours; it tastes best after resting overnight.'
      ]
    }
  },

  {
    id: 'cevapi', kueche: 'balkan', portionen: 4, dauer_min: 40,
    titel: { de: 'Ćevapi (Hackfleischröllchen)', sr: 'Ћевапи', hr: 'Ćevapi', ba: 'Ćevapi', en: 'Ćevapi (grilled minced rolls)' },
    zutaten: [
      { menge: 600, einheit: 'g',   name: { de: 'Rinderhack (oder gemischt)', sr: 'јунеће млевено месо', hr: 'juneće mljeveno meso', ba: 'juneće mljeveno meso', en: 'ground beef (or mixed)' } },
      { menge: 3,   einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 0.5, einheit: 'tl',   name: { de: 'Natron', sr: 'сода бикарбона', hr: 'soda bikarbona', ba: 'soda bikarbona', en: 'baking soda' } },
      { menge: 1,   einheit: 'tl',   name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } },
      { menge: 0.5, einheit: 'tl',   name: { de: 'Pfeffer', sr: 'бибер', hr: 'papar', ba: 'biber', en: 'pepper' } },
      { menge: 2,   einheit: 'stk',  name: { de: 'Zwiebel (zum Servieren)', sr: 'црни лук (за сервирање)', hr: 'luk (za posluživanje)', ba: 'luk (za posluživanje)', en: 'onion (to serve)' } },
      { menge: 4,   einheit: 'stk',  name: { de: 'Fladenbrot (Lepinja)', sr: 'лепиња', hr: 'lepinja', ba: 'lepinja', en: 'flatbread (lepinja)' } }
    ],
    schritte: {
      de: [
        'Knoblauch fein zerdrücken. Mit Hack, Natron, Salz und Pfeffer gründlich verkneten.',
        'Masse abgedeckt mind. 2 Stunden (besser über Nacht) im Kühlschrank ruhen lassen.',
        'Mit feuchten Händen kleine, fingerdicke Röllchen formen.',
        'Auf heißem Grill oder in der Pfanne rundum kräftig braten, bis sie gebräunt und durch sind.',
        'Mit gehackter roher Zwiebel im warmen Fladenbrot servieren (klassisch mit Ajvar oder Kajmak).'
      ],
      sr: [
        'Бели лук ситно изгњечити. Са месом, содом, сољу и бибером добро умесити.',
        'Масу поклопити и оставити у фрижидеру најмање 2 сата (боље преко ноћи).',
        'Влажним рукама обликовати мале ваљчиће дебљине прста.',
        'На врелом роштиљу или у тигању испржити са свих страна док не порумене и буду печени.',
        'Сервирати са сецканим сировим луком у топлој лепињи (класично уз ајвар или кајмак).'
      ],
      hr: [
        'Češnjak sitno zgnječiti. S mesom, sodom, soli i paprom dobro umijesiti.',
        'Masu poklopiti i ostaviti u hladnjaku najmanje 2 sata (bolje preko noći).',
        'Vlažnim rukama oblikovati male valjke debljine prsta.',
        'Na vrućem roštilju ili u tavi ispržiti sa svih strana dok ne porumene i budu pečeni.',
        'Poslužiti s nasjeckanim sirovim lukom u toploj lepinji (klasično uz ajvar ili kajmak).'
      ],
      ba: [
        'Bijeli luk sitno zgnječiti. Sa mesom, sodom, soli i biberom dobro umijesiti.',
        'Masu poklopiti i ostaviti u frižideru najmanje 2 sata (bolje preko noći).',
        'Vlažnim rukama oblikovati male valjke debljine prsta.',
        'Na vrućem roštilju ili u tavi ispržiti sa svih strana dok ne porumene i budu pečeni.',
        'Poslužiti sa nasjeckanim sirovim lukom u toploj lepinji (klasično uz ajvar ili kajmak).'
      ],
      en: [
        'Finely crush the garlic. Knead well with the meat, baking soda, salt and pepper.',
        'Cover the mixture and rest in the fridge for at least 2 hours (ideally overnight).',
        'With damp hands, shape small finger-thick rolls.',
        'Grill or pan-fry on high heat on all sides until browned and cooked through.',
        'Serve with chopped raw onion in warm flatbread (classically with ajvar or kajmak).'
      ]
    }
  },

  {
    id: 'grah', kueche: 'balkan', portionen: 5, dauer_min: 120,
    titel: { de: 'Grah / Pasulj (Bohneneintopf)', sr: 'Пасуљ', hr: 'Grah', ba: 'Grah', en: 'Bean stew (grah/pasulj)' },
    zutaten: [
      { menge: 400, einheit: 'g',   name: { de: 'weiße Bohnen (getrocknet)', sr: 'бели пасуљ (сув)', hr: 'bijeli grah (suhi)', ba: 'bijeli grah (suhi)', en: 'dried white beans' } },
      { menge: 200, einheit: 'g',   name: { de: 'geräuchertes Fleisch/Rippen', sr: 'сувомеснато / ребра', hr: 'suho meso / rebra', ba: 'suho meso / rebra', en: 'smoked meat / ribs' } },
      { menge: 2,   einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Karotte', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrot' } },
      { menge: 2,   einheit: 'el',  name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 1,   einheit: 'tl',  name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: 2,   einheit: 'stk', name: { de: 'Lorbeerblatt', sr: 'ловоров лист', hr: 'lovorov list', ba: 'lovorov list', en: 'bay leaf' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } }
    ],
    schritte: {
      de: [
        'Bohnen über Nacht in kaltem Wasser einweichen, dann abgießen.',
        'Bohnen mit Räucherfleisch, einer Zwiebel, Karotte und Lorbeer in frischem Wasser aufsetzen.',
        'Bei mittlerer Hitze ca. 1,5 Stunden köcheln, bis die Bohnen weich sind.',
        'Für die Einbrenne restliche Zwiebel fein hacken, in Öl anbraten, Mehl und Paprikapulver einrühren.',
        'Einbrenne mit etwas Sud glattrühren und in den Topf geben; kurz aufkochen und binden lassen.',
        'Mit Salz und Pfeffer abschmecken; mit Brot servieren.'
      ],
      sr: [
        'Пасуљ потопити преко ноћи у хладну воду, затим оцедити.',
        'Пасуљ ставити да се кува у свежој води са сувомеснатим, једним луком, шаргарепом и ловором.',
        'Кувати на средњој ватри око 1,5 сат док пасуљ не омекша.',
        'За запршку преостали лук ситно исецкати, пропржити на уљу, додати брашно и алеву паприку.',
        'Запршку размутити мало супе и сипати у лонац; прокувати да се згусне.',
        'Зачинити сољу и бибером; послужити уз хлеб.'
      ],
      hr: [
        'Grah namočiti preko noći u hladnu vodu, zatim ocijediti.',
        'Grah staviti kuhati u svježoj vodi sa suhim mesom, jednim lukom, mrkvom i lovorom.',
        'Kuhati na srednjoj vatri oko 1,5 sat dok grah ne omekša.',
        'Za zapršku preostali luk sitno nasjeckati, popržiti na ulju, dodati brašno i papriku.',
        'Zapršku razmutiti s malo temeljca i uliti u lonac; prokuhati da se zgusne.',
        'Začiniti soli i paprom; poslužiti uz kruh.'
      ],
      ba: [
        'Grah namočiti preko noći u hladnu vodu, zatim ocijediti.',
        'Grah staviti da se kuha u svježoj vodi sa suhim mesom, jednim lukom, mrkvom i lovorom.',
        'Kuhati na srednjoj vatri oko 1,5 sat dok grah ne omekša.',
        'Za zapršku preostali luk sitno nasjeckati, popržiti na ulju, dodati brašno i papriku.',
        'Zapršku razmutiti sa malo temeljca i uliti u lonac; prokuhati da se zgusne.',
        'Začiniti soli i biberom; poslužiti uz hljeb.'
      ],
      en: [
        'Soak the beans overnight in cold water, then drain.',
        'Cook the beans in fresh water with smoked meat, one onion, carrot and bay leaves.',
        'Simmer on medium heat for about 1.5 hours until the beans are soft.',
        'For the roux, finely chop the remaining onion, fry in oil, stir in flour and paprika.',
        'Loosen the roux with a little broth and add to the pot; boil briefly to thicken.',
        'Season with salt and pepper; serve with bread.'
      ]
    }
  },

  {
    id: 'sopska', kueche: 'balkan', portionen: 4, dauer_min: 15,
    titel: { de: 'Šopska-Salat', sr: 'Шопска салата', hr: 'Šopska salata', ba: 'Šopska salata', en: 'Shopska salad' },
    zutaten: [
      { menge: 3,   einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 2,   einheit: 'stk', name: { de: 'Salatgurken', sr: 'краставци', hr: 'krastavci', ba: 'krastavci', en: 'cucumbers' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 150, einheit: 'g',   name: { de: 'Schafskäse (Sirene/Feta)', sr: 'сир (сирене)', hr: 'sir (feta)', ba: 'sir (feta)', en: 'white cheese (feta)' } },
      { menge: 2,   einheit: 'el',  name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: 1,   einheit: 'el',  name: { de: 'Weinessig', sr: 'винско сирће', hr: 'vinski ocat', ba: 'vinsko sirće', en: 'wine vinegar' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: [
        'Tomaten, Gurken und Paprika in mundgerechte Stücke schneiden.',
        'Zwiebel in feine Ringe schneiden und untermischen.',
        'Mit Öl, Essig und Salz vorsichtig vermengen.',
        'Zum Schluss den Käse grob darüberreiben oder zerbröseln. Sofort servieren.'
      ],
      sr: [
        'Парадајз, краставце и паприку исећи на залогаје.',
        'Црни лук исећи на танке колутове и умешати.',
        'Зачинити уљем, сирћетом и сољу, лагано промешати.',
        'На крају сир крупно нарендати или измрвити преко салате. Одмах послужити.'
      ],
      hr: [
        'Rajčice, krastavce i papriku narezati na zalogaje.',
        'Luk narezati na tanke kolutove i umiješati.',
        'Začiniti uljem, octom i soli, lagano promiješati.',
        'Na kraju sir krupno naribati ili izmrviti preko salate. Odmah poslužiti.'
      ],
      ba: [
        'Paradajz, krastavce i papriku narezati na zalogaje.',
        'Luk narezati na tanke kolutove i umiješati.',
        'Začiniti uljem, sirćetom i soli, lagano promiješati.',
        'Na kraju sir krupno naribati ili izmrviti preko salate. Odmah poslužiti.'
      ],
      en: [
        'Cut tomatoes, cucumbers and pepper into bite-sized pieces.',
        'Slice the onion into thin rings and mix in.',
        'Season with oil, vinegar and salt, toss gently.',
        'Finally grate or crumble the cheese generously on top. Serve immediately.'
      ]
    }
  },

  {
    id: 'palacinke', kueche: 'balkan', portionen: 4, dauer_min: 30,
    titel: { de: 'Palatschinken (Palačinke)', sr: 'Палачинке', hr: 'Palačinke', ba: 'Palačinke', en: 'Thin pancakes (palačinke)' },
    zutaten: [
      { menge: 200, einheit: 'g',   name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 2,   einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 400, einheit: 'ml',  name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 1,   einheit: 'prise', name: { de: 'Salz', sr: 'прстохват соли', hr: 'prstohvat soli', ba: 'prstohvat soli', en: 'pinch of salt' } },
      { menge: 1,   einheit: 'el',  name: { de: 'Öl (für den Teig)', sr: 'уље (за тесто)', hr: 'ulje (za tijesto)', ba: 'ulje (za tijesto)', en: 'oil (for the batter)' } },
      { menge: null, einheit: 'ng', name: { de: 'Marmelade oder Nuss-Nougat-Creme', sr: 'џем или крем', hr: 'džem ili krema', ba: 'džem ili krema', en: 'jam or chocolate spread' } }
    ],
    schritte: {
      de: [
        'Mehl, Eier, Salz und die Hälfte der Milch zu einem glatten Teig verrühren.',
        'Restliche Milch und das Öl einrühren, bis ein dünnflüssiger Teig entsteht. 10 Min. ruhen lassen.',
        'Eine beschichtete Pfanne erhitzen, dünn mit Teig ausgießen und schwenken.',
        'Bei mittlerer Hitze goldbraun backen, wenden und kurz fertigbacken.',
        'Mit Marmelade oder Creme bestreichen, aufrollen und servieren.'
      ],
      sr: [
        'Брашно, јаја, со и половину млека умутити у глатко тесто.',
        'Додати остатак млека и уље док не добијете ретко тесто. Оставити 10 минута.',
        'Загрејати тефлон тигањ, сипати мало теста и ротирати да се танко разлије.',
        'Пећи на средњој ватри до златне боје, окренути и кратко допећи.',
        'Премазати џемом или кремом, уролати и послужити.'
      ],
      hr: [
        'Brašno, jaja, sol i pola mlijeka umutiti u glatko tijesto.',
        'Dodati ostatak mlijeka i ulje dok ne dobijete rijetko tijesto. Ostaviti 10 minuta.',
        'Zagrijati teflon tavu, uliti malo tijesta i okretati da se tanko razlije.',
        'Peći na srednjoj vatri do zlatne boje, okrenuti i kratko dopeći.',
        'Premazati džemom ili kremom, zamotati i poslužiti.'
      ],
      ba: [
        'Brašno, jaja, so i pola mlijeka umutiti u glatko tijesto.',
        'Dodati ostatak mlijeka i ulje dok ne dobijete rijetko tijesto. Ostaviti 10 minuta.',
        'Zagrijati teflon tavu, uliti malo tijesta i okretati da se tanko razlije.',
        'Peći na srednjoj vatri do zlatne boje, okrenuti i kratko dopeći.',
        'Premazati džemom ili kremom, zamotati i poslužiti.'
      ],
      en: [
        'Whisk flour, eggs, salt and half the milk into a smooth batter.',
        'Stir in the rest of the milk and the oil until the batter is thin. Rest for 10 minutes.',
        'Heat a non-stick pan, pour in a little batter and swirl to spread thinly.',
        'Cook on medium heat until golden, flip and finish briefly.',
        'Spread with jam or chocolate cream, roll up and serve.'
      ]
    }
  },

  // ---- DEUTSCH -------------------------------------------------------------
  {
    id: 'frikadellen', kueche: 'deutsch', portionen: 4, dauer_min: 30,
    titel: { de: 'Frikadellen (Buletten)', sr: 'Фрикадели', hr: 'Frikadele', ba: 'Frikadele', en: 'Frikadellen (meat patties)' },
    zutaten: [
      { menge: 500, einheit: 'g',   name: { de: 'gemischtes Hackfleisch', sr: 'мешано млевено месо', hr: 'miješano mljeveno meso', ba: 'miješano mljeveno meso', en: 'mixed ground meat' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1,   einheit: 'stk', name: { de: 'altbackenes Brötchen (eingeweicht)', sr: 'стара земичка (натопљена)', hr: 'stara zemička (namočena)', ba: 'stara zemička (namočena)', en: 'stale bread roll (soaked)' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Ei', sr: 'јаје', hr: 'jaje', ba: 'jaje', en: 'egg' } },
      { menge: 1,   einheit: 'el',  name: { de: 'Senf', sr: 'сенф', hr: 'senf', ba: 'senf', en: 'mustard' } },
      { menge: 2,   einheit: 'el',  name: { de: 'Semmelbrösel', sr: 'презле', hr: 'prezle', ba: 'prezle', en: 'breadcrumbs' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl zum Braten', sr: 'уље за пржење', hr: 'ulje za prženje', ba: 'ulje za prženje', en: 'oil for frying' } }
    ],
    schritte: {
      de: ['Brötchen in Wasser einweichen und gut ausdrücken.', 'Zwiebel fein würfeln. Hackfleisch mit Brötchen, Zwiebel, Ei, Senf, Bröseln, Salz und Pfeffer verkneten.', 'Mit feuchten Händen flache Frikadellen formen.', 'In heißem Öl bei mittlerer Hitze pro Seite 4–5 Min. goldbraun braten.', 'Mit Kartoffelsalat oder Brot servieren.'],
      sr: ['Земичку натопити у воду и добро исцедити.', 'Лук ситно исецкати. Месо умесити са земичком, луком, јајетом, сенфом, презлама, сољу и бибером.', 'Влажним рукама обликовати плоснате ћуфте.', 'На врелом уљу пржити на средњој ватри 4–5 минута са сваке стране док не порумене.', 'Послужити са салатом од кромпира или хлебом.'],
      hr: ['Zemičku namočiti u vodu i dobro ocijediti.', 'Luk sitno nasjeckati. Meso umijesiti sa zemičkom, lukom, jajetom, senfom, prezlama, soli i paprom.', 'Vlažnim rukama oblikovati plosnate pljeskavice.', 'Na vrućem ulju pržiti na srednjoj vatri 4–5 minuta sa svake strane dok ne porumene.', 'Poslužiti s krumpir salatom ili kruhom.'],
      ba: ['Zemičku namočiti u vodu i dobro ocijediti.', 'Luk sitno nasjeckati. Meso umijesiti sa zemičkom, lukom, jajetom, senfom, prezlama, soli i biberom.', 'Vlažnim rukama oblikovati plosnate pljeskavice.', 'Na vrućem ulju pržiti na srednjoj vatri 4–5 minuta sa svake strane dok ne porumene.', 'Poslužiti sa krompir salatom ili hljebom.'],
      en: ['Soak the bread roll in water and squeeze out well.', 'Finely dice the onion. Knead the meat with roll, onion, egg, mustard, breadcrumbs, salt and pepper.', 'With damp hands, shape flat patties.', 'Fry in hot oil on medium heat for 4–5 minutes per side until golden.', 'Serve with potato salad or bread.']
    }
  },

  {
    id: 'kartoffelsalat', kueche: 'deutsch', portionen: 4, dauer_min: 40,
    titel: { de: 'Kartoffelsalat', sr: 'Салата од кромпира', hr: 'Krumpir salata', ba: 'Krompir salata', en: 'Potato salad' },
    zutaten: [
      { menge: 800, einheit: 'g',   name: { de: 'festkochende Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'waxy potatoes' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 200, einheit: 'ml',  name: { de: 'Gemüsebrühe', sr: 'повртна супа', hr: 'povrtni temeljac', ba: 'povrtna supa', en: 'vegetable broth' } },
      { menge: 3,   einheit: 'el',  name: { de: 'Weißweinessig', sr: 'винско сирће', hr: 'vinski ocat', ba: 'vinsko sirće', en: 'white wine vinegar' } },
      { menge: 3,   einheit: 'el',  name: { de: 'Öl', sr: 'уље', hr: 'ulje', ba: 'ulje', en: 'oil' } },
      { menge: 1,   einheit: 'tl',  name: { de: 'Senf', sr: 'сенф', hr: 'senf', ba: 'senf', en: 'mustard' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } },
      { menge: 1,   einheit: 'bund', name: { de: 'Schnittlauch', sr: 'влашац', hr: 'vlasac', ba: 'vlasac', en: 'chives' } }
    ],
    schritte: {
      de: ['Kartoffeln in der Schale weich kochen, kurz abkühlen, pellen und in Scheiben schneiden.', 'Zwiebel fein würfeln. Brühe mit Essig, Senf, Salz und Pfeffer erhitzen.', 'Warme Kartoffelscheiben und Zwiebel mit der Brühe übergießen und vorsichtig mischen.', 'Öl unterheben und mindestens 30 Min. durchziehen lassen.', 'Vor dem Servieren mit Schnittlauch bestreuen und nochmals abschmecken.'],
      sr: ['Кромпир скувати у љусци, мало охладити, огулити и исећи на кришке.', 'Лук ситно исецкати. Супу загрејати са сирћетом, сенфом, сољу и бибером.', 'Топле кришке кромпира и лук прелити супом и пажљиво промешати.', 'Умешати уље и оставити да одстоји најмање 30 минута.', 'Пре сервирања посути влашцем и поново зачинити.'],
      hr: ['Krumpir skuhati u kori, malo ohladiti, oguliti i narezati na ploške.', 'Luk sitno nasjeckati. Temeljac zagrijati s octom, senfom, soli i paprom.', 'Tople ploške krumpira i luk preliti temeljcem i pažljivo promiješati.', 'Umiješati ulje i ostaviti da odstoji najmanje 30 minuta.', 'Prije posluživanja posuti vlascem i ponovno začiniti.'],
      ba: ['Krompir skuhati u kori, malo ohladiti, oguliti i narezati na ploške.', 'Luk sitno nasjeckati. Supu zagrijati sa sirćetom, senfom, soli i biberom.', 'Tople ploške krompira i luk preliti supom i pažljivo promiješati.', 'Umiješati ulje i ostaviti da odstoji najmanje 30 minuta.', 'Prije posluživanja posuti vlascem i ponovo začiniti.'],
      en: ['Boil potatoes in their skins until tender, cool briefly, peel and slice.', 'Finely dice the onion. Heat broth with vinegar, mustard, salt and pepper.', 'Pour the broth over the warm potato slices and onion, mix gently.', 'Fold in the oil and let rest for at least 30 minutes.', 'Before serving, sprinkle with chives and season again.']
    }
  },

  {
    id: 'gulasch', kueche: 'deutsch', portionen: 5, dauer_min: 150,
    titel: { de: 'Gulasch', sr: 'Гулаш', hr: 'Gulaš', ba: 'Gulaš', en: 'Goulash' },
    zutaten: [
      { menge: 800, einheit: 'g',   name: { de: 'Rindfleisch (Gulasch)', sr: 'јунеће месо за гулаш', hr: 'junetina za gulaš', ba: 'junetina za gulaš', en: 'beef (for goulash)' } },
      { menge: 600, einheit: 'g',   name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 2,   einheit: 'el',  name: { de: 'Paprikapulver (edelsüß)', sr: 'алева паприка', hr: 'crvena mljevena paprika', ba: 'crvena mljevena paprika', en: 'sweet paprika' } },
      { menge: 2,   einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1,   einheit: 'el',  name: { de: 'Tomatenmark', sr: 'паста од парадајза', hr: 'pasta od rajčice', ba: 'pasta od rajčice', en: 'tomato paste' } },
      { menge: 500, einheit: 'ml',  name: { de: 'Rinderbrühe', sr: 'говеђа супа', hr: 'goveđi temeljac', ba: 'goveđa supa', en: 'beef broth' } },
      { menge: 1,   einheit: 'tl',  name: { de: 'Kümmel (gemahlen)', sr: 'ким (млевени)', hr: 'kim (mljeveni)', ba: 'kim (mljeveni)', en: 'caraway (ground)' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } }
    ],
    schritte: {
      de: ['Zwiebeln in Öl langsam goldbraun anschwitzen (nicht anbrennen).', 'Topf vom Herd, Paprikapulver und Tomatenmark einrühren, damit es nicht bitter wird.', 'Fleischwürfel und Knoblauch zugeben, kurz anbraten.', 'Mit Brühe aufgießen, Kümmel, Salz und Pfeffer zugeben.', 'Zugedeckt bei schwacher Hitze ca. 2 Stunden schmoren, bis das Fleisch weich ist. Mit Brot oder Nudeln servieren.'],
      sr: ['Лук на уљу полако пропржити до златне боје (не загорети).', 'Склонити са ватре, умешати алеву паприку и пасту од парадајза да не загорчи.', 'Додати коцке меса и бели лук, кратко пропржити.', 'Залити супом, додати ким, со и бибер.', 'Поклопљено динстати на тихој ватри око 2 сата док месо не омекша. Послужити уз хлеб или тестенину.'],
      hr: ['Luk na ulju polako popržiti do zlatne boje (ne zagorjeti).', 'Maknuti s vatre, umiješati papriku i pastu od rajčice da ne zagorči.', 'Dodati kocke mesa i češnjak, kratko popržiti.', 'Zaliti temeljcem, dodati kim, sol i papar.', 'Poklopljeno pirjati na laganoj vatri oko 2 sata dok meso ne omekša. Poslužiti uz kruh ili tjesteninu.'],
      ba: ['Luk na ulju polako popržiti do zlatne boje (ne zagorjeti).', 'Skloniti s vatre, umiješati papriku i pastu od rajčice da ne zagorči.', 'Dodati kocke mesa i bijeli luk, kratko popržiti.', 'Zaliti supom, dodati kim, so i biber.', 'Poklopljeno dinstati na laganoj vatri oko 2 sata dok meso ne omekša. Poslužiti uz hljeb ili tjesteninu.'],
      en: ['Slowly sauté the onions in oil until golden (do not burn).', 'Off the heat, stir in paprika and tomato paste so it does not turn bitter.', 'Add the meat cubes and garlic, brown briefly.', 'Pour in the broth, add caraway, salt and pepper.', 'Cover and simmer on low heat for about 2 hours until the meat is tender. Serve with bread or pasta.']
    }
  },

  // ---- ITALIENISCH ---------------------------------------------------------
  {
    id: 'spaghetti_bolognese', kueche: 'italienisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Spaghetti Bolognese', sr: 'Шпагете Болоњезе', hr: 'Špageti bolognese', ba: 'Špagete bolonjeze', en: 'Spaghetti bolognese' },
    zutaten: [
      { menge: 400, einheit: 'g',   name: { de: 'Spaghetti', sr: 'шпагете', hr: 'špageti', ba: 'špagete', en: 'spaghetti' } },
      { menge: 400, einheit: 'g',   name: { de: 'Rinderhackfleisch', sr: 'јунеће млевено месо', hr: 'juneće mljeveno meso', ba: 'juneće mljeveno meso', en: 'ground beef' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Karotte', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrot' } },
      { menge: 2,   einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 400, einheit: 'g',   name: { de: 'gehackte Tomaten (Dose)', sr: 'сецкани парадајз (конзерва)', hr: 'sjeckane rajčice (konzerva)', ba: 'sjeckani paradajz (konzerva)', en: 'chopped tomatoes (can)' } },
      { menge: 50,  einheit: 'g',   name: { de: 'Parmesan', sr: 'пармезан', hr: 'parmezan', ba: 'parmezan', en: 'parmesan' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Olivenöl', sr: 'со, бибер, маслиново уље', hr: 'sol, papar, maslinovo ulje', ba: 'so, biber, maslinovo ulje', en: 'salt, pepper, olive oil' } }
    ],
    schritte: {
      de: ['Zwiebel, Karotte und Knoblauch fein würfeln und in Olivenöl anschwitzen.', 'Hackfleisch zugeben und krümelig anbraten.', 'Tomaten zugeben, salzen, pfeffern und 30–40 Min. bei schwacher Hitze köcheln.', 'Spaghetti in Salzwasser al dente kochen und abgießen.', 'Sauce über die Nudeln geben und mit geriebenem Parmesan servieren.'],
      sr: ['Лук, шаргарепу и бели лук ситно исецкати и продинстати на маслиновом уљу.', 'Додати млевено месо и пропржити да се раздвоји.', 'Додати парадајз, посолити, побиберити и кувати 30–40 минута на тихој ватри.', 'Шпагете скувати у сланој води ал денте и оцедити.', 'Прелити сос преко тестенине и послужити са ренданим пармезаном.'],
      hr: ['Luk, mrkvu i češnjak sitno nasjeckati i pirjati na maslinovom ulju.', 'Dodati mljeveno meso i popržiti da se razdvoji.', 'Dodati rajčice, posoliti, popapriti i kuhati 30–40 minuta na laganoj vatri.', 'Špagete skuhati u slanoj vodi al dente i ocijediti.', 'Preliti umak preko tjestenine i poslužiti s naribanim parmezanom.'],
      ba: ['Luk, mrkvu i bijeli luk sitno nasjeckati i dinstati na maslinovom ulju.', 'Dodati mljeveno meso i popržiti da se razdvoji.', 'Dodati paradajz, posoliti, pobiberiti i kuhati 30–40 minuta na laganoj vatri.', 'Špagete skuhati u slanoj vodi al dente i ocijediti.', 'Preliti sos preko tjestenine i poslužiti sa naribanim parmezanom.'],
      en: ['Finely dice onion, carrot and garlic and sauté in olive oil.', 'Add the ground meat and brown until crumbly.', 'Add tomatoes, season with salt and pepper and simmer for 30–40 minutes on low heat.', 'Cook the spaghetti in salted water until al dente and drain.', 'Pour the sauce over the pasta and serve with grated parmesan.']
    }
  },

  {
    id: 'carbonara', kueche: 'italienisch', portionen: 4, dauer_min: 25,
    titel: { de: 'Spaghetti Carbonara', sr: 'Шпагете Карбонара', hr: 'Špageti carbonara', ba: 'Špagete karbonara', en: 'Spaghetti carbonara' },
    zutaten: [
      { menge: 400, einheit: 'g',   name: { de: 'Spaghetti', sr: 'шпагете', hr: 'špageti', ba: 'špagete', en: 'spaghetti' } },
      { menge: 150, einheit: 'g',   name: { de: 'Pancetta oder durchwachsener Speck', sr: 'панчета / сланина', hr: 'pancetta / slanina', ba: 'pančeta / slanina', en: 'pancetta or bacon' } },
      { menge: 4,   einheit: 'stk', name: { de: 'Eigelb', sr: 'жуманца', hr: 'žumanjci', ba: 'žumanjci', en: 'egg yolks' } },
      { menge: 80,  einheit: 'g',   name: { de: 'Pecorino oder Parmesan', sr: 'пекорино / пармезан', hr: 'pecorino / parmezan', ba: 'pecorino / parmezan', en: 'pecorino or parmesan' } },
      { menge: null, einheit: 'ng', name: { de: 'schwarzer Pfeffer', sr: 'црни бибер', hr: 'crni papar', ba: 'crni biber', en: 'black pepper' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Spaghetti in reichlich Salzwasser al dente kochen, etwas Nudelwasser aufheben.', 'Speck in Streifen ohne zusätzliches Fett knusprig auslassen.', 'Eigelb mit geriebenem Käse und viel Pfeffer verrühren.', 'Heiße, abgetropfte Nudeln zum Speck geben, vom Herd nehmen.', 'Ei-Käse-Mischung unterrühren, mit etwas Nudelwasser cremig ziehen (nicht mehr kochen). Sofort servieren.'],
      sr: ['Шпагете скувати у сланој води ал денте, сачувати мало воде од кувања.', 'Сланину на траке испржити без додатне масти да буде хрскава.', 'Жуманца умутити са ренданим сиром и доста бибера.', 'Топле, оцеђене шпагете додати сланини и склонити са ватре.', 'Умешати смесу од јаја и сира, са мало воде од кувања довести до кремасте текстуре (не кувати даље). Одмах послужити.'],
      hr: ['Špagete skuhati u slanoj vodi al dente, sačuvati malo vode od kuhanja.', 'Slaninu na trake popržiti bez dodatne masnoće da bude hrskava.', 'Žumanjke umutiti s naribanim sirom i dosta papra.', 'Tople, ocijeđene špagete dodati slanini i maknuti s vatre.', 'Umiješati smjesu od jaja i sira, s malo vode od kuhanja dovesti do kremaste teksture (ne kuhati dalje). Odmah poslužiti.'],
      ba: ['Špagete skuhati u slanoj vodi al dente, sačuvati malo vode od kuhanja.', 'Slaninu na trake popržiti bez dodatne masnoće da bude hrskava.', 'Žumanjke umutiti sa naribanim sirom i dosta bibera.', 'Tople, ocijeđene špagete dodati slanini i skloniti s vatre.', 'Umiješati smjesu od jaja i sira, sa malo vode od kuhanja dovesti do kremaste teksture (ne kuhati dalje). Odmah poslužiti.'],
      en: ['Cook spaghetti in plenty of salted water until al dente, reserving some pasta water.', 'Fry the bacon strips without extra fat until crisp.', 'Whisk the egg yolks with grated cheese and lots of pepper.', 'Add the hot, drained pasta to the bacon and take off the heat.', 'Stir in the egg-cheese mix, loosen with a little pasta water until creamy (do not cook further). Serve immediately.']
    }
  },

  {
    id: 'pizza_margherita', kueche: 'italienisch', portionen: 2, dauer_min: 90,
    titel: { de: 'Pizza Margherita', sr: 'Пица Маргарита', hr: 'Pizza Margherita', ba: 'Pizza Margarita', en: 'Pizza Margherita' },
    zutaten: [
      { menge: 300, einheit: 'g',   name: { de: 'Mehl (Type 00)', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour (type 00)' } },
      { menge: 180, einheit: 'ml',  name: { de: 'lauwarmes Wasser', sr: 'млака вода', hr: 'mlaka voda', ba: 'mlaka voda', en: 'lukewarm water' } },
      { menge: 5,   einheit: 'g',   name: { de: 'Trockenhefe', sr: 'сув квасац', hr: 'suhi kvasac', ba: 'suhi kvasac', en: 'dry yeast' } },
      { menge: 200, einheit: 'g',   name: { de: 'passierte Tomaten', sr: 'пасирани парадајз', hr: 'pasirane rajčice', ba: 'pasirani paradajz', en: 'tomato passata' } },
      { menge: 150, einheit: 'g',   name: { de: 'Mozzarella', sr: 'моцарела', hr: 'mozzarella', ba: 'mozzarella', en: 'mozzarella' } },
      { menge: null, einheit: 'ng', name: { de: 'frisches Basilikum', sr: 'свеж босиљак', hr: 'svježi bosiljak', ba: 'svježi bosiljak', en: 'fresh basil' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Salz', sr: 'маслиново уље, со', hr: 'maslinovo ulje, sol', ba: 'maslinovo ulje, so', en: 'olive oil, salt' } }
    ],
    schritte: {
      de: ['Mehl, Wasser, Hefe und 1 TL Salz zu einem glatten Teig kneten. Zugedeckt ca. 1 Std. gehen lassen.', 'Teig dünn ausrollen und auf ein Backblech legen.', 'Passierte Tomaten mit etwas Salz und Öl verrühren, dünn aufstreichen.', 'Mozzarella in Stücken darauf verteilen.', 'Im auf 250 °C vorgeheizten Ofen 8–12 Min. backen, mit Basilikum bestreuen.'],
      sr: ['Брашно, воду, квасац и 1 кашичицу соли умесити у глатко тесто. Поклопљено оставити да нарасте око 1 сат.', 'Тесто танко развући и ставити на плех.', 'Пасирани парадајз зачинити сољу и уљем, танко премазати.', 'Распоредити комаде моцареле.', 'Пећи у загрејаној рерни на 250 степени 8-12 минута, посути босиљком.'],
      hr: ['Brašno, vodu, kvasac i 1 žličicu soli umijesiti u glatko tijesto. Poklopljeno ostaviti da naraste oko 1 sat.', 'Tijesto tanko razvaljati i staviti na lim.', 'Pasirane rajčice začiniti soli i uljem, tanko premazati.', 'Rasporediti komade mozzarelle.', 'Peći u zagrijanoj pećnici na 250 °C 8–12 minuta, posuti bosiljkom.'],
      ba: ['Brašno, vodu, kvasac i 1 kašičicu soli umijesiti u glatko tijesto. Poklopljeno ostaviti da naraste oko 1 sat.', 'Tijesto tanko razvaljati i staviti na pleh.', 'Pasirani paradajz začiniti soli i uljem, tanko premazati.', 'Rasporediti komade mozzarelle.', 'Peći u zagrijanoj pećnici na 250 °C 8–12 minuta, posuti bosiljkom.'],
      en: ['Knead flour, water, yeast and 1 tsp salt into a smooth dough. Cover and let rise for about 1 hour.', 'Roll out the dough thinly and place on a baking tray.', 'Season the passata with a little salt and oil, spread thinly.', 'Distribute pieces of mozzarella on top.', 'Bake in an oven preheated to 250 °C for 8–12 minutes, sprinkle with basil.']
    }
  },

  // ---- BALKAN (Fortsetzung) ------------------------------------------------
  {
    id: 'djuvec', kueche: 'balkan', portionen: 5, dauer_min: 75,
    titel: { de: 'Đuveč (Reistopf mit Gemüse)', sr: 'Ђувеч', hr: 'Đuveč', ba: 'Đuveč', en: 'Đuveč (rice & vegetable bake)' },
    zutaten: [
      { menge: 300, einheit: 'g',   name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 400, einheit: 'g',   name: { de: 'Schweine- oder Rindfleisch (gewürfelt)', sr: 'свињско или јунеће месо (коцке)', hr: 'svinjetina ili junetina (kocke)', ba: 'svinjetina ili junetina (kocke)', en: 'pork or beef (cubed)' } },
      { menge: 2,   einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell peppers' } },
      { menge: 2,   einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Karotte', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrot' } },
      { menge: 1,   einheit: 'tl',  name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Fleisch würfeln, in Öl anbraten, salzen und pfeffern.', 'Zwiebel, Karotte und Paprika klein schneiden und mitdünsten.', 'Reis und Paprikapulver zugeben, kurz anrösten.', 'Mit Wasser aufgießen (etwa doppelte Reismenge), Tomatenscheiben darauflegen.', 'Zugedeckt im Ofen bei 200 Grad ca. 40 Min. backen, bis der Reis gar ist.'],
      sr: ['Месо исећи на коцке, пропржити на уљу, посолити и побиберити.', 'Лук, шаргарепу и паприку ситно исећи и продинстати.', 'Додати пиринач и алеву паприку, кратко пропржити.', 'Залити водом (око двоструко више од пиринча), поређати кришке парадајза.', 'Поклопљено пећи у рерни на 200 степени око 40 минута док се пиринач не скува.'],
      hr: ['Meso narezati na kocke, popržiti na ulju, posoliti i popapriti.', 'Luk, mrkvu i papriku sitno narezati i popirjati.', 'Dodati rižu i papriku, kratko popržiti.', 'Zaliti vodom (oko dvostruko više od riže), poslagati ploške rajčice.', 'Poklopljeno peći u pećnici na 200 stupnjeva oko 40 minuta dok se riža ne skuha.'],
      ba: ['Meso narezati na kocke, popržiti na ulju, posoliti i pobiberiti.', 'Luk, mrkvu i papriku sitno narezati i podinstati.', 'Dodati rižu i papriku, kratko popržiti.', 'Zaliti vodom (oko dvostruko više od riže), poslagati ploške paradajza.', 'Poklopljeno peći u pećnici na 200 stepeni oko 40 minuta dok se riža ne skuha.'],
      en: ['Cube the meat, brown in oil, season with salt and pepper.', 'Finely cut onion, carrot and peppers and saute.', 'Add rice and paprika, toast briefly.', 'Pour in water (about twice the rice volume), lay tomato slices on top.', 'Cover and bake in the oven at 200 degrees for about 40 minutes until the rice is done.']
    }
  },

  {
    id: 'musaka', kueche: 'balkan', portionen: 6, dauer_min: 90,
    titel: { de: 'Musaka (mit Kartoffeln)', sr: 'Мусака', hr: 'Musaka', ba: 'Musaka', en: 'Musaka (potato & minced meat bake)' },
    zutaten: [
      { menge: 1,   einheit: 'kg',  name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 500, einheit: 'g',   name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'ground meat' } },
      { menge: 2,   einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 3,   einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 200, einheit: 'ml',  name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 150, einheit: 'ml',  name: { de: 'saure Sahne', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'sour cream' } },
      { menge: 1,   einheit: 'tl',  name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Kartoffeln schälen und in dünne Scheiben schneiden.', 'Zwiebel hacken, in Öl anbraten, Hackfleisch zugeben und krümelig braten; mit Paprikapulver, Salz und Pfeffer würzen.', 'In eine gefettete Form abwechselnd Kartoffeln und Hackfleisch schichten, mit Kartoffeln abschließen.', 'Eier mit Milch und saurer Sahne verquirlen, salzen und über den Auflauf gießen.', 'Bei 200 Grad ca. 45 Min. goldbraun backen.'],
      sr: ['Кромпир огулити и исећи на танке кришке.', 'Лук исецкати, пропржити на уљу, додати месо и пржити да се раздвоји; зачинити алевом паприком, сољу и бибером.', 'У подмазан плех ређати наизменично кромпир и месо, завршити кромпиром.', 'Јаја умутити са млеком и павлаком, посолити и прелити преко јела.', 'Пећи на 200 степени око 45 минута до златне боје.'],
      hr: ['Krumpir oguliti i narezati na tanke ploške.', 'Luk nasjeckati, popržiti na ulju, dodati meso i pržiti da se razdvoji; začiniti paprikom, soli i paprom.', 'U podmazanu tepsiju slagati naizmjenično krumpir i meso, završiti krumpirom.', 'Jaja umutiti s mlijekom i vrhnjem, posoliti i preliti preko jela.', 'Peći na 200 stupnjeva oko 45 minuta do zlatne boje.'],
      ba: ['Krompir oguliti i narezati na tanke ploške.', 'Luk nasjeckati, popržiti na ulju, dodati meso i pržiti da se razdvoji; začiniti paprikom, soli i biberom.', 'U podmazanu tepsiju slagati naizmjenično krompir i meso, završiti krompirom.', 'Jaja umutiti sa mlijekom i pavlakom, posoliti i preliti preko jela.', 'Peći na 200 stepeni oko 45 minuta do zlatne boje.'],
      en: ['Peel the potatoes and cut into thin slices.', 'Chop the onion, fry in oil, add the meat and brown until crumbly; season with paprika, salt and pepper.', 'In a greased dish, layer potatoes and meat alternately, finishing with potatoes.', 'Whisk eggs with milk and sour cream, salt, and pour over the bake.', 'Bake at 200 degrees for about 45 minutes until golden.']
    }
  },

  {
    id: 'punjene_paprike', kueche: 'balkan', portionen: 5, dauer_min: 80,
    titel: { de: 'Gefüllte Paprika', sr: 'Пуњене паприке', hr: 'Punjene paprike', ba: 'Punjene paprike', en: 'Stuffed peppers' },
    zutaten: [
      { menge: 8,   einheit: 'stk', name: { de: 'Paprika (zum Füllen)', sr: 'паприке (за пуњење)', hr: 'paprike (za punjenje)', ba: 'paprike (za punjenje)', en: 'peppers (for stuffing)' } },
      { menge: 500, einheit: 'g',   name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'ground meat' } },
      { menge: 150, einheit: 'g',   name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 2,   einheit: 'el',  name: { de: 'Tomatenmark', sr: 'паста од парадајза', hr: 'pasta od rajčice', ba: 'pasta od rajčice', en: 'tomato paste' } },
      { menge: 1,   einheit: 'tl',  name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } }
    ],
    schritte: {
      de: ['Paprika waschen, Deckel abschneiden und Kerne entfernen.', 'Zwiebel fein hacken und anbraten; mit Hackfleisch, halb gegartem Reis, Paprikapulver, Salz und Pfeffer mischen.', 'Paprika mit der Masse füllen.', 'In einen Topf setzen, Tomatenmark in Wasser verrühren und angießen bis fast bedeckt.', 'Zugedeckt bei schwacher Hitze ca. 1 Stunde schmoren.'],
      sr: ['Паприке опрати, одсећи поклопце и извадити семенке.', 'Лук ситно исецкати и пропржити; помешати са месом, полукуваним пиринчем, алевом паприком, сољу и бибером.', 'Напунити паприке смесом.', 'Ставити у лонац, пасту од парадајза размутити у води и залити да скоро прекрије.', 'Поклопљено динстати на тихој ватри око 1 сат.'],
      hr: ['Paprike oprati, odrezati poklopce i izvaditi sjemenke.', 'Luk sitno nasjeckati i popržiti; pomiješati s mesom, polukuhanom rižom, paprikom, soli i paprom.', 'Napuniti paprike smjesom.', 'Staviti u lonac, pastu od rajčice razmutiti u vodi i zaliti da gotovo prekrije.', 'Poklopljeno pirjati na laganoj vatri oko 1 sat.'],
      ba: ['Paprike oprati, odrezati poklopce i izvaditi sjemenke.', 'Luk sitno nasjeckati i popržiti; pomiješati sa mesom, polukuhanom rižom, paprikom, soli i biberom.', 'Napuniti paprike smjesom.', 'Staviti u lonac, pastu od paradajza razmutiti u vodi i zaliti da gotovo prekrije.', 'Poklopljeno dinstati na laganoj vatri oko 1 sat.'],
      en: ['Wash the peppers, cut off the tops and remove the seeds.', 'Finely chop the onion and fry; mix with meat, half-cooked rice, paprika, salt and pepper.', 'Fill the peppers with the mixture.', 'Place in a pot, stir tomato paste into water and pour in until almost covered.', 'Cover and simmer on low heat for about 1 hour.']
    }
  },

  {
    id: 'ajvar', kueche: 'balkan', portionen: 8, dauer_min: 120,
    titel: { de: 'Ajvar (Paprika-Aufstrich)', sr: 'Ајвар', hr: 'Ajvar', ba: 'Ajvar', en: 'Ajvar (roasted pepper relish)' },
    zutaten: [
      { menge: 2,   einheit: 'kg',  name: { de: 'rote Paprika (fleischig)', sr: 'црвене меснате паприке', hr: 'crvene mesnate paprike', ba: 'crvene mesnate paprike', en: 'red bell peppers (fleshy)' } },
      { menge: 1,   einheit: 'stk', name: { de: 'Aubergine (nach Wunsch)', sr: 'плави патлиџан (по жељи)', hr: 'patlidžan (po želji)', ba: 'patlidžan (po želji)', en: 'eggplant (optional)' } },
      { menge: 100, einheit: 'ml',  name: { de: 'Sonnenblumenöl', sr: 'сунцокретово уље', hr: 'suncokretovo ulje', ba: 'suncokretovo ulje', en: 'sunflower oil' } },
      { menge: 3,   einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 2,   einheit: 'el',  name: { de: 'Weinessig', sr: 'винско сирће', hr: 'vinski ocat', ba: 'vinsko sirće', en: 'wine vinegar' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Paprika (und Aubergine) im Ofen bei 220 Grad rösten, bis die Haut dunkel und blasig ist.', 'Abgedeckt ausdampfen lassen, dann häuten und entkernen.', 'Das Fruchtfleisch fein zerkleinern oder faschieren.', 'In Öl mit Knoblauch bei schwacher Hitze langsam einkochen, dabei oft rühren, bis die Masse dick wird.', 'Mit Essig und Salz abschmecken; heiß in saubere Gläser füllen.'],
      sr: ['Паприке (и патлиџан) пећи у рерни на 220 степени док кожица не потамни и не буде мехураста.', 'Поклопљено оставити да се проваре, затим огулити и очистити од семенки.', 'Месо паприке ситно исецкати или самлети.', 'На уљу са белим луком лагано укувавати на тихој ватри, често мешати, док се маса не згусне.', 'Зачинити сирћетом и сољу; врело сипати у чисте тегле.'],
      hr: ['Paprike (i patlidžan) peći u pećnici na 220 stupnjeva dok kožica ne potamni i ne bude mjehurasta.', 'Poklopljeno ostaviti da se propare, zatim oguliti i očistiti od sjemenki.', 'Meso paprike sitno nasjeckati ili samljeti.', 'Na ulju s češnjakom lagano ukuhavati na laganoj vatri, često miješati, dok se masa ne zgusne.', 'Začiniti octom i soli; vruće puniti u čiste staklenke.'],
      ba: ['Paprike (i patlidžan) peći u pećnici na 220 stepeni dok kožica ne potamni i ne bude mjehurasta.', 'Poklopljeno ostaviti da se propare, zatim oguliti i očistiti od sjemenki.', 'Meso paprike sitno nasjeckati ili samljeti.', 'Na ulju sa bijelim lukom lagano ukuhavati na laganoj vatri, često miješati, dok se masa ne zgusne.', 'Začiniti sirćetom i soli; vruće puniti u čiste tegle.'],
      en: ['Roast the peppers (and eggplant) in the oven at 220 degrees until the skin is dark and blistered.', 'Let them steam covered, then peel and deseed.', 'Finely chop or mince the flesh.', 'Cook down slowly in oil with garlic on low heat, stirring often, until the mixture thickens.', 'Season with vinegar and salt; fill hot into clean jars.']
    }
  },

  {
    id: 'gibanica', kueche: 'balkan', portionen: 8, dauer_min: 60,
    titel: { de: 'Gibanica (Käse-Pite)', sr: 'Гибаница', hr: 'Gibanica', ba: 'Gibanica', en: 'Gibanica (cheese filo pie)' },
    zutaten: [
      { menge: 500, einheit: 'g',   name: { de: 'Filo-/Yufkateig', sr: 'коре за питу', hr: 'kore za pitu', ba: 'jufke', en: 'filo pastry' } },
      { menge: 400, einheit: 'g',   name: { de: 'Feta (Weißkäse)', sr: 'сир (бели)', hr: 'sir (feta)', ba: 'sir (feta)', en: 'feta cheese' } },
      { menge: 4,   einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 250, einheit: 'ml',  name: { de: 'saure Sahne', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'sour cream' } },
      { menge: 100, einheit: 'ml',  name: { de: 'Öl', sr: 'уље', hr: 'ulje', ba: 'ulje', en: 'oil' } },
      { menge: 200, einheit: 'ml',  name: { de: 'Mineralwasser', sr: 'кисела вода', hr: 'mineralna voda', ba: 'mineralna voda', en: 'sparkling water' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Käse zerbröseln und mit Eiern, saurer Sahne, Öl und Mineralwasser verrühren (etwas für oben aufheben).', 'Eine gefettete Form mit einem Teigblatt auslegen.', 'Restliche Teigblätter locker zerknüllen, in die Käsemasse tauchen und in die Form schichten.', 'Mit der zurückbehaltenen Masse bestreichen.', 'Bei 200 Grad ca. 40 Min. goldbraun backen; kurz ruhen lassen und schneiden.'],
      sr: ['Сир измрвити и умутити са јајима, павлаком, уљем и киселом водом (мало оставити за врх).', 'Подмазан плех обложити једном кором.', 'Преостале коре лабаво изгужвати, умакати у смесу са сиром и ређати у плех.', 'Премазати задржаном смесом.', 'Пећи на 200 степени око 40 минута до златне боје; кратко одморити и сећи.'],
      hr: ['Sir izmrviti i umutiti s jajima, vrhnjem, uljem i mineralnom vodom (malo ostaviti za vrh).', 'Podmazanu tepsiju obložiti jednom korom.', 'Preostale kore labavo izgužvati, umakati u smjesu sa sirom i slagati u tepsiju.', 'Premazati zadržanom smjesom.', 'Peći na 200 stupnjeva oko 40 minuta do zlatne boje; kratko odmoriti i rezati.'],
      ba: ['Sir izmrviti i umutiti sa jajima, pavlakom, uljem i mineralnom vodom (malo ostaviti za vrh).', 'Podmazanu tepsiju obložiti jednom korom.', 'Preostale jufke labavo izgužvati, umakati u smjesu sa sirom i slagati u tepsiju.', 'Premazati zadržanom smjesom.', 'Peći na 200 stepeni oko 40 minuta do zlatne boje; kratko odmoriti i rezati.'],
      en: ['Crumble the cheese and whisk with eggs, sour cream, oil and sparkling water (reserve some for the top).', 'Line a greased dish with one sheet of pastry.', 'Loosely crumple the remaining sheets, dip in the cheese mixture and layer into the dish.', 'Brush with the reserved mixture.', 'Bake at 200 degrees for about 40 minutes until golden; rest briefly and cut.']
    }
  },

  {
    id: 'prebranac', kueche: 'balkan', portionen: 6, dauer_min: 150,
    titel: { de: 'Prebranac (gebackene Bohnen)', sr: 'Пребранац', hr: 'Prebranac', ba: 'Prebranac', en: 'Prebranac (baked beans)' },
    zutaten: [
      { menge: 500, einheit: 'g',   name: { de: 'weiße Bohnen (getrocknet)', sr: 'бели пасуљ (сув)', hr: 'bijeli grah (suhi)', ba: 'bijeli grah (suhi)', en: 'dried white beans' } },
      { menge: 500, einheit: 'g',   name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 2,   einheit: 'stk', name: { de: 'Lorbeerblatt', sr: 'ловоров лист', hr: 'lovorov list', ba: 'lovorov list', en: 'bay leaf' } },
      { menge: 2,   einheit: 'tl',  name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: 100, einheit: 'ml',  name: { de: 'Öl', sr: 'уље', hr: 'ulje', ba: 'ulje', en: 'oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } }
    ],
    schritte: {
      de: ['Bohnen über Nacht einweichen, dann in frischem Wasser weich kochen und abgießen.', 'Zwiebeln in Ringe schneiden und in reichlich Öl weich und goldgelb dünsten.', 'Bohnen und Zwiebeln abwechselnd in eine Form schichten, mit Paprikapulver, Salz und Pfeffer würzen, Lorbeer dazwischen.', 'Mit etwas Wasser und Öl angießen, sodass es saftig bleibt.', 'Bei 180 Grad ca. 1 Stunde backen, bis die Oberfläche goldbraun ist.'],
      sr: ['Пасуљ потопити преко ноћи, затим у свежој води скувати да омекша и оцедити.', 'Лук исећи на колутове и на доста уља продинстати да омекша и порумени.', 'Пасуљ и лук наизменично ређати у плех, зачинити алевом паприком, сољу и бибером, ловор између.', 'Залити са мало воде и уља да остане сочно.', 'Пећи на 180 степени око 1 сат док површина не порумени.'],
      hr: ['Grah namočiti preko noći, zatim u svježoj vodi skuhati da omekša i ocijediti.', 'Luk narezati na kolutove i na dosta ulja popirjati da omekša i porumeni.', 'Grah i luk naizmjenično slagati u tepsiju, začiniti paprikom, soli i paprom, lovor između.', 'Zaliti s malo vode i ulja da ostane sočno.', 'Peći na 180 stupnjeva oko 1 sat dok površina ne porumeni.'],
      ba: ['Grah namočiti preko noći, zatim u svježoj vodi skuhati da omekša i ocijediti.', 'Luk narezati na kolutove i na dosta ulja podinstati da omekša i porumeni.', 'Grah i luk naizmjenično slagati u tepsiju, začiniti paprikom, soli i biberom, lovor između.', 'Zaliti sa malo vode i ulja da ostane sočno.', 'Peći na 180 stepeni oko 1 sat dok površina ne porumeni.'],
      en: ['Soak the beans overnight, then cook in fresh water until soft and drain.', 'Slice the onions into rings and saute in plenty of oil until soft and golden.', 'Layer beans and onions alternately in a dish, season with paprika, salt and pepper, bay leaves in between.', 'Add a little water and oil so it stays juicy.', 'Bake at 180 degrees for about 1 hour until the surface is golden.']
    }
  },

  // ---- DEUTSCH (Fortsetzung) -----------------------------------------------
  {
    id: 'schnitzel', kueche: 'deutsch', portionen: 4, dauer_min: 30,
    titel: { de: 'Paniertes Schnitzel', sr: 'Панирани шницла', hr: 'Pohani odrezak', ba: 'Panirani odrezak', en: 'Breaded schnitzel' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Schnitzel (Schwein oder Kalb)', sr: 'шницле (свињске или телеће)', hr: 'odresci (svinjski ili teleći)', ba: 'odresci (svinjski ili teleći)', en: 'cutlets (pork or veal)' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 100, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 150, einheit: 'g', name: { de: 'Semmelbrösel', sr: 'презле', hr: 'prezle', ba: 'prezle', en: 'breadcrumbs' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone', sr: 'лимун', hr: 'limun', ba: 'limun', en: 'lemon' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Schnitzel flach klopfen, salzen und pfeffern.', 'Nacheinander in Mehl, verquirltem Ei und Semmelbröseln wenden.', 'In reichlich heißem Öl pro Seite 2–3 Min. goldbraun braten.', 'Auf Küchenpapier abtropfen lassen, mit Zitrone servieren.'],
      sr: ['Шницле истањити, посолити и побиберити.', 'Уваљати редом у брашно, умућено јаје и презле.', 'У доста вреле масти пржити 2–3 минута са сваке стране до златне боје.', 'Оцедити на папиру, послужити са лимуном.'],
      hr: ['Odreske istanjiti, posoliti i popapriti.', 'Uvaljati redom u brašno, umućeno jaje i prezle.', 'U dosta vruće masti pržiti 2–3 minute sa svake strane do zlatne boje.', 'Ocijediti na papiru, poslužiti s limunom.'],
      ba: ['Odreske istanjiti, posoliti i pobiberiti.', 'Uvaljati redom u brašno, umućeno jaje i prezle.', 'U dosta vruće masti pržiti 2–3 minute sa svake strane do zlatne boje.', 'Ocijediti na papiru, poslužiti sa limunom.'],
      en: ['Pound the cutlets flat, season with salt and pepper.', 'Coat in turn in flour, beaten egg and breadcrumbs.', 'Fry in plenty of hot oil for 2–3 minutes per side until golden.', 'Drain on paper towels, serve with lemon.']
    }
  },

  {
    id: 'rinderrouladen', kueche: 'deutsch', portionen: 4, dauer_min: 120,
    titel: { de: 'Rinderrouladen', sr: 'Говеђе ролнице', hr: 'Goveđe rolice', ba: 'Goveđe rolnice', en: 'Beef roulades' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'dünne Rindfleischscheiben', sr: 'танке говеђе шнице', hr: 'tanki goveđi odresci', ba: 'tanki goveđi odresci', en: 'thin beef slices' } },
      { menge: 4, einheit: 'el', name: { de: 'Senf', sr: 'сенф', hr: 'senf', ba: 'senf', en: 'mustard' } },
      { menge: 100, einheit: 'g', name: { de: 'Speck', sr: 'сланина', hr: 'slanina', ba: 'slanina', en: 'bacon' } },
      { menge: 2, einheit: 'stk', name: { de: 'Gewürzgurken', sr: 'кисели краставци', hr: 'kiseli krastavci', ba: 'kiseli krastavci', en: 'pickles' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 500, einheit: 'ml', name: { de: 'Rinderbrühe', sr: 'говеђа супа', hr: 'goveđi temeljac', ba: 'goveđa supa', en: 'beef broth' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Fleischscheiben mit Senf bestreichen, salzen und pfeffern.', 'Mit Speck, Gurken- und Zwiebelstreifen belegen, aufrollen und feststecken.', 'Rouladen rundum kräftig anbraten, restliche Zwiebel mitrösten.', 'Mit Brühe angießen und zugedeckt ca. 1,5 Stunden schmoren.', 'Rouladen herausnehmen, den Sud abschmecken und ggf. binden.'],
      sr: ['Шнице премазати сенфом, посолити и побиберити.', 'Обложити сланином, тракама краставца и лука, уролати и причврстити.', 'Ролнице јако пропржити са свих страна, додати преостали лук.', 'Залити супом и поклопљено динстати око 1,5 сат.', 'Извадити ролнице, зачинити сос и по потреби згуснути.'],
      hr: ['Odreske premazati senfom, posoliti i popapriti.', 'Obložiti slaninom, trakama krastavca i luka, zamotati i pričvrstiti.', 'Rolice jako popržiti sa svih strana, dodati preostali luk.', 'Zaliti temeljcem i poklopljeno pirjati oko 1,5 sat.', 'Izvaditi rolice, začiniti umak i po potrebi zgusnuti.'],
      ba: ['Odreske premazati senfom, posoliti i pobiberiti.', 'Obložiti slaninom, trakama krastavca i luka, zamotati i pričvrstiti.', 'Rolnice jako popržiti sa svih strana, dodati preostali luk.', 'Zaliti supom i poklopljeno dinstati oko 1,5 sat.', 'Izvaditi rolnice, začiniti sos i po potrebi zgusnuti.'],
      en: ['Spread the beef slices with mustard, season with salt and pepper.', 'Top with bacon, pickle and onion strips, roll up and secure.', 'Brown the roulades well all over, add the remaining onion.', 'Pour in broth and braise covered for about 1.5 hours.', 'Remove the roulades, season the sauce and thicken if needed.']
    }
  },

  {
    id: 'kaesespaetzle', kueche: 'deutsch', portionen: 4, dauer_min: 45,
    titel: { de: 'Käsespätzle', sr: 'Шпецле са сиром', hr: 'Špecle sa sirom', ba: 'Špecle sa sirom', en: 'Cheese spaetzle' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 4, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 150, einheit: 'ml', name: { de: 'Wasser', sr: 'вода', hr: 'voda', ba: 'voda', en: 'water' } },
      { menge: 200, einheit: 'g', name: { de: 'geriebener Käse (Bergkäse)', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Butter', sr: 'со, путер', hr: 'sol, maslac', ba: 'so, maslac', en: 'salt, butter' } }
    ],
    schritte: {
      de: ['Mehl, Eier, Wasser und Salz zu einem zähen Teig schlagen, bis er Blasen wirft.', 'Teig portionsweise durch einen Spätzlehobel in kochendes Salzwasser schaben.', 'Spätzle abschöpfen, sobald sie oben schwimmen.', 'Zwiebeln in Butter goldbraun rösten.', 'Spätzle mit Käse schichten, verrühren bis er schmilzt, mit Röstzwiebeln servieren.'],
      sr: ['Брашно, јаја, воду и со умутити у густо тесто док не почне да прави мехуриће.', 'Тесто пропуштати кроз ренде за шпецле у кипућу слану воду.', 'Шпецле извадити чим испливају.', 'Лук на путеру пропржити до златне боје.', 'Шпецле ређати са сиром, мешати док се не отопи, послужити са луком.'],
      hr: ['Brašno, jaja, vodu i sol umutiti u gusto tijesto dok ne počne stvarati mjehuriće.', 'Tijesto propuštati kroz ribež za špecle u kipuću slanu vodu.', 'Špecle izvaditi čim isplivaju.', 'Luk na maslacu popržiti do zlatne boje.', 'Špecle slagati sa sirom, miješati dok se ne otopi, poslužiti s lukom.'],
      ba: ['Brašno, jaja, vodu i so umutiti u gusto tijesto dok ne počne stvarati mjehuriće.', 'Tijesto propuštati kroz ribež za špecle u kipuću slanu vodu.', 'Špecle izvaditi čim isplivaju.', 'Luk na maslacu popržiti do zlatne boje.', 'Špecle slagati sa sirom, miješati dok se ne otopi, poslužiti sa lukom.'],
      en: ['Beat flour, eggs, water and salt into a stiff batter until it bubbles.', 'Press the batter through a spaetzle grater into boiling salted water.', 'Scoop out the spaetzle as soon as they float.', 'Fry the onions in butter until golden.', 'Layer the spaetzle with cheese, stir until melted, serve with the onions.']
    }
  },

  {
    id: 'kartoffelsuppe', kueche: 'deutsch', portionen: 4, dauer_min: 40,
    titel: { de: 'Kartoffelsuppe', sr: 'Супа од кромпира', hr: 'Juha od krumpira', ba: 'Supa od krompira', en: 'Potato soup' },
    zutaten: [
      { menge: 700, einheit: 'g', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 1, einheit: 'stk', name: { de: 'Lauch', sr: 'празилук', hr: 'poriluk', ba: 'praziluk', en: 'leek' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'l', name: { de: 'Gemüsebrühe', sr: 'повртна супа', hr: 'povrtni temeljac', ba: 'povrtna supa', en: 'vegetable broth' } },
      { menge: 2, einheit: 'stk', name: { de: 'Würstchen (nach Wunsch)', sr: 'виршле (по жељи)', hr: 'hrenovke (po želji)', ba: 'hrenovke (po želji)', en: 'sausages (optional)' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Majoran', sr: 'со, бибер, мајоран', hr: 'sol, papar, mažuran', ba: 'so, biber, mažuran', en: 'salt, pepper, marjoram' } }
    ],
    schritte: {
      de: ['Gemüse schälen und würfeln.', 'Zwiebel in Öl anschwitzen, restliches Gemüse zugeben.', 'Mit Brühe aufgießen und ca. 20 Min. weich kochen.', 'Einen Teil pürieren für eine sämige Suppe.', 'Mit Salz, Pfeffer und Majoran würzen, Würstchenscheiben zugeben.'],
      sr: ['Поврће огулити и исећи на коцке.', 'Лук продинстати на уљу, додати остало поврће.', 'Залити супом и кувати око 20 минута да омекша.', 'Део изблендати за кремасту супу.', 'Зачинити сољу, бибером и мајораном, додати кришке виршли.'],
      hr: ['Povrće oguliti i narezati na kocke.', 'Luk popirjati na ulju, dodati ostalo povrće.', 'Zaliti temeljcem i kuhati oko 20 minuta da omekša.', 'Dio izblendati za kremastu juhu.', 'Začiniti soli, paprom i mažuranom, dodati ploške hrenovki.'],
      ba: ['Povrće oguliti i narezati na kocke.', 'Luk podinstati na ulju, dodati ostalo povrće.', 'Zaliti supom i kuhati oko 20 minuta da omekša.', 'Dio izblendati za kremastu supu.', 'Začiniti soli, biberom i mažuranom, dodati ploške hrenovki.'],
      en: ['Peel and dice the vegetables.', 'Sauté the onion in oil, add the remaining vegetables.', 'Pour in the broth and cook for about 20 minutes until soft.', 'Purée part of it for a creamy soup.', 'Season with salt, pepper and marjoram, add sausage slices.']
    }
  },

  {
    id: 'linseneintopf', kueche: 'deutsch', portionen: 5, dauer_min: 70,
    titel: { de: 'Linseneintopf', sr: 'Чорба од сочива', hr: 'Varivo od leće', ba: 'Čorba od leće', en: 'Lentil stew' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'braune Linsen', sr: 'смеђе сочиво', hr: 'smeđa leća', ba: 'smeđa leća', en: 'brown lentils' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 2, einheit: 'stk', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 150, einheit: 'g', name: { de: 'geräucherte Wurst', sr: 'димљена кобасица', hr: 'dimljena kobasica', ba: 'dimljena kobasica', en: 'smoked sausage' } },
      { menge: 2, einheit: 'el', name: { de: 'Essig', sr: 'сирће', hr: 'ocat', ba: 'sirće', en: 'vinegar' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Lorbeer', sr: 'со, бибер, ловор', hr: 'sol, papar, lovor', ba: 'so, biber, lovor', en: 'salt, pepper, bay leaf' } }
    ],
    schritte: {
      de: ['Linsen abspülen. Zwiebel in Öl anschwitzen.', 'Gewürfelte Karotten und Kartoffeln zugeben.', 'Linsen, Lorbeer und Wasser dazugeben, ca. 40 Min. köcheln.', 'Wurstscheiben zugeben und mitgaren.', 'Mit Salz, Pfeffer und einem Schuss Essig abschmecken.'],
      sr: ['Сочиво исперите. Лук продинстати на уљу.', 'Додати исецкану шаргарепу и кромпир.', 'Додати сочиво, ловор и воду, кувати око 40 минута.', 'Додати кришке кобасице и прокувати.', 'Зачинити сољу, бибером и мало сирћета.'],
      hr: ['Leću isperite. Luk popirjati na ulju.', 'Dodati narezanu mrkvu i krumpir.', 'Dodati leću, lovor i vodu, kuhati oko 40 minuta.', 'Dodati ploške kobasice i prokuhati.', 'Začiniti soli, paprom i malo octa.'],
      ba: ['Leću isperite. Luk podinstati na ulju.', 'Dodati narezanu mrkvu i krompir.', 'Dodati leću, lovor i vodu, kuhati oko 40 minuta.', 'Dodati ploške kobasice i prokuhati.', 'Začiniti soli, biberom i malo sirćeta.'],
      en: ['Rinse the lentils. Sauté the onion in oil.', 'Add the diced carrots and potatoes.', 'Add lentils, bay leaf and water, simmer for about 40 minutes.', 'Add sausage slices and cook along.', 'Season with salt, pepper and a splash of vinegar.']
    }
  },

  {
    id: 'bratwurst_sauerkraut', kueche: 'deutsch', portionen: 4, dauer_min: 40,
    titel: { de: 'Bratwurst mit Sauerkraut', sr: 'Кобасица са киселим купусом', hr: 'Kobasica s kiselim kupusom', ba: 'Kobasica sa kiselim kupusom', en: 'Bratwurst with sauerkraut' },
    zutaten: [
      { menge: 8, einheit: 'stk', name: { de: 'Bratwürste', sr: 'кобасице за печење', hr: 'kobasice za pečenje', ba: 'kobasice za pečenje', en: 'bratwurst sausages' } },
      { menge: 700, einheit: 'g', name: { de: 'Sauerkraut', sr: 'кисели купус', hr: 'kiseli kupus', ba: 'kiseli kupus', en: 'sauerkraut' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'stk', name: { de: 'Apfel', sr: 'јабука', hr: 'jabuka', ba: 'jabuka', en: 'apple' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kümmel', sr: 'ким', hr: 'kim', ba: 'kim', en: 'caraway' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Zwiebel und Apfel in Öl anschwitzen.', 'Sauerkraut und Kümmel zugeben, mit etwas Wasser 20–25 Min. schmoren.', 'Bratwürste in einer Pfanne rundum goldbraun braten.', 'Kraut mit Salz und Pfeffer abschmecken.', 'Würste auf dem Kraut anrichten.'],
      sr: ['Лук и јабуку продинстати на уљу.', 'Додати кисели купус и ким, са мало воде динстати 20–25 минута.', 'Кобасице испржити у тигању са свих страна до златне боје.', 'Купус зачинити сољу и бибером.', 'Кобасице послужити на купусу.'],
      hr: ['Luk i jabuku popirjati na ulju.', 'Dodati kiseli kupus i kim, s malo vode pirjati 20–25 minuta.', 'Kobasice popržiti u tavi sa svih strana do zlatne boje.', 'Kupus začiniti soli i paprom.', 'Kobasice poslužiti na kupusu.'],
      ba: ['Luk i jabuku podinstati na ulju.', 'Dodati kiseli kupus i kim, sa malo vode dinstati 20–25 minuta.', 'Kobasice popržiti u tavi sa svih strana do zlatne boje.', 'Kupus začiniti soli i biberom.', 'Kobasice poslužiti na kupusu.'],
      en: ['Sauté the onion and apple in oil.', 'Add sauerkraut and caraway, braise with a little water for 20–25 minutes.', 'Fry the bratwurst in a pan until golden all over.', 'Season the kraut with salt and pepper.', 'Serve the sausages on the kraut.']
    }
  },

  {
    id: 'kaiserschmarrn', kueche: 'deutsch', portionen: 3, dauer_min: 30,
    titel: { de: 'Kaiserschmarrn', sr: 'Кајзершмарн', hr: 'Carski drobljenac', ba: 'Kajzeršmarn', en: 'Kaiserschmarrn (shredded pancake)' },
    zutaten: [
      { menge: 150, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 4, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 250, einheit: 'ml', name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 2, einheit: 'el', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 40, einheit: 'g', name: { de: 'Rosinen', sr: 'суво грожђе', hr: 'grožđice', ba: 'grožđice', en: 'raisins' } },
      { menge: 30, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: null, einheit: 'ng', name: { de: 'Puderzucker', sr: 'шећер у праху', hr: 'šećer u prahu', ba: 'šećer u prahu', en: 'icing sugar' } }
    ],
    schritte: {
      de: ['Eigelb mit Milch, Mehl und Zucker glatt rühren.', 'Eiweiß steif schlagen und unterheben, Rosinen zugeben.', 'Teig in Butter in der Pfanne stocken lassen.', 'Wenden, dann mit zwei Gabeln in Stücke reißen und goldbraun rösten.', 'Mit Puderzucker bestäuben, mit Apfelmus servieren.'],
      sr: ['Жуманца умутити са млеком, брашном и шећером.', 'Беланца истући у чврст снег и умешати, додати грожђе.', 'Тесто у путеру у тигању оставити да се стегне.', 'Окренути, па виљушкама поцепати на комаде и пропржити.', 'Посути шећером у праху, послужити са пекмезом од јабука.'],
      hr: ['Žumanjke umutiti s mlijekom, brašnom i šećerom.', 'Bjelanjke istući u čvrst snijeg i umiješati, dodati grožđice.', 'Tijesto u maslacu u tavi ostaviti da se stegne.', 'Okrenuti, pa vilicama poderati na komade i popržiti.', 'Posuti šećerom u prahu, poslužiti s pekmezom od jabuka.'],
      ba: ['Žumanjke umutiti sa mlijekom, brašnom i šećerom.', 'Bjelanjke istući u čvrst snijeg i umiješati, dodati grožđice.', 'Tijesto u maslacu u tavi ostaviti da se stegne.', 'Okrenuti, pa vilicama poderati na komade i popržiti.', 'Posuti šećerom u prahu, poslužiti sa pekmezom od jabuka.'],
      en: ['Whisk egg yolks with milk, flour and sugar until smooth.', 'Beat the egg whites stiff and fold in, add the raisins.', 'Let the batter set in butter in the pan.', 'Flip, then tear into pieces with two forks and fry golden.', 'Dust with icing sugar, serve with apple sauce.']
    }
  },

  // ---- ITALIENISCH (Fortsetzung) -------------------------------------------
  {
    id: 'lasagne', kueche: 'italienisch', portionen: 6, dauer_min: 90,
    titel: { de: 'Lasagne', sr: 'Лазање', hr: 'Lazanje', ba: 'Lazanje', en: 'Lasagne' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'Lasagneplatten', sr: 'коре за лазање', hr: 'kore za lazanje', ba: 'kore za lazanje', en: 'lasagne sheets' } },
      { menge: 500, einheit: 'g', name: { de: 'Rinderhackfleisch', sr: 'јунеће млевено месо', hr: 'juneće mljeveno meso', ba: 'juneće mljeveno meso', en: 'ground beef' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 500, einheit: 'ml', name: { de: 'Béchamelsauce', sr: 'бешамел сос', hr: 'bešamel umak', ba: 'bešamel sos', en: 'béchamel sauce' } },
      { menge: 150, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Olivenöl', sr: 'со, бибер, маслиново уље', hr: 'sol, papar, maslinovo ulje', ba: 'so, biber, maslinovo ulje', en: 'salt, pepper, olive oil' } }
    ],
    schritte: {
      de: ['Zwiebel anschwitzen, Hackfleisch anbraten, Tomaten zugeben und 20 Min. köcheln.', 'Eine Form abwechselnd mit Sauce, Platten und Béchamel schichten.', 'Mit Béchamel und Käse abschließen.', 'Im Ofen bei 190 Grad ca. 35 Min. backen.', 'Vor dem Schneiden kurz ruhen lassen.'],
      sr: ['Лук продинстати, месо пропржити, додати парадајз и кувати 20 минута.', 'У посуду наизменично ређати сос, коре и бешамел.', 'Завршити бешамелом и сиром.', 'Пећи у рерни на 190 степени око 35 минута.', 'Оставити да одстоји пре сечења.'],
      hr: ['Luk popirjati, meso popržiti, dodati rajčice i kuhati 20 minuta.', 'U posudu naizmjenično slagati umak, kore i bešamel.', 'Završiti bešamelom i sirom.', 'Peći u pećnici na 190 stupnjeva oko 35 minuta.', 'Ostaviti da odstoji prije rezanja.'],
      ba: ['Luk podinstati, meso popržiti, dodati paradajz i kuhati 20 minuta.', 'U posudu naizmjenično slagati sos, kore i bešamel.', 'Završiti bešamelom i sirom.', 'Peći u pećnici na 190 stepeni oko 35 minuta.', 'Ostaviti da odstoji prije rezanja.'],
      en: ['Sauté the onion, brown the meat, add tomatoes and simmer for 20 minutes.', 'Layer a dish alternately with sauce, sheets and béchamel.', 'Finish with béchamel and cheese.', 'Bake in the oven at 190 degrees for about 35 minutes.', 'Let it rest briefly before cutting.']
    }
  },

  {
    id: 'risotto_funghi', kueche: 'italienisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Pilzrisotto', sr: 'Ризото са печуркама', hr: 'Rižoto s gljivama', ba: 'Rižoto sa gljivama', en: 'Mushroom risotto' },
    zutaten: [
      { menge: 320, einheit: 'g', name: { de: 'Risottoreis (Arborio)', sr: 'пиринач за ризото', hr: 'riža za rižoto', ba: 'riža za rižoto', en: 'risotto rice (arborio)' } },
      { menge: 300, einheit: 'g', name: { de: 'Champignons', sr: 'печурке', hr: 'šampinjoni', ba: 'šampinjoni', en: 'mushrooms' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'l', name: { de: 'Gemüsebrühe', sr: 'повртна супа', hr: 'povrtni temeljac', ba: 'povrtna supa', en: 'vegetable broth' } },
      { menge: 60, einheit: 'g', name: { de: 'Parmesan', sr: 'пармезан', hr: 'parmezan', ba: 'parmezan', en: 'parmesan' } },
      { menge: 30, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Olivenöl', sr: 'со, бибер, маслиново уље', hr: 'sol, papar, maslinovo ulje', ba: 'so, biber, maslinovo ulje', en: 'salt, pepper, olive oil' } }
    ],
    schritte: {
      de: ['Zwiebel und Pilze in Öl anbraten.', 'Reis zugeben und glasig anrösten.', 'Nach und nach heiße Brühe angießen, dabei rühren.', 'Ca. 18 Min. garen, bis der Reis cremig und bissfest ist.', 'Butter und Parmesan unterrühren, abschmecken.'],
      sr: ['Лук и печурке пропржити на уљу.', 'Додати пиринач и кратко пропржити.', 'Постепено доливати врелу супу уз мешање.', 'Кувати око 18 минута док пиринач не буде кремаст и ал денте.', 'Умешати путер и пармезан, зачинити.'],
      hr: ['Luk i gljive popržiti na ulju.', 'Dodati rižu i kratko popržiti.', 'Postupno dolijevati vrući temeljac uz miješanje.', 'Kuhati oko 18 minuta dok riža ne bude kremasta i al dente.', 'Umiješati maslac i parmezan, začiniti.'],
      ba: ['Luk i gljive popržiti na ulju.', 'Dodati rižu i kratko popržiti.', 'Postupno dolijevati vruću supu uz miješanje.', 'Kuhati oko 18 minuta dok riža ne bude kremasta i al dente.', 'Umiješati maslac i parmezan, začiniti.'],
      en: ['Fry the onion and mushrooms in oil.', 'Add the rice and toast until glossy.', 'Gradually pour in hot broth, stirring.', 'Cook for about 18 minutes until the rice is creamy and al dente.', 'Stir in butter and parmesan, season.']
    }
  },

  {
    id: 'minestrone', kueche: 'italienisch', portionen: 5, dauer_min: 50,
    titel: { de: 'Minestrone (Gemüsesuppe)', sr: 'Минестроне', hr: 'Minestrone', ba: 'Minestrone', en: 'Minestrone (vegetable soup)' },
    zutaten: [
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zucchini', sr: 'тиквице', hr: 'tikvice', ba: 'tikvice', en: 'zucchini' } },
      { menge: 1, einheit: 'stk', name: { de: 'Sellerie', sr: 'целер', hr: 'celer', ba: 'celer', en: 'celery' } },
      { menge: 400, einheit: 'g', name: { de: 'weiße Bohnen (Dose)', sr: 'бели пасуљ (конзерва)', hr: 'bijeli grah (konzerva)', ba: 'bijeli grah (konzerva)', en: 'white beans (can)' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 100, einheit: 'g', name: { de: 'kleine Nudeln', sr: 'ситна тестенина', hr: 'sitna tjestenina', ba: 'sitna tjestenina', en: 'small pasta' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Olivenöl', sr: 'со, бибер, маслиново уље', hr: 'sol, papar, maslinovo ulje', ba: 'so, biber, maslinovo ulje', en: 'salt, pepper, olive oil' } }
    ],
    schritte: {
      de: ['Gemüse würfeln und in Öl anschwitzen.', 'Tomaten und Wasser zugeben, ca. 20 Min. köcheln.', 'Bohnen und Nudeln zugeben und garen.', 'Mit Salz und Pfeffer abschmecken.', 'Mit Olivenöl und Parmesan servieren.'],
      sr: ['Поврће исецкати и продинстати на уљу.', 'Додати парадајз и воду, кувати око 20 минута.', 'Додати пасуљ и тестенину и скувати.', 'Зачинити сољу и бибером.', 'Послужити са маслиновим уљем и пармезаном.'],
      hr: ['Povrće narezati i popirjati na ulju.', 'Dodati rajčice i vodu, kuhati oko 20 minuta.', 'Dodati grah i tjesteninu i skuhati.', 'Začiniti soli i paprom.', 'Poslužiti s maslinovim uljem i parmezanom.'],
      ba: ['Povrće narezati i podinstati na ulju.', 'Dodati paradajz i vodu, kuhati oko 20 minuta.', 'Dodati grah i tjesteninu i skuhati.', 'Začiniti soli i biberom.', 'Poslužiti sa maslinovim uljem i parmezanom.'],
      en: ['Dice the vegetables and sauté in oil.', 'Add tomatoes and water, simmer for about 20 minutes.', 'Add beans and pasta and cook.', 'Season with salt and pepper.', 'Serve with olive oil and parmesan.']
    }
  },

  {
    id: 'gnocchi', kueche: 'italienisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Gnocchi mit Tomatensauce', sr: 'Њоки са сосом од парадајза', hr: 'Njoki s umakom od rajčice', ba: 'Njoki sa sosom od paradajza', en: 'Gnocchi with tomato sauce' },
    zutaten: [
      { menge: 800, einheit: 'g', name: { de: 'mehlige Kartoffeln', sr: 'брашнави кромпир', hr: 'brašnati krumpir', ba: 'brašnavi krompir', en: 'floury potatoes' } },
      { menge: 200, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 1, einheit: 'stk', name: { de: 'Ei', sr: 'јаје', hr: 'jaje', ba: 'jaje', en: 'egg' } },
      { menge: 400, einheit: 'g', name: { de: 'passierte Tomaten', sr: 'пасирани парадајз', hr: 'pasirane rajčice', ba: 'pasirani paradajz', en: 'tomato passata' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Basilikum, Olivenöl', sr: 'со, босиљак, маслиново уље', hr: 'sol, bosiljak, maslinovo ulje', ba: 'so, bosiljak, maslinovo ulje', en: 'salt, basil, olive oil' } }
    ],
    schritte: {
      de: ['Kartoffeln kochen, pellen und durchpressen.', 'Mit Mehl, Ei und Salz zu einem Teig verkneten.', 'Rollen formen, in Stücke schneiden und mit der Gabel prägen.', 'In Salzwasser garen, bis sie aufsteigen.', 'Tomaten mit Knoblauch zu einer Sauce köcheln und mit den Gnocchi mischen.'],
      sr: ['Кромпир скувати, огулити и испресовати.', 'Умесити са брашном, јајетом и сољу у тесто.', 'Обликовати ваљке, исећи на комаде и утиснути виљушком.', 'Кувати у сланој води док не испливају.', 'Парадајз са белим луком укувати у сос и помешати са њокима.'],
      hr: ['Krumpir skuhati, oguliti i propasirati.', 'Umijesiti s brašnom, jajetom i soli u tijesto.', 'Oblikovati valjke, narezati na komade i utisnuti vilicom.', 'Kuhati u slanoj vodi dok ne isplivaju.', 'Rajčice s češnjakom ukuhati u umak i pomiješati s njokima.'],
      ba: ['Krompir skuhati, oguliti i propasirati.', 'Umijesiti sa brašnom, jajetom i soli u tijesto.', 'Oblikovati valjke, narezati na komade i utisnuti vilicom.', 'Kuhati u slanoj vodi dok ne isplivaju.', 'Paradajz sa bijelim lukom ukuhati u sos i pomiješati sa njokima.'],
      en: ['Boil the potatoes, peel and press through a ricer.', 'Knead with flour, egg and salt into a dough.', 'Form rolls, cut into pieces and press with a fork.', 'Cook in salted water until they float.', 'Simmer tomatoes with garlic into a sauce and toss with the gnocchi.']
    }
  },

  {
    id: 'caprese', kueche: 'italienisch', portionen: 4, dauer_min: 10,
    titel: { de: 'Caprese-Salat', sr: 'Капрезе салата', hr: 'Caprese salata', ba: 'Caprese salata', en: 'Caprese salad' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 250, einheit: 'g', name: { de: 'Mozzarella', sr: 'моцарела', hr: 'mozzarella', ba: 'mozzarella', en: 'mozzarella' } },
      { menge: 1, einheit: 'bund', name: { de: 'frisches Basilikum', sr: 'свеж босиљак', hr: 'svježi bosiljak', ba: 'svježi bosiljak', en: 'fresh basil' } },
      { menge: 3, einheit: 'el', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } }
    ],
    schritte: {
      de: ['Tomaten und Mozzarella in Scheiben schneiden.', 'Abwechselnd auf einem Teller anrichten.', 'Basilikumblätter dazwischenlegen.', 'Mit Olivenöl beträufeln, salzen und pfeffern.'],
      sr: ['Парадајз и моцарелу исећи на кришке.', 'Наизменично поређати на тањир.', 'Између ставити листове босиљка.', 'Прелити маслиновим уљем, посолити и побиберити.'],
      hr: ['Rajčice i mozzarellu narezati na ploške.', 'Naizmjenično posložiti na tanjur.', 'Između staviti listove bosiljka.', 'Preliti maslinovim uljem, posoliti i popapriti.'],
      ba: ['Paradajz i mozzarellu narezati na ploške.', 'Naizmjenično posložiti na tanjir.', 'Između staviti listove bosiljka.', 'Preliti maslinovim uljem, posoliti i pobiberiti.'],
      en: ['Slice the tomatoes and mozzarella.', 'Arrange alternately on a plate.', 'Place basil leaves in between.', 'Drizzle with olive oil, season with salt and pepper.']
    }
  },

  {
    id: 'tiramisu', kueche: 'italienisch', portionen: 6, dauer_min: 30,
    titel: { de: 'Tiramisu', sr: 'Тирамису', hr: 'Tiramisu', ba: 'Tiramisu', en: 'Tiramisu' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'Mascarpone', sr: 'маскарпоне', hr: 'mascarpone', ba: 'mascarpone', en: 'mascarpone' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 80, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 200, einheit: 'g', name: { de: 'Löffelbiskuits', sr: 'пишкоте', hr: 'piškote', ba: 'piškote', en: 'ladyfingers' } },
      { menge: 250, einheit: 'ml', name: { de: 'starker Kaffee (abgekühlt)', sr: 'јака кафа (охлађена)', hr: 'jaka kava (ohlađena)', ba: 'jaka kahva (ohlađena)', en: 'strong coffee (cooled)' } },
      { menge: null, einheit: 'ng', name: { de: 'Kakaopulver', sr: 'какао', hr: 'kakao', ba: 'kakao', en: 'cocoa powder' } }
    ],
    schritte: {
      de: ['Eigelb mit Zucker schaumig rühren, Mascarpone unterrühren.', 'Eiweiß steif schlagen und vorsichtig unterheben.', 'Löffelbiskuits kurz in Kaffee tauchen und in eine Form legen.', 'Abwechselnd Creme und Biskuits schichten.', 'Mit Kakao bestäuben und mind. 4 Std. kühlen.'],
      sr: ['Жуманца са шећером умутити пенасто, умешати маскарпоне.', 'Беланца истући у чврст снег и пажљиво умешати.', 'Пишкоте кратко умочити у кафу и ређати у посуду.', 'Наизменично ређати крем и пишкоте.', 'Посути какаом и хладити најмање 4 сата.'],
      hr: ['Žumanjke sa šećerom umutiti pjenasto, umiješati mascarpone.', 'Bjelanjke istući u čvrst snijeg i pažljivo umiješati.', 'Piškote kratko umočiti u kavu i slagati u posudu.', 'Naizmjenično slagati kremu i piškote.', 'Posuti kakaom i hladiti najmanje 4 sata.'],
      ba: ['Žumanjke sa šećerom umutiti pjenasto, umiješati mascarpone.', 'Bjelanjke istući u čvrst snijeg i pažljivo umiješati.', 'Piškote kratko umočiti u kahvu i slagati u posudu.', 'Naizmjenično slagati kremu i piškote.', 'Posuti kakaom i hladiti najmanje 4 sata.'],
      en: ['Whisk egg yolks with sugar until fluffy, stir in mascarpone.', 'Beat egg whites stiff and fold in gently.', 'Briefly dip the ladyfingers in coffee and place in a dish.', 'Layer cream and ladyfingers alternately.', 'Dust with cocoa and chill for at least 4 hours.']
    }
  },

  {
    id: 'pasta_pomodoro', kueche: 'italienisch', portionen: 4, dauer_min: 25,
    titel: { de: 'Pasta al Pomodoro', sr: 'Паста са парадајзом', hr: 'Tjestenina s rajčicom', ba: 'Tjestenina sa paradajzom', en: 'Pasta al pomodoro' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Nudeln (Penne)', sr: 'тестенина (пене)', hr: 'tjestenina (penne)', ba: 'tjestenina (penne)', en: 'pasta (penne)' } },
      { menge: 500, einheit: 'g', name: { de: 'passierte Tomaten', sr: 'пасирани парадајз', hr: 'pasirane rajčice', ba: 'pasirani paradajz', en: 'tomato passata' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'bund', name: { de: 'Basilikum', sr: 'босиљак', hr: 'bosiljak', ba: 'bosiljak', en: 'basil' } },
      { menge: 40, einheit: 'g', name: { de: 'Parmesan', sr: 'пармезан', hr: 'parmezan', ba: 'parmezan', en: 'parmesan' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Olivenöl', sr: 'со, маслиново уље', hr: 'sol, maslinovo ulje', ba: 'so, maslinovo ulje', en: 'salt, olive oil' } }
    ],
    schritte: {
      de: ['Knoblauch in Olivenöl anduften lassen.', 'Passierte Tomaten zugeben, salzen und 10–15 Min. köcheln.', 'Nudeln al dente kochen und abgießen.', 'Nudeln mit der Sauce und Basilikum mischen.', 'Mit Parmesan servieren.'],
      sr: ['Бели лук пропржити на маслиновом уљу.', 'Додати пасирани парадајз, посолити и кувати 10–15 минута.', 'Тестенину скувати ал денте и оцедити.', 'Тестенину помешати са сосом и босиљком.', 'Послужити са пармезаном.'],
      hr: ['Češnjak popržiti na maslinovom ulju.', 'Dodati pasirane rajčice, posoliti i kuhati 10–15 minuta.', 'Tjesteninu skuhati al dente i ocijediti.', 'Tjesteninu pomiješati s umakom i bosiljkom.', 'Poslužiti s parmezanom.'],
      ba: ['Bijeli luk popržiti na maslinovom ulju.', 'Dodati pasirani paradajz, posoliti i kuhati 10–15 minuta.', 'Tjesteninu skuhati al dente i ocijediti.', 'Tjesteninu pomiješati sa sosom i bosiljkom.', 'Poslužiti sa parmezanom.'],
      en: ['Let the garlic release its aroma in olive oil.', 'Add the passata, salt and simmer for 10–15 minutes.', 'Cook the pasta al dente and drain.', 'Toss the pasta with the sauce and basil.', 'Serve with parmesan.']
    }
  },

  // ---- CHINESISCH ----------------------------------------------------------
  {
    id: 'gebratener_reis', kueche: 'chinesisch', portionen: 4, dauer_min: 25,
    titel: { de: 'Gebratener Reis', sr: 'Пржени пиринач', hr: 'Pržena riža', ba: 'Pržena riža', en: 'Fried rice' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'gekochter Reis (vom Vortag)', sr: 'кувани пиринач (од јуче)', hr: 'kuhana riža (od jučer)', ba: 'kuhana riža (od jučer)', en: 'cooked rice (day-old)' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 150, einheit: 'g', name: { de: 'Erbsen und Karotten', sr: 'грашак и шаргарепа', hr: 'grašak i mrkva', ba: 'grašak i mrkva', en: 'peas and carrots' } },
      { menge: 3, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } },
      { menge: 3, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 2, einheit: 'el', name: { de: 'Öl', sr: 'уље', hr: 'ulje', ba: 'ulje', en: 'oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Öl in einer Pfanne oder im Wok stark erhitzen.', 'Verquirlte Eier hineingeben und stocken lassen, grob zerteilen.', 'Gemüse zugeben und kurz anbraten.', 'Reis dazugeben und unter Rühren heiß braten.', 'Mit Sojasauce, Salz und Pfeffer würzen, Frühlingszwiebeln unterrühren.'],
      sr: ['Уље у тигању или воку јако загрејати.', 'Умућена јаја убацити и оставити да се стегну, крупно исецкати.', 'Додати поврће и кратко пропржити.', 'Додати пиринач и уз мешање пржити да се загреје.', 'Зачинити соја сосом, сољу и бибером, умешати млади лук.'],
      hr: ['Ulje u tavi ili woku jako zagrijati.', 'Umućena jaja ubaciti i ostaviti da se stegnu, grubo nasjeckati.', 'Dodati povrće i kratko popržiti.', 'Dodati rižu i uz miješanje pržiti da se zagrije.', 'Začiniti soja umakom, soli i paprom, umiješati mladi luk.'],
      ba: ['Ulje u tavi ili woku jako zagrijati.', 'Umućena jaja ubaciti i ostaviti da se stegnu, grubo nasjeckati.', 'Dodati povrće i kratko popržiti.', 'Dodati rižu i uz miješanje pržiti da se zagrije.', 'Začiniti soja sosom, soli i biberom, umiješati mladi luk.'],
      en: ['Heat oil in a pan or wok until very hot.', 'Add beaten eggs and let set, break up roughly.', 'Add the vegetables and stir-fry briefly.', 'Add the rice and stir-fry until hot.', 'Season with soy sauce, salt and pepper, stir in the spring onions.']
    }
  },

  {
    id: 'suess_sauer_huhn', kueche: 'chinesisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Süß-saures Hühnchen', sr: 'Слатко-кисела пилетина', hr: 'Slatko-kisela piletina', ba: 'Slatko-kisela piletina', en: 'Sweet and sour chicken' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Hähnchenbrust', sr: 'пилеће бело месо', hr: 'pileća prsa', ba: 'pileća prsa', en: 'chicken breast' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 200, einheit: 'g', name: { de: 'Ananas', sr: 'ананас', hr: 'ananas', ba: 'ananas', en: 'pineapple' } },
      { menge: 3, einheit: 'el', name: { de: 'Ketchup', sr: 'кечап', hr: 'kečap', ba: 'kečap', en: 'ketchup' } },
      { menge: 2, einheit: 'el', name: { de: 'Essig', sr: 'сирће', hr: 'ocat', ba: 'sirće', en: 'vinegar' } },
      { menge: 2, einheit: 'el', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 1, einheit: 'el', name: { de: 'Speisestärke', sr: 'густин', hr: 'gustin', ba: 'gustin', en: 'cornstarch' } }
    ],
    schritte: {
      de: ['Hähnchen würfeln, in Stärke wenden und knusprig braten.', 'Paprika kurz anbraten, Ananas zugeben.', 'Ketchup, Essig, Zucker und etwas Wasser zu einer Sauce verrühren.', 'Sauce zugießen und aufkochen, mit angerührter Stärke binden.', 'Hähnchen unterheben und mit Reis servieren.'],
      sr: ['Пилетину исећи на коцке, уваљати у густин и испржити да буде хрскава.', 'Паприку кратко пропржити, додати ананас.', 'Кечап, сирће, шећер и мало воде умешати у сос.', 'Долити сос и прокувати, згуснути размућеним густином.', 'Умешати пилетину и послужити са пиринчем.'],
      hr: ['Piletinu narezati na kocke, uvaljati u gustin i pržiti da bude hrskava.', 'Papriku kratko popržiti, dodati ananas.', 'Kečap, ocat, šećer i malo vode umiješati u umak.', 'Uliti umak i prokuhati, zgusnuti razmućenim gustinom.', 'Umiješati piletinu i poslužiti s rižom.'],
      ba: ['Piletinu narezati na kocke, uvaljati u gustin i pržiti da bude hrskava.', 'Papriku kratko popržiti, dodati ananas.', 'Kečap, sirće, šećer i malo vode umiješati u sos.', 'Uliti sos i prokuhati, zgusnuti razmućenim gustinom.', 'Umiješati piletinu i poslužiti sa rižom.'],
      en: ['Cube the chicken, coat in cornstarch and fry until crisp.', 'Fry the pepper briefly, add pineapple.', 'Mix ketchup, vinegar, sugar and a little water into a sauce.', 'Pour in the sauce and bring to a boil, thicken with slurry.', 'Fold in the chicken and serve with rice.']
    }
  },

  {
    id: 'chow_mein', kueche: 'chinesisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Chow Mein (gebratene Nudeln)', sr: 'Чоу меин (пржени резанци)', hr: 'Chow mein (pržani rezanci)', ba: 'Chow mein (prženi rezanci)', en: 'Chow mein (fried noodles)' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Eiernudeln', sr: 'резанци са јајима', hr: 'jajni rezanci', ba: 'jajni rezanci', en: 'egg noodles' } },
      { menge: 200, einheit: 'g', name: { de: 'Hähnchen oder Tofu', sr: 'пилетина или тофу', hr: 'piletina ili tofu', ba: 'piletina ili tofu', en: 'chicken or tofu' } },
      { menge: 150, einheit: 'g', name: { de: 'Weißkohl', sr: 'бели купус', hr: 'bijeli kupus', ba: 'bijeli kupus', en: 'white cabbage' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 3, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 2, einheit: 'el', name: { de: 'Öl', sr: 'уље', hr: 'ulje', ba: 'ulje', en: 'oil' } }
    ],
    schritte: {
      de: ['Nudeln nach Packung kochen und abtropfen lassen.', 'Fleisch/Tofu im Wok scharf anbraten und herausnehmen.', 'Gemüse mit Knoblauch kräftig unter Rühren braten.', 'Nudeln und Fleisch zurückgeben.', 'Mit Sojasauce würzen und alles heiß durchschwenken.'],
      sr: ['Резанце скувати по упутству и оцедити.', 'Месо/тофу у воку јако пропржити и извадити.', 'Поврће са белим луком снажно пропржити уз мешање.', 'Вратити резанце и месо.', 'Зачинити соја сосом и све врело промешати.'],
      hr: ['Rezance skuhati po uputama i ocijediti.', 'Meso/tofu u woku jako popržiti i izvaditi.', 'Povrće s češnjakom snažno popržiti uz miješanje.', 'Vratiti rezance i meso.', 'Začiniti soja umakom i sve vruće promiješati.'],
      ba: ['Rezance skuhati po uputama i ocijediti.', 'Meso/tofu u woku jako popržiti i izvaditi.', 'Povrće sa bijelim lukom snažno popržiti uz miješanje.', 'Vratiti rezance i meso.', 'Začiniti soja sosom i sve vruće promiješati.'],
      en: ['Cook the noodles per the packet and drain.', 'Sear the meat/tofu in the wok and remove.', 'Stir-fry the vegetables with garlic over high heat.', 'Return the noodles and meat.', 'Season with soy sauce and toss everything hot.']
    }
  },

  {
    id: 'mapo_tofu', kueche: 'chinesisch', portionen: 3, dauer_min: 25,
    titel: { de: 'Mapo Tofu', sr: 'Мапо тофу', hr: 'Mapo tofu', ba: 'Mapo tofu', en: 'Mapo tofu' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Tofu', sr: 'тофу', hr: 'tofu', ba: 'tofu', en: 'tofu' } },
      { menge: 150, einheit: 'g', name: { de: 'Schweinehack', sr: 'свињско млевено месо', hr: 'svinjsko mljeveno meso', ba: 'svinjsko mljeveno meso', en: 'ground pork' } },
      { menge: 2, einheit: 'el', name: { de: 'scharfe Bohnenpaste', sr: 'љута паста од пасуља', hr: 'ljuta pasta od graha', ba: 'ljuta pasta od graha', en: 'spicy bean paste' } },
      { menge: 3, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 1, einheit: 'el', name: { de: 'Speisestärke', sr: 'густин', hr: 'gustin', ba: 'gustin', en: 'cornstarch' } }
    ],
    schritte: {
      de: ['Tofu würfeln. Hackfleisch mit Knoblauch anbraten.', 'Bohnenpaste einrühren und kurz mitbraten.', 'Mit etwas Wasser und Sojasauce aufgießen.', 'Tofu vorsichtig zugeben und kurz köcheln.', 'Mit angerührter Stärke binden, Frühlingszwiebeln darüberstreuen.'],
      sr: ['Тофу исећи на коцке. Месо са белим луком пропржити.', 'Умешати пасту од пасуља и кратко пропржити.', 'Долити мало воде и соја сос.', 'Пажљиво додати тофу и кратко прокувати.', 'Згуснути размућеним густином, посути млади лук.'],
      hr: ['Tofu narezati na kocke. Meso s češnjakom popržiti.', 'Umiješati pastu od graha i kratko popržiti.', 'Uliti malo vode i soja umak.', 'Pažljivo dodati tofu i kratko prokuhati.', 'Zgusnuti razmućenim gustinom, posuti mladi luk.'],
      ba: ['Tofu narezati na kocke. Meso sa bijelim lukom popržiti.', 'Umiješati pastu od graha i kratko popržiti.', 'Uliti malo vode i soja sos.', 'Pažljivo dodati tofu i kratko prokuhati.', 'Zgusnuti razmućenim gustinom, posuti mladi luk.'],
      en: ['Cube the tofu. Fry the ground meat with garlic.', 'Stir in the bean paste and fry briefly.', 'Add a little water and soy sauce.', 'Carefully add the tofu and simmer briefly.', 'Thicken with slurry, sprinkle with spring onions.']
    }
  },

  {
    id: 'wan_tan_suppe', kueche: 'chinesisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Wan-Tan-Suppe', sr: 'Вон тон супа', hr: 'Wonton juha', ba: 'Wonton supa', en: 'Wonton soup' },
    zutaten: [
      { menge: 20, einheit: 'stk', name: { de: 'Wan-Tan-Teigblätter', sr: 'коре за вон тон', hr: 'kore za wonton', ba: 'kore za wonton', en: 'wonton wrappers' } },
      { menge: 250, einheit: 'g', name: { de: 'Schweinehack', sr: 'свињско млевено месо', hr: 'svinjsko mljeveno meso', ba: 'svinjsko mljeveno meso', en: 'ground pork' } },
      { menge: 1, einheit: 'el', name: { de: 'Ingwer (gerieben)', sr: 'ђумбир (рендани)', hr: 'đumbir (naribani)', ba: 'đumbir (naribani)', en: 'ginger (grated)' } },
      { menge: 2, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 1.5, einheit: 'l', name: { de: 'Hühnerbrühe', sr: 'пилећа супа', hr: 'pileći temeljac', ba: 'pileća supa', en: 'chicken broth' } },
      { menge: 3, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } }
    ],
    schritte: {
      de: ['Hack mit Ingwer, Sojasauce und etwas Frühlingszwiebel mischen.', 'Je einen Teelöffel Füllung auf ein Teigblatt geben und zu Täschchen formen.', 'Brühe zum Kochen bringen.', 'Wan-Tan hineingeben und 4–5 Min. ziehen lassen, bis sie oben schwimmen.', 'Mit Frühlingszwiebeln bestreut servieren.'],
      sr: ['Месо помешати са ђумбиром, соја сосом и мало младог лука.', 'На сваку кору ставити кашичицу фила и обликовати кесице.', 'Супу довести до кључања.', 'Убацити вон тоне и оставити 4–5 минута док не испливају.', 'Послужити посуто младим луком.'],
      hr: ['Meso pomiješati s đumbirom, soja umakom i malo mladog luka.', 'Na svaku koru staviti žličicu nadjeva i oblikovati vrećice.', 'Temeljac dovesti do vrenja.', 'Ubaciti wontone i ostaviti 4–5 minuta dok ne isplivaju.', 'Poslužiti posuto mladim lukom.'],
      ba: ['Meso pomiješati sa đumbirom, soja sosom i malo mladog luka.', 'Na svaku koru staviti kašičicu nadjeva i oblikovati vrećice.', 'Supu dovesti do ključanja.', 'Ubaciti wontone i ostaviti 4–5 minuta dok ne isplivaju.', 'Poslužiti posuto mladim lukom.'],
      en: ['Mix the meat with ginger, soy sauce and a little spring onion.', 'Put a teaspoon of filling on each wrapper and form parcels.', 'Bring the broth to a boil.', 'Add the wontons and simmer 4–5 minutes until they float.', 'Serve sprinkled with spring onions.']
    }
  },

  {
    id: 'rind_brokkoli', kueche: 'chinesisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Rind mit Brokkoli', sr: 'Јунетина са броколијем', hr: 'Junetina s brokulom', ba: 'Junetina sa brokulom', en: 'Beef with broccoli' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Rindfleisch (Streifen)', sr: 'јунетина (траке)', hr: 'junetina (trake)', ba: 'junetina (trake)', en: 'beef (strips)' } },
      { menge: 400, einheit: 'g', name: { de: 'Brokkoli', sr: 'броколи', hr: 'brokula', ba: 'brokula', en: 'broccoli' } },
      { menge: 3, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 1, einheit: 'el', name: { de: 'Austernsauce', sr: 'остриге сос', hr: 'oyster umak', ba: 'oyster sos', en: 'oyster sauce' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'el', name: { de: 'Speisestärke', sr: 'густин', hr: 'gustin', ba: 'gustin', en: 'cornstarch' } },
      { menge: 2, einheit: 'el', name: { de: 'Öl', sr: 'уље', hr: 'ulje', ba: 'ulje', en: 'oil' } }
    ],
    schritte: {
      de: ['Rindfleisch mit etwas Sojasauce und Stärke marinieren.', 'Brokkoli kurz blanchieren.', 'Fleisch im heißen Wok scharf anbraten und herausnehmen.', 'Knoblauch und Brokkoli anbraten, Fleisch zurückgeben.', 'Mit Soja- und Austernsauce würzen, kurz binden lassen.'],
      sr: ['Јунетину маринирати са мало соја соса и густина.', 'Броколи кратко бланширати.', 'Месо у врелом воку јако пропржити и извадити.', 'Пропржити бели лук и броколи, вратити месо.', 'Зачинити соја и остриге сосом, кратко згуснути.'],
      hr: ['Junetinu marinirati s malo soja umaka i gustina.', 'Brokulu kratko blanširati.', 'Meso u vrućem woku jako popržiti i izvaditi.', 'Popržiti češnjak i brokulu, vratiti meso.', 'Začiniti soja i oyster umakom, kratko zgusnuti.'],
      ba: ['Junetinu marinirati sa malo soja sosa i gustina.', 'Brokulu kratko blanširati.', 'Meso u vrućem woku jako popržiti i izvaditi.', 'Popržiti bijeli luk i brokulu, vratiti meso.', 'Začiniti soja i oyster sosom, kratko zgusnuti.'],
      en: ['Marinate the beef with a little soy sauce and cornstarch.', 'Blanch the broccoli briefly.', 'Sear the beef in a hot wok and remove.', 'Fry the garlic and broccoli, return the beef.', 'Season with soy and oyster sauce, thicken briefly.']
    }
  },

  {
    id: 'fruehlingsrollen', kueche: 'chinesisch', portionen: 4, dauer_min: 50,
    titel: { de: 'Frühlingsrollen', sr: 'Пролећне ролнице', hr: 'Proljetne rolice', ba: 'Proljetne rolnice', en: 'Spring rolls' },
    zutaten: [
      { menge: 12, einheit: 'stk', name: { de: 'Frühlingsrollen-Teigblätter', sr: 'коре за ролнице', hr: 'kore za rolice', ba: 'kore za rolnice', en: 'spring roll wrappers' } },
      { menge: 200, einheit: 'g', name: { de: 'Weißkohl', sr: 'бели купус', hr: 'bijeli kupus', ba: 'bijeli kupus', en: 'white cabbage' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 100, einheit: 'g', name: { de: 'Sojasprossen', sr: 'клице соје', hr: 'klice soje', ba: 'klice soje', en: 'bean sprouts' } },
      { menge: 2, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl zum Frittieren', sr: 'уље за пржење', hr: 'ulje za prženje', ba: 'ulje za prženje', en: 'oil for frying' } }
    ],
    schritte: {
      de: ['Gemüse fein raspeln und im Wok kurz anbraten, mit Sojasauce würzen.', 'Füllung abkühlen lassen.', 'Auf jedes Teigblatt etwas Füllung geben und fest aufrollen, Rand mit Wasser verkleben.', 'In heißem Öl goldbraun frittieren.', 'Auf Küchenpapier abtropfen lassen und heiß servieren.'],
      sr: ['Поврће ситно нарендати и у воку кратко пропржити, зачинити соја сосом.', 'Фил охладити.', 'На сваку кору ставити мало фила и чврсто уролати, ивицу залепити водом.', 'У врелом уљу испржити до златне боје.', 'Оцедити на папиру и послужити вруће.'],
      hr: ['Povrće sitno naribati i u woku kratko popržiti, začiniti soja umakom.', 'Nadjev ohladiti.', 'Na svaku koru staviti malo nadjeva i čvrsto zamotati, rub zalijepiti vodom.', 'U vrućem ulju pržiti do zlatne boje.', 'Ocijediti na papiru i poslužiti vruće.'],
      ba: ['Povrće sitno naribati i u woku kratko popržiti, začiniti soja sosom.', 'Nadjev ohladiti.', 'Na svaku koru staviti malo nadjeva i čvrsto zamotati, rub zalijepiti vodom.', 'U vrućem ulju pržiti do zlatne boje.', 'Ocijediti na papiru i poslužiti vruće.'],
      en: ['Finely grate the vegetables and stir-fry briefly, season with soy sauce.', 'Let the filling cool.', 'Put some filling on each wrapper and roll tightly, seal the edge with water.', 'Deep-fry in hot oil until golden.', 'Drain on paper towels and serve hot.']
    }
  },

  {
    id: 'gebratene_nudeln_gemuese', kueche: 'chinesisch', portionen: 4, dauer_min: 25,
    titel: { de: 'Gebratene Nudeln mit Gemüse', sr: 'Пржени резанци са поврћем', hr: 'Prženi rezanci s povrćem', ba: 'Prženi rezanci sa povrćem', en: 'Stir-fried noodles with vegetables' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Mie-Nudeln', sr: 'ми резанци', hr: 'mie rezanci', ba: 'mie rezanci', en: 'mie noodles' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 150, einheit: 'g', name: { de: 'Zuckerschoten', sr: 'млади грашак', hr: 'mahune graška', ba: 'mahune graška', en: 'snap peas' } },
      { menge: 3, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 1, einheit: 'el', name: { de: 'Sesamöl', sr: 'сусамово уље', hr: 'sezamovo ulje', ba: 'sezamovo ulje', en: 'sesame oil' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } }
    ],
    schritte: {
      de: ['Nudeln garen und abtropfen lassen.', 'Gemüse in Streifen schneiden.', 'Knoblauch und Gemüse im Wok scharf anbraten.', 'Nudeln zugeben und unter Rühren mitbraten.', 'Mit Soja- und Sesamöl würzen und heiß servieren.'],
      sr: ['Резанце скувати и оцедити.', 'Поврће исећи на траке.', 'Бели лук и поврће у воку јако пропржити.', 'Додати резанце и уз мешање пропржити.', 'Зачинити соја и сусамовим уљем и послужити вруће.'],
      hr: ['Rezance skuhati i ocijediti.', 'Povrće narezati na trake.', 'Češnjak i povrće u woku jako popržiti.', 'Dodati rezance i uz miješanje popržiti.', 'Začiniti soja i sezamovim uljem i poslužiti vruće.'],
      ba: ['Rezance skuhati i ocijediti.', 'Povrće narezati na trake.', 'Bijeli luk i povrće u woku jako popržiti.', 'Dodati rezance i uz miješanje popržiti.', 'Začiniti soja i sezamovim uljem i poslužiti vruće.'],
      en: ['Cook the noodles and drain.', 'Cut the vegetables into strips.', 'Stir-fry the garlic and vegetables in a hot wok.', 'Add the noodles and stir-fry.', 'Season with soy and sesame oil and serve hot.']
    }
  },

  // ---- AMERIKANISCH --------------------------------------------------------
  {
    id: 'cheeseburger', kueche: 'amerikanisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Cheeseburger', sr: 'Чизбургер', hr: 'Cheeseburger', ba: 'Cheeseburger', en: 'Cheeseburger' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Rinderhackfleisch', sr: 'јунеће млевено месо', hr: 'juneće mljeveno meso', ba: 'juneće mljeveno meso', en: 'ground beef' } },
      { menge: 4, einheit: 'stk', name: { de: 'Burgerbrötchen', sr: 'бургер лепиње', hr: 'burger pecivo', ba: 'burger pecivo', en: 'burger buns' } },
      { menge: 4, einheit: 'stk', name: { de: 'Käsescheiben (Cheddar)', sr: 'кришке сира (чедар)', hr: 'ploške sira (cheddar)', ba: 'ploške sira (cheddar)', en: 'cheese slices (cheddar)' } },
      { menge: 1, einheit: 'stk', name: { de: 'Tomate', sr: 'парадајз', hr: 'rajčica', ba: 'paradajz', en: 'tomato' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 4, einheit: 'stk', name: { de: 'Salatblätter', sr: 'листови зелене салате', hr: 'listovi zelene salate', ba: 'listovi zelene salate', en: 'lettuce leaves' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Ketchup', sr: 'со, бибер, кечап', hr: 'sol, papar, kečap', ba: 'so, biber, kečap', en: 'salt, pepper, ketchup' } }
    ],
    schritte: {
      de: ['Hackfleisch salzen, pfeffern und zu vier flachen Patties formen.', 'In der Pfanne oder auf dem Grill pro Seite 3–4 Min. braten.', 'Kurz vor Ende je eine Käsescheibe auflegen und schmelzen lassen.', 'Brötchen halbieren und kurz anrösten.', 'Mit Salat, Tomate, Zwiebel, Patty und Ketchup belegen.'],
      sr: ['Месо посолити, побиберити и обликовати четири плоснате пљескавице.', 'У тигању или на роштиљу пржити 3–4 минута са сваке стране.', 'Пред крај ставити кришку сира да се отопи.', 'Лепиње преполовити и кратко пропржити.', 'Сложити салату, парадајз, лук, пљескавицу и кечап.'],
      hr: ['Meso posoliti, popapriti i oblikovati četiri plosnata pljeskavica.', 'U tavi ili na roštilju pržiti 3–4 minute sa svake strane.', 'Pred kraj staviti ploške sira da se otopi.', 'Peciva prepoloviti i kratko popržiti.', 'Složiti salatu, rajčicu, luk, pljeskavicu i kečap.'],
      ba: ['Meso posoliti, pobiberiti i oblikovati četiri plosnate pljeskavice.', 'U tavi ili na roštilju pržiti 3–4 minute sa svake strane.', 'Pred kraj staviti ploške sira da se otopi.', 'Peciva prepoloviti i kratko popržiti.', 'Složiti salatu, paradajz, luk, pljeskavicu i kečap.'],
      en: ['Season the beef, and form four flat patties.', 'Fry in a pan or on the grill for 3–4 minutes per side.', 'Near the end, add a cheese slice and let it melt.', 'Halve the buns and toast briefly.', 'Assemble with lettuce, tomato, onion, patty and ketchup.']
    }
  },

  {
    id: 'pancakes', kueche: 'amerikanisch', portionen: 4, dauer_min: 25,
    titel: { de: 'American Pancakes', sr: 'Америчке палачинке', hr: 'Američke palačinke', ba: 'Američke palačinke', en: 'American pancakes' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 300, einheit: 'ml', name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 2, einheit: 'tl', name: { de: 'Backpulver', sr: 'прашак за пециво', hr: 'prašak za pecivo', ba: 'prašak za pecivo', en: 'baking powder' } },
      { menge: 2, einheit: 'el', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 30, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: null, einheit: 'ng', name: { de: 'Ahornsirup', sr: 'јаворов сируп', hr: 'javorov sirup', ba: 'javorov sirup', en: 'maple syrup' } }
    ],
    schritte: {
      de: ['Mehl, Backpulver und Zucker mischen.', 'Eier, Milch und geschmolzene Butter unterrühren, bis ein dickflüssiger Teig entsteht.', 'Kleine Portionen in eine leicht gefettete Pfanne geben.', 'Backen, bis Blasen entstehen, dann wenden.', 'Warm mit Ahornsirup servieren.'],
      sr: ['Брашно, прашак за пециво и шећер помешати.', 'Умешати јаја, млеко и отопљени путер до густог теста.', 'Мале порције сипати у благо подмазан тигањ.', 'Пећи док се не појаве мехурићи, па окренути.', 'Топло послужити са јаворовим сирупом.'],
      hr: ['Brašno, prašak za pecivo i šećer pomiješati.', 'Umiješati jaja, mlijeko i otopljeni maslac do gustog tijesta.', 'Male porcije uliti u blago podmazanu tavu.', 'Peći dok se ne pojave mjehurići, pa okrenuti.', 'Toplo poslužiti s javorovim sirupom.'],
      ba: ['Brašno, prašak za pecivo i šećer pomiješati.', 'Umiješati jaja, mlijeko i otopljeni maslac do gustog tijesta.', 'Male porcije uliti u blago podmazanu tavu.', 'Peći dok se ne pojave mjehurići, pa okrenuti.', 'Toplo poslužiti sa javorovim sirupom.'],
      en: ['Mix flour, baking powder and sugar.', 'Stir in eggs, milk and melted butter to form a thick batter.', 'Pour small portions into a lightly greased pan.', 'Cook until bubbles form, then flip.', 'Serve warm with maple syrup.']
    }
  },

  {
    id: 'mac_and_cheese', kueche: 'amerikanisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Mac and Cheese', sr: 'Мак енд чиз', hr: 'Mac and cheese', ba: 'Mac and cheese', en: 'Mac and cheese' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Makkaroni', sr: 'макароне', hr: 'makaroni', ba: 'makaroni', en: 'macaroni' } },
      { menge: 40, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: 40, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 500, einheit: 'ml', name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 250, einheit: 'g', name: { de: 'geriebener Cheddar', sr: 'рендани чедар', hr: 'naribani cheddar', ba: 'naribani cheddar', en: 'grated cheddar' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Muskat', sr: 'со, бибер, мушкатни орашчић', hr: 'sol, papar, muškatni oraščić', ba: 'so, biber, muškatni oraščić', en: 'salt, pepper, nutmeg' } }
    ],
    schritte: {
      de: ['Makkaroni al dente kochen und abgießen.', 'Butter schmelzen, Mehl einrühren, mit Milch zu einer glatten Sauce aufkochen.', 'Käse unterrühren, bis er schmilzt, mit Salz, Pfeffer und Muskat würzen.', 'Nudeln mit der Käsesauce mischen.', 'Nach Wunsch mit etwas Käse im Ofen überbacken.'],
      sr: ['Макароне скувати ал денте и оцедити.', 'Отопити путер, умешати брашно, са млеком прокувати у глатки сос.', 'Умешати сир док се не отопи, зачинити сољу, бибером и мушкатним орашчићем.', 'Тестенину помешати са сосом од сира.', 'По жељи запећи у рерни са мало сира.'],
      hr: ['Makarone skuhati al dente i ocijediti.', 'Otopiti maslac, umiješati brašno, s mlijekom prokuhati u glatki umak.', 'Umiješati sir dok se ne otopi, začiniti soli, paprom i muškatnim oraščićem.', 'Tjesteninu pomiješati s umakom od sira.', 'Po želji zapeći u pećnici s malo sira.'],
      ba: ['Makarone skuhati al dente i ocijediti.', 'Otopiti maslac, umiješati brašno, sa mlijekom prokuhati u glatki sos.', 'Umiješati sir dok se ne otopi, začiniti soli, biberom i muškatnim oraščićem.', 'Tjesteninu pomiješati sa sosom od sira.', 'Po želji zapeći u pećnici sa malo sira.'],
      en: ['Cook the macaroni al dente and drain.', 'Melt butter, stir in flour, boil with milk into a smooth sauce.', 'Stir in cheese until melted, season with salt, pepper and nutmeg.', 'Mix the pasta with the cheese sauce.', 'Optionally bake with a little cheese on top.']
    }
  },

  {
    id: 'chili_con_carne', kueche: 'amerikanisch', portionen: 5, dauer_min: 60,
    titel: { de: 'Chili con Carne', sr: 'Чили кон карне', hr: 'Chili con carne', ba: 'Chili con carne', en: 'Chili con carne' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Rinderhackfleisch', sr: 'јунеће млевено месо', hr: 'juneće mljeveno meso', ba: 'juneće mljeveno meso', en: 'ground beef' } },
      { menge: 400, einheit: 'g', name: { de: 'Kidneybohnen (Dose)', sr: 'црвени пасуљ (конзерва)', hr: 'crveni grah (konzerva)', ba: 'crveni grah (konzerva)', en: 'kidney beans (can)' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 1, einheit: 'tl', name: { de: 'Chilipulver', sr: 'чили у праху', hr: 'čili u prahu', ba: 'čili u prahu', en: 'chili powder' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Kreuzkümmel', sr: 'со, бибер, кумин', hr: 'sol, papar, kumin', ba: 'so, biber, kumin', en: 'salt, pepper, cumin' } }
    ],
    schritte: {
      de: ['Zwiebel und Paprika anschwitzen, Hackfleisch krümelig anbraten.', 'Chilipulver und Kreuzkümmel einrühren.', 'Tomaten und etwas Wasser zugeben, 30 Min. köcheln.', 'Bohnen zugeben und weitere 10 Min. garen.', 'Mit Salz und Pfeffer abschmecken, mit Reis oder Brot servieren.'],
      sr: ['Лук и паприку продинстати, месо пропржити да се раздвоји.', 'Умешати чили и кумин.', 'Додати парадајз и мало воде, кувати 30 минута.', 'Додати пасуљ и кувати још 10 минута.', 'Зачинити сољу и бибером, послужити са пиринчем или хлебом.'],
      hr: ['Luk i papriku popirjati, meso popržiti da se razdvoji.', 'Umiješati čili i kumin.', 'Dodati rajčice i malo vode, kuhati 30 minuta.', 'Dodati grah i kuhati još 10 minuta.', 'Začiniti soli i paprom, poslužiti s rižom ili kruhom.'],
      ba: ['Luk i papriku podinstati, meso popržiti da se razdvoji.', 'Umiješati čili i kumin.', 'Dodati paradajz i malo vode, kuhati 30 minuta.', 'Dodati grah i kuhati još 10 minuta.', 'Začiniti soli i biberom, poslužiti sa rižom ili hljebom.'],
      en: ['Sauté onion and pepper, brown the meat until crumbly.', 'Stir in chili powder and cumin.', 'Add tomatoes and a little water, simmer for 30 minutes.', 'Add the beans and cook for another 10 minutes.', 'Season with salt and pepper, serve with rice or bread.']
    }
  },

  {
    id: 'caesar_salad', kueche: 'amerikanisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Caesar Salad', sr: 'Цезар салата', hr: 'Cezar salata', ba: 'Cezar salata', en: 'Caesar salad' },
    zutaten: [
      { menge: 1, einheit: 'kopf', name: { de: 'Römersalat', sr: 'римска салата', hr: 'rimska salata', ba: 'rimska salata', en: 'romaine lettuce' } },
      { menge: 100, einheit: 'g', name: { de: 'Croûtons', sr: 'крутони', hr: 'krutoni', ba: 'krutoni', en: 'croutons' } },
      { menge: 50, einheit: 'g', name: { de: 'Parmesan', sr: 'пармезан', hr: 'parmezan', ba: 'parmezan', en: 'parmesan' } },
      { menge: 3, einheit: 'el', name: { de: 'Mayonnaise', sr: 'мајонез', hr: 'majoneza', ba: 'majoneza', en: 'mayonnaise' } },
      { menge: 1, einheit: 'zehe', name: { de: 'Knoblauchzehe', sr: 'чен белог лука', hr: 'češanj češnjaka', ba: 'čehno bijelog luka', en: 'garlic clove' } },
      { menge: 1, einheit: 'el', name: { de: 'Zitronensaft', sr: 'лимунов сок', hr: 'limunov sok', ba: 'limunov sok', en: 'lemon juice' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Salat waschen und in mundgerechte Stücke zupfen.', 'Für das Dressing Mayonnaise, Knoblauch, Zitronensaft, Salz und Pfeffer verrühren.', 'Salat mit dem Dressing vermengen.', 'Croûtons und geriebenen Parmesan darüberstreuen.', 'Sofort servieren.'],
      sr: ['Салату опрати и покидати на залогаје.', 'За прелив умешати мајонез, бели лук, лимунов сок, со и бибер.', 'Салату помешати са преливом.', 'Посути крутоне и рендани пармезан.', 'Одмах послужити.'],
      hr: ['Salatu oprati i potrgati na zalogaje.', 'Za preljev umiješati majonezu, češnjak, limunov sok, sol i papar.', 'Salatu pomiješati s preljevom.', 'Posuti krutone i naribani parmezan.', 'Odmah poslužiti.'],
      ba: ['Salatu oprati i potrgati na zalogaje.', 'Za preljev umiješati majonezu, bijeli luk, limunov sok, so i biber.', 'Salatu pomiješati sa preljevom.', 'Posuti krutone i naribani parmezan.', 'Odmah poslužiti.'],
      en: ['Wash the lettuce and tear into bite-sized pieces.', 'For the dressing, mix mayonnaise, garlic, lemon juice, salt and pepper.', 'Toss the lettuce with the dressing.', 'Sprinkle with croutons and grated parmesan.', 'Serve immediately.']
    }
  },

  {
    id: 'bbq_ribs', kueche: 'amerikanisch', portionen: 4, dauer_min: 180,
    titel: { de: 'BBQ-Spareribs', sr: 'BBQ ребарца', hr: 'BBQ rebrca', ba: 'BBQ rebra', en: 'BBQ spare ribs' },
    zutaten: [
      { menge: 1.5, einheit: 'kg', name: { de: 'Schweinerippchen', sr: 'свињска ребарца', hr: 'svinjska rebrca', ba: 'svinjska rebra', en: 'pork ribs' } },
      { menge: 150, einheit: 'ml', name: { de: 'BBQ-Sauce', sr: 'BBQ сос', hr: 'BBQ umak', ba: 'BBQ sos', en: 'BBQ sauce' } },
      { menge: 2, einheit: 'el', name: { de: 'brauner Zucker', sr: 'смеђи шећер', hr: 'smeđi šećer', ba: 'smeđi šećer', en: 'brown sugar' } },
      { menge: 1, einheit: 'tl', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } }
    ],
    schritte: {
      de: ['Rippchen mit Zucker, Paprika, Knoblauch, Salz und Pfeffer einreiben.', 'In Folie wickeln und im Ofen bei 150 Grad ca. 2,5 Stunden garen.', 'Folie öffnen und mit BBQ-Sauce bestreichen.', 'Ohne Folie bei 200 Grad 15–20 Min. glasieren.', 'Vor dem Schneiden kurz ruhen lassen.'],
      sr: ['Ребарца утрљати шећером, паприком, белим луком, сољу и бибером.', 'Умотати у фолију и пећи у рерни на 150 степени око 2,5 сата.', 'Отворити фолију и премазати BBQ сосом.', 'Без фолије на 200 степени 15–20 минута глазирати.', 'Оставити да одстоји пре сечења.'],
      hr: ['Rebrca utrljati šećerom, paprikom, češnjakom, soli i paprom.', 'Umotati u foliju i peći u pećnici na 150 stupnjeva oko 2,5 sata.', 'Otvoriti foliju i premazati BBQ umakom.', 'Bez folije na 200 stupnjeva 15–20 minuta glazirati.', 'Ostaviti da odstoji prije rezanja.'],
      ba: ['Rebra utrljati šećerom, paprikom, bijelim lukom, soli i biberom.', 'Umotati u foliju i peći u pećnici na 150 stepeni oko 2,5 sata.', 'Otvoriti foliju i premazati BBQ sosom.', 'Bez folije na 200 stepeni 15–20 minuta glazirati.', 'Ostaviti da odstoji prije rezanja.'],
      en: ['Rub the ribs with sugar, paprika, garlic, salt and pepper.', 'Wrap in foil and cook in the oven at 150 degrees for about 2.5 hours.', 'Open the foil and brush with BBQ sauce.', 'Glaze without foil at 200 degrees for 15–20 minutes.', 'Let rest briefly before cutting.']
    }
  },

  {
    id: 'cheesecake', kueche: 'amerikanisch', portionen: 8, dauer_min: 90,
    titel: { de: 'New York Cheesecake', sr: 'Њујоршки чизкејк', hr: 'New York cheesecake', ba: 'New York cheesecake', en: 'New York cheesecake' },
    zutaten: [
      { menge: 200, einheit: 'g', name: { de: 'Butterkekse', sr: 'кекс', hr: 'keksi', ba: 'keksi', en: 'digestive biscuits' } },
      { menge: 80, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: 600, einheit: 'g', name: { de: 'Frischkäse', sr: 'крем сир', hr: 'krem sir', ba: 'krem sir', en: 'cream cheese' } },
      { menge: 150, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 200, einheit: 'g', name: { de: 'saure Sahne', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'sour cream' } },
      { menge: 1, einheit: 'tl', name: { de: 'Vanille', sr: 'ванила', hr: 'vanilija', ba: 'vanilija', en: 'vanilla' } }
    ],
    schritte: {
      de: ['Kekse fein zerbröseln, mit geschmolzener Butter mischen und in eine Form drücken.', 'Frischkäse mit Zucker und Vanille glatt rühren.', 'Eier einzeln unterrühren, dann saure Sahne einarbeiten.', 'Masse auf den Boden gießen.', 'Bei 160 Grad ca. 55 Min. backen, im Ofen auskühlen lassen und kalt stellen.'],
      sr: ['Кекс ситно измрвити, помешати са отопљеним путером и утиснути у калуп.', 'Крем сир умутити са шећером и ванилом.', 'Јаја додавати једно по једно, затим умешати павлаку.', 'Масу сипати на кору.', 'Пећи на 160 степени око 55 минута, охладити у рерни и ставити у фрижидер.'],
      hr: ['Kekse sitno izmrviti, pomiješati s otopljenim maslacem i utisnuti u kalup.', 'Krem sir umutiti sa šećerom i vanilijom.', 'Jaja dodavati jedno po jedno, zatim umiješati vrhnje.', 'Masu uliti na podlogu.', 'Peći na 160 stupnjeva oko 55 minuta, ohladiti u pećnici i staviti u hladnjak.'],
      ba: ['Kekse sitno izmrviti, pomiješati sa otopljenim maslacem i utisnuti u kalup.', 'Krem sir umutiti sa šećerom i vanilijom.', 'Jaja dodavati jedno po jedno, zatim umiješati pavlaku.', 'Masu uliti na podlogu.', 'Peći na 160 stepeni oko 55 minuta, ohladiti u pećnici i staviti u frižider.'],
      en: ['Finely crush the biscuits, mix with melted butter and press into a tin.', 'Beat the cream cheese with sugar and vanilla until smooth.', 'Stir in the eggs one at a time, then work in the sour cream.', 'Pour the mixture onto the base.', 'Bake at 160 degrees for about 55 minutes, cool in the oven and chill.']
    }
  },

  {
    id: 'fried_chicken', kueche: 'amerikanisch', portionen: 4, dauer_min: 45,
    titel: { de: 'Southern Fried Chicken', sr: 'Пржена пилетина', hr: 'Pohana piletina', ba: 'Pržena piletina', en: 'Southern fried chicken' },
    zutaten: [
      { menge: 8, einheit: 'stk', name: { de: 'Hähnchenteile', sr: 'пилећи делови', hr: 'pileći dijelovi', ba: 'pileći dijelovi', en: 'chicken pieces' } },
      { menge: 300, einheit: 'ml', name: { de: 'Buttermilch', sr: 'млаћеница', hr: 'mlaćenica', ba: 'mlaćenica', en: 'buttermilk' } },
      { menge: 250, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 1, einheit: 'tl', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: 1, einheit: 'tl', name: { de: 'Knoblauchpulver', sr: 'бели лук у праху', hr: 'češnjak u prahu', ba: 'bijeli luk u prahu', en: 'garlic powder' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl zum Frittieren', sr: 'со, бибер, уље за пржење', hr: 'sol, papar, ulje za prženje', ba: 'so, biber, ulje za prženje', en: 'salt, pepper, oil for frying' } }
    ],
    schritte: {
      de: ['Hähnchen mind. 2 Std. in gesalzener Buttermilch marinieren.', 'Mehl mit Paprika, Knoblauchpulver, Salz und Pfeffer mischen.', 'Hähnchen aus der Buttermilch nehmen und im Mehl wenden.', 'In heißem Öl (170 Grad) ca. 12–15 Min. goldbraun frittieren.', 'Auf einem Gitter abtropfen lassen.'],
      sr: ['Пилетину маринирати најмање 2 сата у сланој млаћеници.', 'Брашно помешати са паприком, белим луком у праху, сољу и бибером.', 'Пилетину извадити из млаћенице и уваљати у брашно.', 'У врелом уљу (170 степени) пржити 12–15 минута до златне боје.', 'Оцедити на решетки.'],
      hr: ['Piletinu marinirati najmanje 2 sata u slanoj mlaćenici.', 'Brašno pomiješati s paprikom, češnjakom u prahu, soli i paprom.', 'Piletinu izvaditi iz mlaćenice i uvaljati u brašno.', 'U vrućem ulju (170 stupnjeva) pržiti 12–15 minuta do zlatne boje.', 'Ocijediti na rešetki.'],
      ba: ['Piletinu marinirati najmanje 2 sata u slanoj mlaćenici.', 'Brašno pomiješati sa paprikom, bijelim lukom u prahu, soli i biberom.', 'Piletinu izvaditi iz mlaćenice i uvaljati u brašno.', 'U vrućem ulju (170 stepeni) pržiti 12–15 minuta do zlatne boje.', 'Ocijediti na rešetki.'],
      en: ['Marinate the chicken for at least 2 hours in salted buttermilk.', 'Mix flour with paprika, garlic powder, salt and pepper.', 'Remove the chicken from the buttermilk and coat in flour.', 'Deep-fry in hot oil (170 degrees) for 12–15 minutes until golden.', 'Drain on a rack.']
    }
  },

  // ---- MEXIKANISCH ---------------------------------------------------------
  {
    id: 'tacos', kueche: 'mexikanisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Tacos mit Hackfleisch', sr: 'Такоси са месом', hr: 'Tacosi s mesom', ba: 'Tacosi sa mesom', en: 'Beef tacos' },
    zutaten: [
      { menge: 8, einheit: 'stk', name: { de: 'Taco-Schalen', sr: 'тако корице', hr: 'taco korice', ba: 'taco korice', en: 'taco shells' } },
      { menge: 500, einheit: 'g', name: { de: 'Rinderhackfleisch', sr: 'јунеће млевено месо', hr: 'juneće mljeveno meso', ba: 'juneće mljeveno meso', en: 'ground beef' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kreuzkümmel', sr: 'кумин', hr: 'kumin', ba: 'kumin', en: 'cumin' } },
      { menge: 150, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: 100, einheit: 'g', name: { de: 'Salat und Tomaten', sr: 'салата и парадајз', hr: 'salata i rajčice', ba: 'salata i paradajz', en: 'lettuce and tomatoes' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Chili', sr: 'со, бибер, чили', hr: 'sol, papar, čili', ba: 'so, biber, čili', en: 'salt, pepper, chili' } }
    ],
    schritte: {
      de: ['Zwiebel anschwitzen, Hackfleisch anbraten.', 'Mit Kreuzkümmel, Chili, Salz und Pfeffer würzen.', 'Taco-Schalen kurz im Ofen erwärmen.', 'Mit Hackfleisch, Käse, Salat und Tomaten füllen.', 'Nach Wunsch mit Salsa servieren.'],
      sr: ['Лук продинстати, месо пропржити.', 'Зачинити кумином, чилијем, сољу и бибером.', 'Тако корице кратко загрејати у рерни.', 'Напунити месом, сиром, салатом и парадајзом.', 'По жељи послужити са салсом.'],
      hr: ['Luk popirjati, meso popržiti.', 'Začiniti kuminom, čilijem, soli i paprom.', 'Taco korice kratko zagrijati u pećnici.', 'Napuniti mesom, sirom, salatom i rajčicama.', 'Po želji poslužiti sa salsom.'],
      ba: ['Luk podinstati, meso popržiti.', 'Začiniti kuminom, čilijem, soli i biberom.', 'Taco korice kratko zagrijati u pećnici.', 'Napuniti mesom, sirom, salatom i paradajzom.', 'Po želji poslužiti sa salsom.'],
      en: ['Sauté the onion, brown the meat.', 'Season with cumin, chili, salt and pepper.', 'Warm the taco shells briefly in the oven.', 'Fill with meat, cheese, lettuce and tomatoes.', 'Serve with salsa if you like.']
    }
  },

  {
    id: 'guacamole', kueche: 'mexikanisch', portionen: 4, dauer_min: 15,
    titel: { de: 'Guacamole', sr: 'Гуакамоле', hr: 'Guacamole', ba: 'Guacamole', en: 'Guacamole' },
    zutaten: [
      { menge: 3, einheit: 'stk', name: { de: 'reife Avocados', sr: 'зреле авокадо', hr: 'zreli avokado', ba: 'zreli avokado', en: 'ripe avocados' } },
      { menge: 1, einheit: 'stk', name: { de: 'Tomate', sr: 'парадајз', hr: 'rajčica', ba: 'paradajz', en: 'tomato' } },
      { menge: 0.5, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'stk', name: { de: 'Limette (Saft)', sr: 'лимета (сок)', hr: 'limeta (sok)', ba: 'limeta (sok)', en: 'lime (juice)' } },
      { menge: 1, einheit: 'zehe', name: { de: 'Knoblauchzehe', sr: 'чен белог лука', hr: 'češanj češnjaka', ba: 'čehno bijelog luka', en: 'garlic clove' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Koriander', sr: 'со, коријандер', hr: 'sol, korijandar', ba: 'so, korijander', en: 'salt, coriander' } }
    ],
    schritte: {
      de: ['Avocados halbieren, entkernen und das Fruchtfleisch zerdrücken.', 'Tomate, Zwiebel und Knoblauch fein würfeln und untermischen.', 'Limettensaft zugeben, damit es nicht braun wird.', 'Mit Salz und Koriander abschmecken.', 'Mit Tortilla-Chips servieren.'],
      sr: ['Авокадо преполовити, извадити коштицу и изгњечити месо.', 'Парадајз, лук и бели лук ситно исецкати и умешати.', 'Додати сок лимете да не потамни.', 'Зачинити сољу и коријандером.', 'Послужити са тортиља чипсом.'],
      hr: ['Avokado prepoloviti, izvaditi košticu i zgnječiti meso.', 'Rajčicu, luk i češnjak sitno nasjeckati i umiješati.', 'Dodati sok limete da ne potamni.', 'Začiniti soli i korijandrom.', 'Poslužiti s tortilja čipsom.'],
      ba: ['Avokado prepoloviti, izvaditi košticu i zgnječiti meso.', 'Paradajz, luk i bijeli luk sitno nasjeckati i umiješati.', 'Dodati sok limete da ne potamni.', 'Začiniti soli i korijanderom.', 'Poslužiti sa tortilja čipsom.'],
      en: ['Halve the avocados, remove the stone and mash the flesh.', 'Finely dice tomato, onion and garlic and mix in.', 'Add lime juice to keep it from browning.', 'Season with salt and coriander.', 'Serve with tortilla chips.']
    }
  },

  {
    id: 'quesadilla', kueche: 'mexikanisch', portionen: 2, dauer_min: 20,
    titel: { de: 'Quesadilla', sr: 'Кесадиља', hr: 'Quesadilla', ba: 'Quesadilla', en: 'Quesadilla' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Weizentortillas', sr: 'пшеничне тортиље', hr: 'pšenične tortilje', ba: 'pšenične tortilje', en: 'wheat tortillas' } },
      { menge: 200, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 150, einheit: 'g', name: { de: 'Hähnchen (gegart)', sr: 'пилетина (кувана)', hr: 'piletina (kuhana)', ba: 'piletina (kuhana)', en: 'chicken (cooked)' } },
      { menge: 2, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Paprika und Frühlingszwiebeln klein schneiden.', 'Eine Tortilla in die Pfanne legen, mit Käse, Gemüse und Hähnchen belegen.', 'Mit einer zweiten Tortilla bedecken.', 'Von beiden Seiten goldbraun braten, bis der Käse schmilzt.', 'In Stücke schneiden und servieren.'],
      sr: ['Паприку и млади лук ситно исећи.', 'Тортиљу ставити у тигањ, поређати сир, поврће и пилетину.', 'Прекрити другом тортиљом.', 'Пржити са обе стране до златне боје док се сир не отопи.', 'Исећи на комаде и послужити.'],
      hr: ['Papriku i mladi luk sitno narezati.', 'Tortilju staviti u tavu, posložiti sir, povrće i piletinu.', 'Prekriti drugom tortiljom.', 'Pržiti s obje strane do zlatne boje dok se sir ne otopi.', 'Narezati na komade i poslužiti.'],
      ba: ['Papriku i mladi luk sitno narezati.', 'Tortilju staviti u tavu, posložiti sir, povrće i piletinu.', 'Prekriti drugom tortiljom.', 'Pržiti sa obje strane do zlatne boje dok se sir ne otopi.', 'Narezati na komade i poslužiti.'],
      en: ['Finely cut the pepper and spring onions.', 'Place a tortilla in the pan, top with cheese, vegetables and chicken.', 'Cover with a second tortilla.', 'Fry on both sides until golden and the cheese melts.', 'Cut into pieces and serve.']
    }
  },

  {
    id: 'burrito', kueche: 'mexikanisch', portionen: 4, dauer_min: 35,
    titel: { de: 'Burrito', sr: 'Бурито', hr: 'Burrito', ba: 'Burrito', en: 'Burrito' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'große Tortillas', sr: 'велике тортиље', hr: 'velike tortilje', ba: 'velike tortilje', en: 'large tortillas' } },
      { menge: 200, einheit: 'g', name: { de: 'Reis (gekocht)', sr: 'пиринач (кувани)', hr: 'riža (kuhana)', ba: 'riža (kuhana)', en: 'rice (cooked)' } },
      { menge: 400, einheit: 'g', name: { de: 'Kidneybohnen', sr: 'црвени пасуљ', hr: 'crveni grah', ba: 'crveni grah', en: 'kidney beans' } },
      { menge: 400, einheit: 'g', name: { de: 'Hähnchen oder Hackfleisch', sr: 'пилетина или млевено месо', hr: 'piletina ili mljeveno meso', ba: 'piletina ili mljeveno meso', en: 'chicken or ground meat' } },
      { menge: 150, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Chili', sr: 'со, бибер, чили', hr: 'sol, papar, čili', ba: 'so, biber, čili', en: 'salt, pepper, chili' } }
    ],
    schritte: {
      de: ['Fleisch würzen und anbraten, Bohnen erwärmen.', 'Tortillas kurz aufwärmen.', 'Reis, Bohnen, Fleisch und Käse in die Mitte geben.', 'Seiten einschlagen und fest aufrollen.', 'In der Pfanne kurz von beiden Seiten anrösten.'],
      sr: ['Месо зачинити и пропржити, пасуљ загрејати.', 'Тортиље кратко загрејати.', 'У средину ставити пиринач, пасуљ, месо и сир.', 'Преклопити стране и чврсто уролати.', 'У тигању кратко пропржити са обе стране.'],
      hr: ['Meso začiniti i popržiti, grah zagrijati.', 'Tortilje kratko zagrijati.', 'U sredinu staviti rižu, grah, meso i sir.', 'Preklopiti strane i čvrsto zamotati.', 'U tavi kratko popržiti s obje strane.'],
      ba: ['Meso začiniti i popržiti, grah zagrijati.', 'Tortilje kratko zagrijati.', 'U sredinu staviti rižu, grah, meso i sir.', 'Preklopiti strane i čvrsto zamotati.', 'U tavi kratko popržiti sa obje strane.'],
      en: ['Season and brown the meat, warm the beans.', 'Warm the tortillas briefly.', 'Place rice, beans, meat and cheese in the middle.', 'Fold in the sides and roll up tightly.', 'Toast briefly on both sides in the pan.']
    }
  },

  {
    id: 'fajitas', kueche: 'mexikanisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Chicken Fajitas', sr: 'Пилеће фахитас', hr: 'Pileći fajitas', ba: 'Pileći fajitas', en: 'Chicken fajitas' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Hähnchenbrust', sr: 'пилеће бело месо', hr: 'pileća prsa', ba: 'pileća prsa', en: 'chicken breast' } },
      { menge: 2, einheit: 'stk', name: { de: 'Paprika (bunt)', sr: 'паприке (шарене)', hr: 'paprike (šarene)', ba: 'paprike (šarene)', en: 'peppers (mixed)' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 8, einheit: 'stk', name: { de: 'Tortillas', sr: 'тортиље', hr: 'tortilje', ba: 'tortilje', en: 'tortillas' } },
      { menge: 1, einheit: 'tl', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: 1, einheit: 'stk', name: { de: 'Limette', sr: 'лимета', hr: 'limeta', ba: 'limeta', en: 'lime' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Hähnchen in Streifen schneiden und würzen.', 'Im heißen Öl kräftig anbraten und herausnehmen.', 'Paprika- und Zwiebelstreifen scharf anbraten.', 'Hähnchen zurückgeben, mit Limettensaft ablöschen.', 'In warmen Tortillas servieren.'],
      sr: ['Пилетину исећи на траке и зачинити.', 'На врелом уљу јако пропржити и извадити.', 'Траке паприке и лука јако пропржити.', 'Вратити пилетину, залити соком лимете.', 'Послужити у топлим тортиљама.'],
      hr: ['Piletinu narezati na trake i začiniti.', 'Na vrućem ulju jako popržiti i izvaditi.', 'Trake paprike i luka jako popržiti.', 'Vratiti piletinu, zaliti sokom limete.', 'Poslužiti u toplim tortiljama.'],
      ba: ['Piletinu narezati na trake i začiniti.', 'Na vrućem ulju jako popržiti i izvaditi.', 'Trake paprike i luka jako popržiti.', 'Vratiti piletinu, zaliti sokom limete.', 'Poslužiti u toplim tortiljama.'],
      en: ['Cut the chicken into strips and season.', 'Sear in hot oil and remove.', 'Fry the pepper and onion strips over high heat.', 'Return the chicken, deglaze with lime juice.', 'Serve in warm tortillas.']
    }
  },

  {
    id: 'salsa', kueche: 'mexikanisch', portionen: 6, dauer_min: 15,
    titel: { de: 'Salsa (Tomaten-Dip)', sr: 'Салса (дип од парадајза)', hr: 'Salsa (umak od rajčice)', ba: 'Salsa (umak od paradajza)', en: 'Salsa (tomato dip)' },
    zutaten: [
      { menge: 5, einheit: 'stk', name: { de: 'reife Tomaten', sr: 'зрели парадајз', hr: 'zrele rajčice', ba: 'zreli paradajz', en: 'ripe tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'stk', name: { de: 'Chilischote', sr: 'љута папричица', hr: 'ljuta papričica', ba: 'ljuta papričica', en: 'chili pepper' } },
      { menge: 1, einheit: 'stk', name: { de: 'Limette (Saft)', sr: 'лимета (сок)', hr: 'limeta (sok)', ba: 'limeta (sok)', en: 'lime (juice)' } },
      { menge: 1, einheit: 'bund', name: { de: 'Koriander', sr: 'коријандер', hr: 'korijandar', ba: 'korijander', en: 'coriander' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Tomaten, Zwiebel und Chili sehr fein würfeln.', 'Koriander hacken und zugeben.', 'Mit Limettensaft und Salz mischen.', 'Kurz durchziehen lassen.', 'Mit Tortilla-Chips servieren.'],
      sr: ['Парадајз, лук и чили врло ситно исецкати.', 'Коријандер исецкати и додати.', 'Помешати са соком лимете и сољу.', 'Оставити кратко да одстоји.', 'Послужити са тортиља чипсом.'],
      hr: ['Rajčice, luk i čili vrlo sitno nasjeckati.', 'Korijandar nasjeckati i dodati.', 'Pomiješati sa sokom limete i soli.', 'Ostaviti kratko da odstoji.', 'Poslužiti s tortilja čipsom.'],
      ba: ['Paradajz, luk i čili vrlo sitno nasjeckati.', 'Korijander nasjeckati i dodati.', 'Pomiješati sa sokom limete i soli.', 'Ostaviti kratko da odstoji.', 'Poslužiti sa tortilja čipsom.'],
      en: ['Very finely dice the tomatoes, onion and chili.', 'Chop the coriander and add.', 'Mix with lime juice and salt.', 'Let it sit briefly.', 'Serve with tortilla chips.']
    }
  },

  {
    id: 'enchiladas', kueche: 'mexikanisch', portionen: 4, dauer_min: 50,
    titel: { de: 'Enchiladas', sr: 'Енчиладе', hr: 'Enchilade', ba: 'Enchilade', en: 'Enchiladas' },
    zutaten: [
      { menge: 8, einheit: 'stk', name: { de: 'Maistortillas', sr: 'кукурузне тортиље', hr: 'kukuruzne tortilje', ba: 'kukuruzne tortilje', en: 'corn tortillas' } },
      { menge: 400, einheit: 'g', name: { de: 'Hähnchen (gegart, zerpflückt)', sr: 'пилетина (кувана, ишчупана)', hr: 'piletina (kuhana, natrgana)', ba: 'piletina (kuhana, natrgana)', en: 'chicken (cooked, shredded)' } },
      { menge: 400, einheit: 'g', name: { de: 'Tomatensauce', sr: 'сос од парадајза', hr: 'umak od rajčice', ba: 'sos od paradajza', en: 'tomato sauce' } },
      { menge: 1, einheit: 'tl', name: { de: 'Chilipulver', sr: 'чили у праху', hr: 'čili u prahu', ba: 'čili u prahu', en: 'chili powder' } },
      { menge: 200, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Tomatensauce mit Chili, Salz und Pfeffer würzen.', 'Hähnchen mit etwas Sauce mischen.', 'Tortillas füllen, aufrollen und in eine Form legen.', 'Restliche Sauce darübergeben und mit Käse bestreuen.', 'Bei 190 Grad ca. 20 Min. überbacken.'],
      sr: ['Сос од парадајза зачинити чилијем, сољу и бибером.', 'Пилетину помешати са мало соса.', 'Тортиље напунити, уролати и ставити у посуду.', 'Прелити преосталим сосом и посути сиром.', 'Запећи на 190 степени око 20 минута.'],
      hr: ['Umak od rajčice začiniti čilijem, soli i paprom.', 'Piletinu pomiješati s malo umaka.', 'Tortilje napuniti, zamotati i staviti u posudu.', 'Preliti preostalim umakom i posuti sirom.', 'Zapeći na 190 stupnjeva oko 20 minuta.'],
      ba: ['Sos od paradajza začiniti čilijem, soli i biberom.', 'Piletinu pomiješati sa malo sosa.', 'Tortilje napuniti, zamotati i staviti u posudu.', 'Preliti preostalim sosom i posuti sirom.', 'Zapeći na 190 stepeni oko 20 minuta.'],
      en: ['Season the tomato sauce with chili, salt and pepper.', 'Mix the chicken with a little sauce.', 'Fill the tortillas, roll up and place in a dish.', 'Pour over the remaining sauce and sprinkle with cheese.', 'Bake at 190 degrees for about 20 minutes.']
    }
  },

  // ---- GRIECHISCH ----------------------------------------------------------
  {
    id: 'gyros', kueche: 'griechisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Gyros mit Tzatziki', sr: 'Ђирос са цацикијем', hr: 'Gyros s tzatzikijem', ba: 'Gyros sa tzatzikijem', en: 'Gyros with tzatziki' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Schweinefleisch (Streifen)', sr: 'свињетина (траке)', hr: 'svinjetina (trake)', ba: 'svinjetina (trake)', en: 'pork (strips)' } },
      { menge: 2, einheit: 'el', name: { de: 'Gyrosgewürz', sr: 'зачин за ђирос', hr: 'začin za gyros', ba: 'začin za gyros', en: 'gyros seasoning' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 4, einheit: 'stk', name: { de: 'Pita-Brote', sr: 'пита хлеб', hr: 'pita kruh', ba: 'pita hljeb', en: 'pita breads' } },
      { menge: 200, einheit: 'g', name: { de: 'Tzatziki', sr: 'цацики', hr: 'tzatziki', ba: 'tzatziki', en: 'tzatziki' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Olivenöl', sr: 'со, бибер, маслиново уље', hr: 'sol, papar, maslinovo ulje', ba: 'so, biber, maslinovo ulje', en: 'salt, pepper, olive oil' } }
    ],
    schritte: {
      de: ['Fleisch mit Gewürz, Knoblauch und Öl mind. 1 Std. marinieren.', 'In einer heißen Pfanne kräftig und knusprig anbraten.', 'Pita-Brote kurz erwärmen.', 'Mit Fleisch, Zwiebeln und Tzatziki füllen.', 'Mit Salat nach Wunsch servieren.'],
      sr: ['Месо маринирати са зачином, белим луком и уљем најмање 1 сат.', 'У врелом тигању јако и хрскаво пропржити.', 'Пита хлеб кратко загрејати.', 'Напунити месом, луком и цацикијем.', 'Послужити са салатом по жељи.'],
      hr: ['Meso marinirati sa začinom, češnjakom i uljem najmanje 1 sat.', 'U vrućoj tavi jako i hrskavo popržiti.', 'Pita kruh kratko zagrijati.', 'Napuniti mesom, lukom i tzatzikijem.', 'Poslužiti sa salatom po želji.'],
      ba: ['Meso marinirati sa začinom, bijelim lukom i uljem najmanje 1 sat.', 'U vrućoj tavi jako i hrskavo popržiti.', 'Pita hljeb kratko zagrijati.', 'Napuniti mesom, lukom i tzatzikijem.', 'Poslužiti sa salatom po želji.'],
      en: ['Marinate the meat with seasoning, garlic and oil for at least 1 hour.', 'Sear until crisp in a hot pan.', 'Warm the pita breads briefly.', 'Fill with meat, onions and tzatziki.', 'Serve with salad as desired.']
    }
  },

  {
    id: 'tzatziki', kueche: 'griechisch', portionen: 6, dauer_min: 15,
    titel: { de: 'Tzatziki', sr: 'Цацики', hr: 'Tzatziki', ba: 'Tzatziki', en: 'Tzatziki' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'griechischer Joghurt', sr: 'грчки јогурт', hr: 'grčki jogurt', ba: 'grčki jogurt', en: 'greek yogurt' } },
      { menge: 1, einheit: 'stk', name: { de: 'Salatgurke', sr: 'краставац', hr: 'krastavac', ba: 'krastavac', en: 'cucumber' } },
      { menge: 3, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 2, einheit: 'el', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: 1, einheit: 'el', name: { de: 'Weißweinessig', sr: 'винско сирће', hr: 'vinski ocat', ba: 'vinsko sirće', en: 'white wine vinegar' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Gurke reiben, salzen und gut ausdrücken.', 'Knoblauch fein zerdrücken.', 'Joghurt mit Gurke, Knoblauch, Öl und Essig verrühren.', 'Mit Salz abschmecken.', 'Vor dem Servieren kühlen.'],
      sr: ['Краставац изрендати, посолити и добро исцедити.', 'Бели лук ситно изгњечити.', 'Јогурт умешати са краставцем, белим луком, уљем и сирћетом.', 'Зачинити сољу.', 'Охладити пре сервирања.'],
      hr: ['Krastavac naribati, posoliti i dobro ocijediti.', 'Češnjak sitno zgnječiti.', 'Jogurt umiješati s krastavcem, češnjakom, uljem i octom.', 'Začiniti soli.', 'Ohladiti prije posluživanja.'],
      ba: ['Krastavac naribati, posoliti i dobro ocijediti.', 'Bijeli luk sitno zgnječiti.', 'Jogurt umiješati sa krastavcem, bijelim lukom, uljem i sirćetom.', 'Začiniti soli.', 'Ohladiti prije posluživanja.'],
      en: ['Grate the cucumber, salt and squeeze out well.', 'Finely crush the garlic.', 'Mix the yogurt with cucumber, garlic, oil and vinegar.', 'Season with salt.', 'Chill before serving.']
    }
  },

  {
    id: 'griechischer_salat', kueche: 'griechisch', portionen: 4, dauer_min: 15,
    titel: { de: 'Griechischer Salat', sr: 'Грчка салата', hr: 'Grčka salata', ba: 'Grčka salata', en: 'Greek salad' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Salatgurke', sr: 'краставац', hr: 'krastavac', ba: 'krastavac', en: 'cucumber' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 1, einheit: 'stk', name: { de: 'rote Zwiebel', sr: 'црвени лук', hr: 'crveni luk', ba: 'crveni luk', en: 'red onion' } },
      { menge: 200, einheit: 'g', name: { de: 'Feta', sr: 'фета сир', hr: 'feta sir', ba: 'feta sir', en: 'feta' } },
      { menge: 50, einheit: 'g', name: { de: 'schwarze Oliven', sr: 'црне маслине', hr: 'crne masline', ba: 'crne masline', en: 'black olives' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Oregano, Salz', sr: 'маслиново уље, оригано, со', hr: 'maslinovo ulje, origano, sol', ba: 'maslinovo ulje, origano, so', en: 'olive oil, oregano, salt' } }
    ],
    schritte: {
      de: ['Tomaten, Gurke und Paprika in grobe Stücke schneiden.', 'Zwiebel in Ringe schneiden.', 'Alles in eine Schüssel geben, Oliven zufügen.', 'Feta in einem Stück darauflegen.', 'Mit Olivenöl, Oregano und Salz beträufeln.'],
      sr: ['Парадајз, краставац и паприку исећи на крупне комаде.', 'Лук исећи на колутове.', 'Све ставити у чинију, додати маслине.', 'Фету ставити у комаду одозго.', 'Прелити маслиновим уљем, ориганом и сољу.'],
      hr: ['Rajčice, krastavac i papriku narezati na krupne komade.', 'Luk narezati na kolutove.', 'Sve staviti u zdjelu, dodati masline.', 'Fetu staviti u komadu odozgo.', 'Preliti maslinovim uljem, origanom i soli.'],
      ba: ['Paradajz, krastavac i papriku narezati na krupne komade.', 'Luk narezati na kolutove.', 'Sve staviti u zdjelu, dodati masline.', 'Fetu staviti u komadu odozgo.', 'Preliti maslinovim uljem, origanom i soli.'],
      en: ['Cut tomatoes, cucumber and pepper into rough pieces.', 'Slice the onion into rings.', 'Put everything in a bowl, add olives.', 'Place the feta on top in one piece.', 'Drizzle with olive oil, oregano and salt.']
    }
  },

  {
    id: 'souvlaki', kueche: 'griechisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Souvlaki (Fleischspieße)', sr: 'Сувлаки (ражњићи)', hr: 'Souvlaki (ražnjići)', ba: 'Souvlaki (ražnjići)', en: 'Souvlaki (skewers)' },
    zutaten: [
      { menge: 700, einheit: 'g', name: { de: 'Schweine- oder Hähnchenfleisch', sr: 'свињетина или пилетина', hr: 'svinjetina ili piletina', ba: 'svinjetina ili piletina', en: 'pork or chicken' } },
      { menge: 3, einheit: 'el', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone (Saft)', sr: 'лимун (сок)', hr: 'limun (sok)', ba: 'limun (sok)', en: 'lemon (juice)' } },
      { menge: 3, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'tl', name: { de: 'Oregano', sr: 'оригано', hr: 'origano', ba: 'origano', en: 'oregano' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz und Pfeffer', sr: 'со и бибер', hr: 'sol i papar', ba: 'so i biber', en: 'salt and pepper' } }
    ],
    schritte: {
      de: ['Fleisch würfeln und mit Öl, Zitronensaft, Knoblauch und Oregano marinieren.', 'Mind. 1 Std. ziehen lassen.', 'Fleisch auf Spieße stecken.', 'Auf dem Grill oder in der Pfanne rundum garen.', 'Mit Pita, Zitrone und Tzatziki servieren.'],
      sr: ['Месо исећи на коцке и маринирати са уљем, соком лимуна, белим луком и ориганом.', 'Оставити најмање 1 сат.', 'Месо нанизати на ражњиће.', 'На роштиљу или у тигању испећи са свих страна.', 'Послужити са питом, лимуном и цацикијем.'],
      hr: ['Meso narezati na kocke i marinirati s uljem, sokom limuna, češnjakom i origanom.', 'Ostaviti najmanje 1 sat.', 'Meso nanizati na ražnjiće.', 'Na roštilju ili u tavi ispeći sa svih strana.', 'Poslužiti s pitom, limunom i tzatzikijem.'],
      ba: ['Meso narezati na kocke i marinirati sa uljem, sokom limuna, bijelim lukom i origanom.', 'Ostaviti najmanje 1 sat.', 'Meso nanizati na ražnjiće.', 'Na roštilju ili u tavi ispeći sa svih strana.', 'Poslužiti sa pitom, limunom i tzatzikijem.'],
      en: ['Cube the meat and marinate with oil, lemon juice, garlic and oregano.', 'Let it rest for at least 1 hour.', 'Thread the meat onto skewers.', 'Cook on the grill or in a pan all over.', 'Serve with pita, lemon and tzatziki.']
    }
  },

  {
    id: 'spanakopita', kueche: 'griechisch', portionen: 6, dauer_min: 70,
    titel: { de: 'Spanakopita (Spinat-Feta-Pite)', sr: 'Спанакопита (пита са спанаћем)', hr: 'Spanakopita (pita sa špinatom)', ba: 'Spanakopita (pita sa špinatom)', en: 'Spanakopita (spinach & feta pie)' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Blattspinat', sr: 'спанаћ', hr: 'špinat', ba: 'špinat', en: 'spinach' } },
      { menge: 250, einheit: 'g', name: { de: 'Feta', sr: 'фета сир', hr: 'feta sir', ba: 'feta sir', en: 'feta' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 250, einheit: 'g', name: { de: 'Filoteig', sr: 'коре за питу', hr: 'kore za pitu', ba: 'jufke', en: 'filo pastry' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 80, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Zwiebel anschwitzen, Spinat zugeben und zusammenfallen lassen.', 'Abkühlen lassen, mit zerbröseltem Feta und Eiern mischen, würzen.', 'Form mit geölten Filoblättern auslegen.', 'Füllung einfüllen und mit weiteren Filoblättern bedecken.', 'Bei 190 Grad ca. 35 Min. goldbraun backen.'],
      sr: ['Лук продинстати, додати спанаћ и оставити да спласне.', 'Охладити, помешати са измрвљеном фетом и јајима, зачинити.', 'Калуп обложити науљеним корама.', 'Сипати фил и прекрити додатним корама.', 'Пећи на 190 степени око 35 минута до златне боје.'],
      hr: ['Luk popirjati, dodati špinat i ostaviti da splasne.', 'Ohladiti, pomiješati s izmrvljenom fetom i jajima, začiniti.', 'Kalup obložiti nauljenim korama.', 'Uliti nadjev i prekriti dodatnim korama.', 'Peći na 190 stupnjeva oko 35 minuta do zlatne boje.'],
      ba: ['Luk podinstati, dodati špinat i ostaviti da splasne.', 'Ohladiti, pomiješati sa izmrvljenom fetom i jajima, začiniti.', 'Kalup obložiti nauljenim jufkama.', 'Uliti nadjev i prekriti dodatnim jufkama.', 'Peći na 190 stepeni oko 35 minuta do zlatne boje.'],
      en: ['Sauté the onion, add the spinach and let it wilt.', 'Cool, mix with crumbled feta and eggs, season.', 'Line a tin with oiled filo sheets.', 'Add the filling and cover with more filo sheets.', 'Bake at 190 degrees for about 35 minutes until golden.']
    }
  },

  {
    id: 'dolmades', kueche: 'griechisch', portionen: 5, dauer_min: 90,
    titel: { de: 'Dolmades (gefüllte Weinblätter)', sr: 'Долме (пуњено лишће винове лозе)', hr: 'Dolme (punjeni listovi vinove loze)', ba: 'Dolme (punjeni listovi vinove loze)', en: 'Dolmades (stuffed vine leaves)' },
    zutaten: [
      { menge: 40, einheit: 'stk', name: { de: 'Weinblätter (eingelegt)', sr: 'лишће винове лозе (кисело)', hr: 'listovi vinove loze (kiseli)', ba: 'listovi vinove loze (kiseli)', en: 'vine leaves (brined)' } },
      { menge: 250, einheit: 'g', name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'bund', name: { de: 'Dill und Minze', sr: 'мирођија и нана', hr: 'kopar i menta', ba: 'mirođija i menta', en: 'dill and mint' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone (Saft)', sr: 'лимун (сок)', hr: 'limun (sok)', ba: 'limun (sok)', en: 'lemon (juice)' } },
      { menge: 80, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Zwiebel anschwitzen, Reis, Kräuter, Salz und Pfeffer mischen.', 'Je etwas Füllung auf ein Weinblatt geben und fest aufrollen.', 'Rollen dicht in einen Topf schichten.', 'Mit Olivenöl, Zitronensaft und Wasser knapp bedecken.', 'Zugedeckt bei schwacher Hitze ca. 45 Min. garen.'],
      sr: ['Лук продинстати, помешати пиринач, зачинско биље, со и бибер.', 'На свако лишће ставити мало фила и чврсто уролати.', 'Ролнице густо сложити у лонац.', 'Прелити маслиновим уљем, соком лимуна и водом да једва прекрије.', 'Поклопљено кувати на тихој ватри око 45 минута.'],
      hr: ['Luk popirjati, pomiješati rižu, začinsko bilje, sol i papar.', 'Na svaki list staviti malo nadjeva i čvrsto zamotati.', 'Rolice gusto složiti u lonac.', 'Preliti maslinovim uljem, sokom limuna i vodom da jedva prekrije.', 'Poklopljeno kuhati na laganoj vatri oko 45 minuta.'],
      ba: ['Luk podinstati, pomiješati rižu, začinsko bilje, so i biber.', 'Na svaki list staviti malo nadjeva i čvrsto zamotati.', 'Rolnice gusto složiti u lonac.', 'Preliti maslinovim uljem, sokom limuna i vodom da jedva prekrije.', 'Poklopljeno kuhati na laganoj vatri oko 45 minuta.'],
      en: ['Sauté the onion, mix rice, herbs, salt and pepper.', 'Put a little filling on each leaf and roll up tightly.', 'Layer the rolls tightly in a pot.', 'Cover barely with olive oil, lemon juice and water.', 'Cook covered on low heat for about 45 minutes.']
    }
  },

  // ---- ORIENTALISCH --------------------------------------------------------
  {
    id: 'hummus', kueche: 'orientalisch', portionen: 6, dauer_min: 15,
    titel: { de: 'Hummus', sr: 'Хумус', hr: 'Hummus', ba: 'Humus', en: 'Hummus' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Kichererbsen (Dose)', sr: 'леблебије (конзерва)', hr: 'slanutak (konzerva)', ba: 'slanutak (konzerva)', en: 'chickpeas (can)' } },
      { menge: 3, einheit: 'el', name: { de: 'Tahini (Sesampaste)', sr: 'тахини (сусам паста)', hr: 'tahini (sezam pasta)', ba: 'tahini (sezam pasta)', en: 'tahini (sesame paste)' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone (Saft)', sr: 'лимун (сок)', hr: 'limun (sok)', ba: 'limun (sok)', en: 'lemon (juice)' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 3, einheit: 'el', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Kreuzkümmel', sr: 'со, кумин', hr: 'sol, kumin', ba: 'so, kumin', en: 'salt, cumin' } }
    ],
    schritte: {
      de: ['Kichererbsen abspülen und abtropfen lassen.', 'Mit Tahini, Zitronensaft, Knoblauch und etwas Wasser fein pürieren.', 'Olivenöl unterrühren, bis die Masse cremig ist.', 'Mit Salz und Kreuzkümmel abschmecken.', 'Mit Öl beträufelt und Fladenbrot servieren.'],
      sr: ['Леблебије исперите и оцедите.', 'Са тахинијем, соком лимуна, белим луком и мало воде фино изблендати.', 'Умешати маслиново уље док не постане кремасто.', 'Зачинити сољу и кумином.', 'Послужити прелито уљем уз лепињу.'],
      hr: ['Slanutak isperite i ocijedite.', 'S tahinijem, sokom limuna, češnjakom i malo vode fino izblendati.', 'Umiješati maslinovo ulje dok ne postane kremasto.', 'Začiniti soli i kuminom.', 'Poslužiti preliveno uljem uz lepinju.'],
      ba: ['Slanutak isperite i ocijedite.', 'Sa tahinijem, sokom limuna, bijelim lukom i malo vode fino izblendati.', 'Umiješati maslinovo ulje dok ne postane kremasto.', 'Začiniti soli i kuminom.', 'Poslužiti preliveno uljem uz lepinju.'],
      en: ['Rinse and drain the chickpeas.', 'Blend finely with tahini, lemon juice, garlic and a little water.', 'Stir in olive oil until creamy.', 'Season with salt and cumin.', 'Serve drizzled with oil and flatbread.']
    }
  },

  {
    id: 'falafel', kueche: 'orientalisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Falafel', sr: 'Фалафел', hr: 'Falafel', ba: 'Falafel', en: 'Falafel' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'getrocknete Kichererbsen', sr: 'сув леблебија', hr: 'suhi slanutak', ba: 'suhi slanutak', en: 'dried chickpeas' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 3, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kreuzkümmel', sr: 'кумин', hr: 'kumin', ba: 'kumin', en: 'cumin' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Öl zum Frittieren', sr: 'со, уље за пржење', hr: 'sol, ulje za prženje', ba: 'so, ulje za prženje', en: 'salt, oil for frying' } }
    ],
    schritte: {
      de: ['Kichererbsen über Nacht einweichen und abtropfen lassen (nicht kochen).', 'Mit Zwiebel, Knoblauch, Petersilie und Gewürzen fein zerkleinern.', 'Zu kleinen Bällchen formen.', 'In heißem Öl goldbraun frittieren.', 'Mit Hummus oder im Fladenbrot servieren.'],
      sr: ['Леблебије потопити преко ноћи и оцедити (не кувати).', 'Са луком, белим луком, першуном и зачинима ситно самлети.', 'Обликовати мале ћуфтице.', 'У врелом уљу испржити до златне боје.', 'Послужити са хумусом или у лепињи.'],
      hr: ['Slanutak namočiti preko noći i ocijediti (ne kuhati).', 'S lukom, češnjakom, peršinom i začinima sitno samljeti.', 'Oblikovati male okruglice.', 'U vrućem ulju pržiti do zlatne boje.', 'Poslužiti s humusom ili u lepinji.'],
      ba: ['Slanutak namočiti preko noći i ocijediti (ne kuhati).', 'Sa lukom, bijelim lukom, peršunom i začinima sitno samljeti.', 'Oblikovati male okruglice.', 'U vrućem ulju pržiti do zlatne boje.', 'Poslužiti sa humusom ili u lepinji.'],
      en: ['Soak the chickpeas overnight and drain (do not cook).', 'Finely grind with onion, garlic, parsley and spices.', 'Form into small balls.', 'Deep-fry in hot oil until golden.', 'Serve with hummus or in flatbread.']
    }
  },

  {
    id: 'shawarma', kueche: 'orientalisch', portionen: 4, dauer_min: 45,
    titel: { de: 'Chicken Shawarma', sr: 'Пилећа шаварма', hr: 'Pileća šavarma', ba: 'Pileća šavarma', en: 'Chicken shawarma' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Hähnchenschenkel', sr: 'пилећи батаци', hr: 'pileći bataci', ba: 'pileći bataci', en: 'chicken thighs' } },
      { menge: 2, einheit: 'el', name: { de: 'Joghurt', sr: 'јогурт', hr: 'jogurt', ba: 'jogurt', en: 'yogurt' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kreuzkümmel', sr: 'кумин', hr: 'kumin', ba: 'kumin', en: 'cumin' } },
      { menge: 1, einheit: 'tl', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: 3, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 4, einheit: 'stk', name: { de: 'Fladenbrote', sr: 'лепиње', hr: 'lepinje', ba: 'lepinje', en: 'flatbreads' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Hähnchen mit Joghurt, Gewürzen und Knoblauch marinieren.', 'Mind. 1 Std. ziehen lassen.', 'In der Pfanne kräftig anbraten, dann in Streifen schneiden.', 'Fladenbrote erwärmen.', 'Mit Fleisch, Salat und Knoblauchsauce füllen.'],
      sr: ['Пилетину маринирати са јогуртом, зачинима и белим луком.', 'Оставити најмање 1 сат.', 'У тигању јако пропржити, па исећи на траке.', 'Лепиње загрејати.', 'Напунити месом, салатом и сосом од белог лука.'],
      hr: ['Piletinu marinirati s jogurtom, začinima i češnjakom.', 'Ostaviti najmanje 1 sat.', 'U tavi jako popržiti, pa narezati na trake.', 'Lepinje zagrijati.', 'Napuniti mesom, salatom i umakom od češnjaka.'],
      ba: ['Piletinu marinirati sa jogurtom, začinima i bijelim lukom.', 'Ostaviti najmanje 1 sat.', 'U tavi jako popržiti, pa narezati na trake.', 'Lepinje zagrijati.', 'Napuniti mesom, salatom i sosom od bijelog luka.'],
      en: ['Marinate the chicken with yogurt, spices and garlic.', 'Let it rest for at least 1 hour.', 'Sear well in a pan, then slice into strips.', 'Warm the flatbreads.', 'Fill with meat, salad and garlic sauce.']
    }
  },

  {
    id: 'tabbouleh', kueche: 'orientalisch', portionen: 4, dauer_min: 25,
    titel: { de: 'Tabbouleh (Bulgursalat)', sr: 'Табуле (салата од булгура)', hr: 'Tabbouleh (salata od bulgura)', ba: 'Tabbouleh (salata od bulgura)', en: 'Tabbouleh (bulgur salad)' },
    zutaten: [
      { menge: 100, einheit: 'g', name: { de: 'Bulgur', sr: 'булгур', hr: 'bulgur', ba: 'bulgur', en: 'bulgur' } },
      { menge: 2, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } },
      { menge: 3, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 3, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone (Saft)', sr: 'лимун (сок)', hr: 'limun (sok)', ba: 'limun (sok)', en: 'lemon (juice)' } },
      { menge: 4, einheit: 'el', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Minze', sr: 'со, нана', hr: 'sol, menta', ba: 'so, menta', en: 'salt, mint' } }
    ],
    schritte: {
      de: ['Bulgur mit heißem Wasser übergießen und quellen lassen.', 'Petersilie, Tomaten und Frühlingszwiebeln sehr fein hacken.', 'Alles mit dem abgetropften Bulgur mischen.', 'Mit Zitronensaft, Öl, Salz und Minze abschmecken.', 'Kühl servieren.'],
      sr: ['Булгур прелити врелом водом и оставити да набубри.', 'Першун, парадајз и млади лук врло ситно исецкати.', 'Све помешати са оцеђеним булгуром.', 'Зачинити соком лимуна, уљем, сољу и наном.', 'Послужити хладно.'],
      hr: ['Bulgur preliti vrućom vodom i ostaviti da nabubri.', 'Peršin, rajčice i mladi luk vrlo sitno nasjeckati.', 'Sve pomiješati s ocijeđenim bulgurom.', 'Začiniti sokom limuna, uljem, soli i mentom.', 'Poslužiti hladno.'],
      ba: ['Bulgur preliti vrućom vodom i ostaviti da nabubri.', 'Peršun, paradajz i mladi luk vrlo sitno nasjeckati.', 'Sve pomiješati sa ocijeđenim bulgurom.', 'Začiniti sokom limuna, uljem, soli i mentom.', 'Poslužiti hladno.'],
      en: ['Pour hot water over the bulgur and let it swell.', 'Very finely chop the parsley, tomatoes and spring onions.', 'Mix everything with the drained bulgur.', 'Season with lemon juice, oil, salt and mint.', 'Serve chilled.']
    }
  },

  {
    id: 'koefte', kueche: 'orientalisch', portionen: 4, dauer_min: 35,
    titel: { de: 'Köfte (Hackfleischbällchen)', sr: 'Ћуфте (месне ћуфтице)', hr: 'Köfte (mesne okruglice)', ba: 'Ćufte (mesne okruglice)', en: 'Köfte (meatballs)' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Lamm- oder Rinderhack', sr: 'јагњеће или јунеће млевено месо', hr: 'janjeće ili juneće mljeveno meso', ba: 'janjeće ili juneće mljeveno meso', en: 'lamb or beef mince' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kreuzkümmel', sr: 'кумин', hr: 'kumin', ba: 'kumin', en: 'cumin' } },
      { menge: 1, einheit: 'tl', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'crvena paprika', ba: 'crvena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Zwiebel und Petersilie sehr fein hacken.', 'Mit Hack und Gewürzen gründlich verkneten.', 'Zu länglichen Bällchen formen.', 'In der Pfanne oder auf dem Grill rundum garen.', 'Mit Reis, Fladenbrot und Joghurt servieren.'],
      sr: ['Лук и першун врло ситно исецкати.', 'Са месом и зачинима добро умесити.', 'Обликовати издужене ћуфтице.', 'У тигању или на роштиљу испећи са свих страна.', 'Послужити са пиринчем, лепињом и јогуртом.'],
      hr: ['Luk i peršin vrlo sitno nasjeckati.', 'S mesom i začinima dobro umijesiti.', 'Oblikovati duguljaste okruglice.', 'U tavi ili na roštilju ispeći sa svih strana.', 'Poslužiti s rižom, lepinjom i jogurtom.'],
      ba: ['Luk i peršun vrlo sitno nasjeckati.', 'Sa mesom i začinima dobro umijesiti.', 'Oblikovati duguljaste okruglice.', 'U tavi ili na roštilju ispeći sa svih strana.', 'Poslužiti sa rižom, lepinjom i jogurtom.'],
      en: ['Very finely chop the onion and parsley.', 'Knead well with the mince and spices.', 'Form into elongated balls.', 'Cook in a pan or on the grill all over.', 'Serve with rice, flatbread and yogurt.']
    }
  },

  {
    id: 'baklava', kueche: 'orientalisch', portionen: 10, dauer_min: 75,
    titel: { de: 'Baklava', sr: 'Баклава', hr: 'Baklava', ba: 'Baklava', en: 'Baklava' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Filoteig', sr: 'коре за питу', hr: 'kore za pitu', ba: 'jufke', en: 'filo pastry' } },
      { menge: 300, einheit: 'g', name: { de: 'gehackte Walnüsse', sr: 'млевени ораси', hr: 'mljeveni orasi', ba: 'mljeveni orasi', en: 'chopped walnuts' } },
      { menge: 200, einheit: 'g', name: { de: 'Butter (geschmolzen)', sr: 'путер (отопљен)', hr: 'maslac (otopljen)', ba: 'maslac (otopljen)', en: 'butter (melted)' } },
      { menge: 300, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 250, einheit: 'ml', name: { de: 'Wasser', sr: 'вода', hr: 'voda', ba: 'voda', en: 'water' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone (Saft)', sr: 'лимун (сок)', hr: 'limun (sok)', ba: 'limun (sok)', en: 'lemon (juice)' } }
    ],
    schritte: {
      de: ['Abwechselnd gebutterte Filoblätter und Walnüsse in eine Form schichten.', 'Vor dem Backen in Rauten schneiden.', 'Bei 170 Grad ca. 40 Min. goldbraun backen.', 'Zucker, Wasser und Zitronensaft zu Sirup kochen.', 'Heißen Sirup über die abgekühlte Baklava gießen und durchziehen lassen.'],
      sr: ['Наизменично ређати намаслаћене коре и орахе у плех.', 'Пре печења исећи на ромбове.', 'Пећи на 170 степени око 40 минута до златне боје.', 'Шећер, воду и сок лимуна укувати у сируп.', 'Врели сируп прелити преко охлађене баклаве и оставити да упије.'],
      hr: ['Naizmjenično slagati namaslane kore i orahe u lim.', 'Prije pečenja narezati na rombove.', 'Peći na 170 stupnjeva oko 40 minuta do zlatne boje.', 'Šećer, vodu i sok limuna ukuhati u sirup.', 'Vrući sirup preliti preko ohlađene baklave i ostaviti da upije.'],
      ba: ['Naizmjenično slagati namaslane jufke i orahe u pleh.', 'Prije pečenja narezati na rombove.', 'Peći na 170 stepeni oko 40 minuta do zlatne boje.', 'Šećer, vodu i sok limuna ukuhati u sirup.', 'Vrući sirup preliti preko ohlađene baklave i ostaviti da upije.'],
      en: ['Layer buttered filo sheets and walnuts alternately in a tin.', 'Cut into diamonds before baking.', 'Bake at 170 degrees for about 40 minutes until golden.', 'Boil sugar, water and lemon juice into a syrup.', 'Pour hot syrup over the cooled baklava and let it soak.']
    }
  },

  // ---- INTERNATIONAL / ALLTAG ----------------------------------------------
  {
    id: 'omelett', kueche: 'international', portionen: 2, dauer_min: 15,
    titel: { de: 'Gemüse-Omelett', sr: 'Омлет са поврћем', hr: 'Omlet s povrćem', ba: 'Omlet sa povrćem', en: 'Vegetable omelette' },
    zutaten: [
      { menge: 5, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 1, einheit: 'stk', name: { de: 'Tomate', sr: 'парадајз', hr: 'rajčica', ba: 'paradajz', en: 'tomato' } },
      { menge: 80, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: 20, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Paprika und Tomate klein würfeln.', 'Eier verquirlen, salzen und pfeffern.', 'Gemüse in Butter kurz andünsten.', 'Eier darübergießen und stocken lassen.', 'Mit Käse bestreuen, zusammenklappen und servieren.'],
      sr: ['Паприку и парадајз ситно исецкати.', 'Јаја умутити, посолити и побиберити.', 'Поврће у путеру кратко продинстати.', 'Прелити јајима и оставити да се стегну.', 'Посути сиром, преклопити и послужити.'],
      hr: ['Papriku i rajčicu sitno narezati.', 'Jaja umutiti, posoliti i popapriti.', 'Povrće u maslacu kratko popirjati.', 'Preliti jajima i ostaviti da se stegnu.', 'Posuti sirom, preklopiti i poslužiti.'],
      ba: ['Papriku i paradajz sitno narezati.', 'Jaja umutiti, posoliti i pobiberiti.', 'Povrće u maslacu kratko podinstati.', 'Preliti jajima i ostaviti da se stegnu.', 'Posuti sirom, preklopiti i poslužiti.'],
      en: ['Finely dice the pepper and tomato.', 'Whisk the eggs, season with salt and pepper.', 'Sauté the vegetables briefly in butter.', 'Pour the eggs over and let set.', 'Sprinkle with cheese, fold over and serve.']
    }
  },

  {
    id: 'tomatensuppe', kueche: 'international', portionen: 4, dauer_min: 30,
    titel: { de: 'Tomatensuppe', sr: 'Супа од парадајза', hr: 'Juha od rajčice', ba: 'Supa od paradajza', en: 'Tomato soup' },
    zutaten: [
      { menge: 800, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 500, einheit: 'ml', name: { de: 'Gemüsebrühe', sr: 'повртна супа', hr: 'povrtni temeljac', ba: 'povrtna supa', en: 'vegetable broth' } },
      { menge: 100, einheit: 'ml', name: { de: 'Sahne', sr: 'павлака за кување', hr: 'vrhnje za kuhanje', ba: 'pavlaka za kuhanje', en: 'cream' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Basilikum', sr: 'со, бибер, босиљак', hr: 'sol, papar, bosiljak', ba: 'so, biber, bosiljak', en: 'salt, pepper, basil' } }
    ],
    schritte: {
      de: ['Zwiebel und Knoblauch in Öl anschwitzen.', 'Tomaten und Brühe zugeben, 15 Min. köcheln.', 'Suppe fein pürieren.', 'Sahne einrühren und mit Salz, Pfeffer und Basilikum abschmecken.', 'Mit Brot servieren.'],
      sr: ['Лук и бели лук продинстати на уљу.', 'Додати парадајз и супу, кувати 15 минута.', 'Супу фино изблендати.', 'Умешати павлаку и зачинити сољу, бибером и босиљком.', 'Послужити са хлебом.'],
      hr: ['Luk i češnjak popirjati na ulju.', 'Dodati rajčice i temeljac, kuhati 15 minuta.', 'Juhu fino izblendati.', 'Umiješati vrhnje i začiniti soli, paprom i bosiljkom.', 'Poslužiti s kruhom.'],
      ba: ['Luk i bijeli luk podinstati na ulju.', 'Dodati paradajz i supu, kuhati 15 minuta.', 'Supu fino izblendati.', 'Umiješati pavlaku i začiniti soli, biberom i bosiljkom.', 'Poslužiti sa hljebom.'],
      en: ['Sauté the onion and garlic in oil.', 'Add tomatoes and broth, simmer for 15 minutes.', 'Purée the soup finely.', 'Stir in cream and season with salt, pepper and basil.', 'Serve with bread.']
    }
  },

  {
    id: 'gemuesecurry', kueche: 'international', portionen: 4, dauer_min: 35,
    titel: { de: 'Gemüse-Curry', sr: 'Кари са поврћем', hr: 'Curry s povrćem', ba: 'Curry sa povrćem', en: 'Vegetable curry' },
    zutaten: [
      { menge: 400, einheit: 'ml', name: { de: 'Kokosmilch', sr: 'кокосово млеко', hr: 'kokosovo mlijeko', ba: 'kokosovo mlijeko', en: 'coconut milk' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 200, einheit: 'g', name: { de: 'Kichererbsen', sr: 'леблебије', hr: 'slanutak', ba: 'slanutak', en: 'chickpeas' } },
      { menge: 2, einheit: 'el', name: { de: 'Currypaste', sr: 'кари паста', hr: 'curry pasta', ba: 'curry pasta', en: 'curry paste' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Reis zum Servieren', sr: 'со, пиринач за прилог', hr: 'sol, riža za prilog', ba: 'so, riža za prilog', en: 'salt, rice to serve' } }
    ],
    schritte: {
      de: ['Zwiebel anschwitzen, Currypaste kurz mitrösten.', 'Gemüse zugeben und kurz anbraten.', 'Kokosmilch angießen und 15 Min. köcheln.', 'Kichererbsen zugeben und erwärmen.', 'Mit Salz abschmecken und mit Reis servieren.'],
      sr: ['Лук продинстати, кари пасту кратко пропржити.', 'Додати поврће и кратко пропржити.', 'Долити кокосово млеко и кувати 15 минута.', 'Додати леблебије и загрејати.', 'Зачинити сољу и послужити са пиринчем.'],
      hr: ['Luk popirjati, curry pastu kratko popržiti.', 'Dodati povrće i kratko popržiti.', 'Uliti kokosovo mlijeko i kuhati 15 minuta.', 'Dodati slanutak i zagrijati.', 'Začiniti soli i poslužiti s rižom.'],
      ba: ['Luk podinstati, curry pastu kratko popržiti.', 'Dodati povrće i kratko popržiti.', 'Uliti kokosovo mlijeko i kuhati 15 minuta.', 'Dodati slanutak i zagrijati.', 'Začiniti soli i poslužiti sa rižom.'],
      en: ['Sauté the onion, toast the curry paste briefly.', 'Add the vegetables and fry briefly.', 'Pour in coconut milk and simmer for 15 minutes.', 'Add the chickpeas and warm through.', 'Season with salt and serve with rice.']
    }
  },

  {
    id: 'ruehrei', kueche: 'international', portionen: 2, dauer_min: 10,
    titel: { de: 'Rührei', sr: 'Кајгана', hr: 'Kajgana', ba: 'Kajgana', en: 'Scrambled eggs' },
    zutaten: [
      { menge: 5, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 3, einheit: 'el', name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 20, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: 1, einheit: 'bund', name: { de: 'Schnittlauch', sr: 'влашац', hr: 'vlasac', ba: 'vlasac', en: 'chives' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Eier mit Milch, Salz und Pfeffer verquirlen.', 'Butter in der Pfanne schmelzen.', 'Eimasse zugeben und bei mittlerer Hitze langsam stocken lassen.', 'Immer wieder vorsichtig rühren.', 'Mit Schnittlauch bestreut servieren.'],
      sr: ['Јаја умутити са млеком, сољу и бибером.', 'Путер отопити у тигању.', 'Додати масу и на средњој ватри полако стезати.', 'Стално пажљиво мешати.', 'Послужити посуто влашцем.'],
      hr: ['Jaja umutiti s mlijekom, soli i paprom.', 'Maslac otopiti u tavi.', 'Dodati masu i na srednjoj vatri polako stezati.', 'Stalno pažljivo miješati.', 'Poslužiti posuto vlascem.'],
      ba: ['Jaja umutiti sa mlijekom, soli i biberom.', 'Maslac otopiti u tavi.', 'Dodati masu i na srednjoj vatri polako stezati.', 'Stalno pažljivo miješati.', 'Poslužiti posuto vlascem.'],
      en: ['Whisk the eggs with milk, salt and pepper.', 'Melt the butter in a pan.', 'Add the egg mixture and let it set slowly on medium heat.', 'Keep stirring gently.', 'Serve sprinkled with chives.']
    }
  },

  {
    id: 'reis_mit_gemuese', kueche: 'international', portionen: 4, dauer_min: 30,
    titel: { de: 'Reispfanne mit Gemüse', sr: 'Пиринач са поврћем', hr: 'Riža s povrćem', ba: 'Riža sa povrćem', en: 'Rice with vegetables' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 150, einheit: 'g', name: { de: 'Erbsen', sr: 'грашак', hr: 'grašak', ba: 'grašak', en: 'peas' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 700, einheit: 'ml', name: { de: 'Gemüsebrühe', sr: 'повртна супа', hr: 'povrtni temeljac', ba: 'povrtna supa', en: 'vegetable broth' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Zwiebel und Gemüse würfeln und in Öl anbraten.', 'Reis zugeben und kurz anrösten.', 'Mit Brühe aufgießen.', 'Zugedeckt bei schwacher Hitze ca. 18 Min. garen.', 'Mit Salz und Pfeffer abschmecken und auflockern.'],
      sr: ['Лук и поврће исецкати и пропржити на уљу.', 'Додати пиринач и кратко пропржити.', 'Залити супом.', 'Поклопљено на тихој ватри кувати око 18 минута.', 'Зачинити сољу и бибером и разрахлити.'],
      hr: ['Luk i povrće narezati i popržiti na ulju.', 'Dodati rižu i kratko popržiti.', 'Zaliti temeljcem.', 'Poklopljeno na laganoj vatri kuhati oko 18 minuta.', 'Začiniti soli i paprom i rastresti.'],
      ba: ['Luk i povrće narezati i popržiti na ulju.', 'Dodati rižu i kratko popržiti.', 'Zaliti supom.', 'Poklopljeno na laganoj vatri kuhati oko 18 minuta.', 'Začiniti soli i biberom i rastresti.'],
      en: ['Dice the onion and vegetables and fry in oil.', 'Add the rice and toast briefly.', 'Pour in the broth.', 'Cook covered on low heat for about 18 minutes.', 'Season with salt and pepper and fluff up.']
    }
  },

  {
    id: 'kartoffelpuffer', kueche: 'international', portionen: 4, dauer_min: 30,
    titel: { de: 'Kartoffelpuffer', sr: 'Кромпир палачинке', hr: 'Krumpirovi palačinci', ba: 'Krompir palačinke', en: 'Potato pancakes' },
    zutaten: [
      { menge: 800, einheit: 'g', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 3, einheit: 'el', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Öl', sr: 'со, бибер, уље', hr: 'sol, papar, ulje', ba: 'so, biber, ulje', en: 'salt, pepper, oil' } }
    ],
    schritte: {
      de: ['Kartoffeln und Zwiebel fein reiben und gut ausdrücken.', 'Mit Eiern, Mehl, Salz und Pfeffer vermengen.', 'Kleine Portionen in heißes Öl geben und flach drücken.', 'Pro Seite goldbraun und knusprig braten.', 'Mit Apfelmus oder Quark servieren.'],
      sr: ['Кромпир и лук ситно изрендати и добро исцедити.', 'Помешати са јајима, брашном, сољу и бибером.', 'Мале порције ставити у врело уље и спљоштити.', 'Пржити са сваке стране до златне и хрскаве боје.', 'Послужити са пекмезом од јабука или сиром.'],
      hr: ['Krumpir i luk sitno naribati i dobro ocijediti.', 'Pomiješati s jajima, brašnom, soli i paprom.', 'Male porcije staviti u vruće ulje i spljoštiti.', 'Pržiti sa svake strane do zlatne i hrskave boje.', 'Poslužiti s pekmezom od jabuka ili sirom.'],
      ba: ['Krompir i luk sitno naribati i dobro ocijediti.', 'Pomiješati sa jajima, brašnom, soli i biberom.', 'Male porcije staviti u vruće ulje i spljoštiti.', 'Pržiti sa svake strane do zlatne i hrskave boje.', 'Poslužiti sa pekmezom od jabuka ili sirom.'],
      en: ['Finely grate the potatoes and onion and squeeze out well.', 'Mix with eggs, flour, salt and pepper.', 'Put small portions into hot oil and flatten.', 'Fry until golden and crisp on each side.', 'Serve with apple sauce or quark.']
    }
  },

  // ---- FRANZÖSISCH ---------------------------------------------------------
  {
    id: 'quiche_lorraine', kueche: 'franzoesisch', portionen: 6, dauer_min: 60,
    titel: { de: 'Quiche Lorraine', sr: 'Киш Лорен', hr: 'Quiche Lorraine', ba: 'Quiche Lorraine', en: 'Quiche Lorraine' },
    zutaten: [
      { menge: 1, einheit: 'stk', name: { de: 'Blätterteig', sr: 'лиснато тесто', hr: 'lisnato tijesto', ba: 'lisnato tijesto', en: 'shortcrust pastry' } },
      { menge: 200, einheit: 'g', name: { de: 'geräucherter Speck', sr: 'димљена сланина', hr: 'dimljena slanina', ba: 'dimljena slanina', en: 'smoked bacon' } },
      { menge: 4, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 200, einheit: 'ml', name: { de: 'Sahne', sr: 'павлака за кување', hr: 'vrhnje za kuhanje', ba: 'pavlaka za kuhanje', en: 'cream' } },
      { menge: 150, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Muskat', sr: 'со, бибер, мушкатни орашчић', hr: 'sol, papar, muškatni oraščić', ba: 'so, biber, muškatni oraščić', en: 'salt, pepper, nutmeg' } }
    ],
    schritte: {
      de: ['Teig in eine Form legen und mit einer Gabel einstechen.', 'Speck würfeln und knusprig anbraten.', 'Eier mit Sahne, Käse und Gewürzen verquirlen.', 'Speck auf dem Teig verteilen, Eimasse darübergießen.', 'Bei 180 Grad ca. 35 Minuten goldbraun backen.'],
      sr: ['Тесто ставити у калуп и избуцкати виљушком.', 'Сланину исецкати и пропржити до хрскавости.', 'Јаја умутити са павлаком, сиром и зачинима.', 'Сланину распоредити по тесту, прелити смесом.', 'Пећи на 180 степени око 35 минута до златне боје.'],
      hr: ['Tijesto staviti u kalup i izbockati vilicom.', 'Slaninu narezati i popržiti do hrskavosti.', 'Jaja umutiti s vrhnjem, sirom i začinima.', 'Slaninu rasporediti po tijestu, preliti smjesom.', 'Peći na 180 stupnjeva oko 35 minuta do zlatne boje.'],
      ba: ['Tijesto staviti u kalup i izbockati viljuškom.', 'Slaninu narezati i popržiti do hrskavosti.', 'Jaja umutiti sa pavlakom, sirom i začinima.', 'Slaninu rasporediti po tijestu, preliti smjesom.', 'Peći na 180 stepeni oko 35 minuta do zlatne boje.'],
      en: ['Line a tin with the pastry and prick with a fork.', 'Dice the bacon and fry until crisp.', 'Whisk eggs with cream, cheese and seasoning.', 'Spread bacon over the pastry, pour the mixture over.', 'Bake at 180 degrees for about 35 minutes until golden.']
    }
  },

  {
    id: 'ratatouille', kueche: 'franzoesisch', portionen: 4, dauer_min: 50,
    titel: { de: 'Ratatouille', sr: 'Рататуј', hr: 'Ratatouille', ba: 'Ratatouille', en: 'Ratatouille' },
    zutaten: [
      { menge: 1, einheit: 'stk', name: { de: 'Aubergine', sr: 'плави патлиџан', hr: 'patlidžan', ba: 'plavi patlidžan', en: 'aubergine' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zucchini', sr: 'тиквица', hr: 'tikvica', ba: 'tikvica', en: 'courgette' } },
      { menge: 2, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell peppers' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Kräuter, Salz', sr: 'маслиново уље, зачинско биље, со', hr: 'maslinovo ulje, začinsko bilje, sol', ba: 'maslinovo ulje, začinsko bilje, so', en: 'olive oil, herbs, salt' } }
    ],
    schritte: {
      de: ['Gemüse in gleichmäßige Würfel schneiden.', 'Zwiebel und Knoblauch in Olivenöl anschwitzen.', 'Aubergine, Zucchini und Paprika zugeben und anbraten.', 'Tomaten und Kräuter zugeben.', 'Zugedeckt bei kleiner Hitze ca. 30 Minuten schmoren.'],
      sr: ['Поврће исећи на једнаке коцкице.', 'Лук и бели лук продинстати на маслиновом уљу.', 'Додати патлиџан, тиквицу и паприку и пропржити.', 'Додати парадајз и зачинско биље.', 'Поклопљено на тихој ватри динстати око 30 минута.'],
      hr: ['Povrće narezati na jednake kockice.', 'Luk i češnjak popirjati na maslinovom ulju.', 'Dodati patlidžan, tikvicu i papriku i popržiti.', 'Dodati rajčice i začinsko bilje.', 'Poklopljeno na laganoj vatri pirjati oko 30 minuta.'],
      ba: ['Povrće narezati na jednake kockice.', 'Luk i bijeli luk podinstati na maslinovom ulju.', 'Dodati patlidžan, tikvicu i papriku i popržiti.', 'Dodati paradajz i začinsko bilje.', 'Poklopljeno na laganoj vatri dinstati oko 30 minuta.'],
      en: ['Cut the vegetables into even cubes.', 'Sauté onion and garlic in olive oil.', 'Add aubergine, courgette and pepper and fry.', 'Add the tomatoes and herbs.', 'Cover and stew on low heat for about 30 minutes.']
    }
  },

  {
    id: 'crepes', kueche: 'franzoesisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Crêpes', sr: 'Француске палачинке', hr: 'Francuske palačinke', ba: 'Francuske palačinke', en: 'Crêpes' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 500, einheit: 'ml', name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 1, einheit: 'prise', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } },
      { menge: 30, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } }
    ],
    schritte: {
      de: ['Mehl, Milch, Eier und Salz zu einem glatten Teig verrühren.', 'Teig 15 Minuten ruhen lassen.', 'Etwas Butter in einer Pfanne erhitzen.', 'Dünn ausbacken und pro Seite kurz backen.', 'Nach Wunsch mit Marmelade oder Schokolade füllen.'],
      sr: ['Брашно, млеко, јаја и со умутити у глатко тесто.', 'Тесто оставити да одстоји 15 минута.', 'Мало путера загрејати у тигању.', 'Танко испећи и са сваке стране кратко пржити.', 'По жељи пунити мармеладом или чоколадом.'],
      hr: ['Brašno, mlijeko, jaja i sol umutiti u glatko tijesto.', 'Tijesto ostaviti da odstoji 15 minuta.', 'Malo maslaca zagrijati u tavi.', 'Tanko ispeći i sa svake strane kratko pržiti.', 'Po želji puniti marmeladom ili čokoladom.'],
      ba: ['Brašno, mlijeko, jaja i so umutiti u glatko tijesto.', 'Tijesto ostaviti da odstoji 15 minuta.', 'Malo maslaca zagrijati u tavi.', 'Tanko ispeći i sa svake strane kratko pržiti.', 'Po želji puniti marmeladom ili čokoladom.'],
      en: ['Whisk flour, milk, eggs and salt into a smooth batter.', 'Let the batter rest for 15 minutes.', 'Heat a little butter in a pan.', 'Cook thin and fry briefly on each side.', 'Fill with jam or chocolate as desired.']
    }
  },

  {
    id: 'croque_monsieur', kueche: 'franzoesisch', portionen: 2, dauer_min: 20,
    titel: { de: 'Croque Monsieur', sr: 'Крок мосје', hr: 'Croque Monsieur', ba: 'Croque Monsieur', en: 'Croque Monsieur' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Toastscheiben', sr: 'кришке тост хлеба', hr: 'kriške tost kruha', ba: 'kriške tost hljeba', en: 'slices of toast' } },
      { menge: 4, einheit: 'stk', name: { de: 'Scheiben Kochschinken', sr: 'кришке шунке', hr: 'kriške šunke', ba: 'kriške šunke', en: 'slices of cooked ham' } },
      { menge: 150, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: 20, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: 100, einheit: 'ml', name: { de: 'Béchamelsauce', sr: 'бешамел сос', hr: 'bešamel umak', ba: 'bešamel sos', en: 'béchamel sauce' } }
    ],
    schritte: {
      de: ['Toast mit Béchamel bestreichen.', 'Mit Schinken und Käse belegen und zuklappen.', 'Von außen mit Butter bestreichen.', 'In der Pfanne oder im Ofen goldbraun überbacken.', 'Heiß servieren.'],
      sr: ['Тост премазати бешамел сосом.', 'Ставити шунку и сир и склопити.', 'Споља премазати путером.', 'У тигању или рерни запећи до златне боје.', 'Послужити вруће.'],
      hr: ['Tost premazati bešamel umakom.', 'Staviti šunku i sir i sklopiti.', 'Izvana premazati maslacem.', 'U tavi ili pećnici zapeći do zlatne boje.', 'Poslužiti vruće.'],
      ba: ['Tost premazati bešamel sosom.', 'Staviti šunku i sir i sklopiti.', 'Izvana premazati maslacem.', 'U tavi ili rerni zapeći do zlatne boje.', 'Poslužiti vruće.'],
      en: ['Spread béchamel on the toast.', 'Top with ham and cheese and close.', 'Butter the outside.', 'Grill golden in a pan or oven.', 'Serve hot.']
    }
  },

  {
    id: 'coq_au_vin', kueche: 'franzoesisch', portionen: 4, dauer_min: 90,
    titel: { de: 'Coq au Vin', sr: 'Пилетина у вину', hr: 'Piletina u vinu', ba: 'Piletina u vinu', en: 'Coq au vin' },
    zutaten: [
      { menge: 1, einheit: 'kg', name: { de: 'Hähnchenteile', sr: 'делови пилетине', hr: 'dijelovi piletine', ba: 'dijelovi piletine', en: 'chicken pieces' } },
      { menge: 500, einheit: 'ml', name: { de: 'Rotwein', sr: 'црно вино', hr: 'crno vino', ba: 'crno vino', en: 'red wine' } },
      { menge: 150, einheit: 'g', name: { de: 'Speck', sr: 'сланина', hr: 'slanina', ba: 'slanina', en: 'bacon' } },
      { menge: 250, einheit: 'g', name: { de: 'Champignons', sr: 'печурке', hr: 'šampinjoni', ba: 'šampinjoni', en: 'mushrooms' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Thymian', sr: 'со, бибер, мајчина душица', hr: 'sol, papar, majčina dušica', ba: 'so, biber, majčina dušica', en: 'salt, pepper, thyme' } }
    ],
    schritte: {
      de: ['Speck auslassen, Hähnchen darin rundum anbraten.', 'Zwiebel, Karotten und Champignons zugeben.', 'Mit Rotwein ablöschen.', 'Würzen und zugedeckt ca. 60 Minuten schmoren.', 'Sauce einkochen lassen und servieren.'],
      sr: ['Истопити сланину, пилетину у њој пропржити са свих страна.', 'Додати лук, шаргарепу и печурке.', 'Залити црним вином.', 'Зачинити и поклопљено динстати око 60 минута.', 'Сос укувати и послужити.'],
      hr: ['Istopiti slaninu, piletinu u njoj popržiti sa svih strana.', 'Dodati luk, mrkvu i šampinjone.', 'Zaliti crnim vinom.', 'Začiniti i poklopljeno pirjati oko 60 minuta.', 'Umak ukuhati i poslužiti.'],
      ba: ['Istopiti slaninu, piletinu u njoj popržiti sa svih strana.', 'Dodati luk, mrkvu i šampinjone.', 'Zaliti crnim vinom.', 'Začiniti i poklopljeno dinstati oko 60 minuta.', 'Sos ukuhati i poslužiti.'],
      en: ['Render the bacon, brown the chicken all over in it.', 'Add onion, carrots and mushrooms.', 'Deglaze with red wine.', 'Season and stew covered for about 60 minutes.', 'Reduce the sauce and serve.']
    }
  },

  {
    id: 'boeuf_bourguignon', kueche: 'franzoesisch', portionen: 4, dauer_min: 150,
    titel: { de: 'Boeuf Bourguignon', sr: 'Говедина бургињон', hr: 'Bœuf bourguignon', ba: 'Bœuf bourguignon', en: 'Beef bourguignon' },
    zutaten: [
      { menge: 800, einheit: 'g', name: { de: 'Rindergulasch', sr: 'говеђи гулаш', hr: 'goveđi gulaš', ba: 'goveđi gulaš', en: 'diced beef' } },
      { menge: 500, einheit: 'ml', name: { de: 'Rotwein', sr: 'црно вино', hr: 'crno vino', ba: 'crno vino', en: 'red wine' } },
      { menge: 150, einheit: 'g', name: { de: 'Speck', sr: 'сланина', hr: 'slanina', ba: 'slanina', en: 'bacon' } },
      { menge: 250, einheit: 'g', name: { de: 'Champignons', sr: 'печурке', hr: 'šampinjoni', ba: 'šampinjoni', en: 'mushrooms' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 2, einheit: 'el', name: { de: 'Tomatenmark', sr: 'паста од парадајза', hr: 'pasta od rajčice', ba: 'pasta od paradajza', en: 'tomato paste' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Lorbeer', sr: 'со, бибер, ловоров лист', hr: 'sol, papar, lovorov list', ba: 'so, biber, lovorov list', en: 'salt, pepper, bay leaf' } }
    ],
    schritte: {
      de: ['Speck auslassen, Fleisch darin scharf anbraten.', 'Karotten und Tomatenmark zugeben.', 'Mit Rotwein ablöschen und würzen.', 'Zugedeckt bei kleiner Hitze ca. 2 Stunden schmoren.', 'Champignons zugeben und weitere 20 Minuten garen.'],
      sr: ['Истопити сланину, месо у њој јако пропржити.', 'Додати шаргарепу и пасту од парадајза.', 'Залити црним вином и зачинити.', 'Поклопљено на тихој ватри динстати око 2 сата.', 'Додати печурке и кувати још 20 минута.'],
      hr: ['Istopiti slaninu, meso u njoj jako popržiti.', 'Dodati mrkvu i pastu od rajčice.', 'Zaliti crnim vinom i začiniti.', 'Poklopljeno na laganoj vatri pirjati oko 2 sata.', 'Dodati šampinjone i kuhati još 20 minuta.'],
      ba: ['Istopiti slaninu, meso u njoj jako popržiti.', 'Dodati mrkvu i pastu od paradajza.', 'Zaliti crnim vinom i začiniti.', 'Poklopljeno na laganoj vatri dinstati oko 2 sata.', 'Dodati šampinjone i kuhati još 20 minuta.'],
      en: ['Render the bacon, sear the meat hard in it.', 'Add carrots and tomato paste.', 'Deglaze with red wine and season.', 'Stew covered on low heat for about 2 hours.', 'Add mushrooms and cook another 20 minutes.']
    }
  },

  // ---- SPANISCH ------------------------------------------------------------
  {
    id: 'paella', kueche: 'spanisch', portionen: 4, dauer_min: 50,
    titel: { de: 'Paella', sr: 'Паеља', hr: 'Paella', ba: 'Paella', en: 'Paella' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Paella-Reis', sr: 'пиринач за паељу', hr: 'riža za paellu', ba: 'riža za paellu', en: 'paella rice' } },
      { menge: 300, einheit: 'g', name: { de: 'Hähnchen', sr: 'пилетина', hr: 'piletina', ba: 'piletina', en: 'chicken' } },
      { menge: 200, einheit: 'g', name: { de: 'Meeresfrüchte', sr: 'плодови мора', hr: 'plodovi mora', ba: 'plodovi mora', en: 'seafood' } },
      { menge: 150, einheit: 'g', name: { de: 'Erbsen', sr: 'грашак', hr: 'grašak', ba: 'grašak', en: 'peas' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 800, einheit: 'ml', name: { de: 'Brühe', sr: 'супа', hr: 'temeljac', ba: 'supa', en: 'stock' } },
      { menge: 1, einheit: 'prise', name: { de: 'Safran', sr: 'шафран', hr: 'šafran', ba: 'šafran', en: 'saffron' } }
    ],
    schritte: {
      de: ['Hähnchen in Öl anbraten und herausnehmen.', 'Paprika kurz anbraten, Reis zugeben.', 'Brühe mit Safran angießen.', 'Hähnchen, Erbsen und Meeresfrüchte verteilen.', 'Ohne Rühren ca. 20 Minuten garen, bis der Reis weich ist.'],
      sr: ['Пилетину пропржити на уљу и извадити.', 'Паприку кратко пропржити, додати пиринач.', 'Залити супом са шафраном.', 'Распоредити пилетину, грашак и плодове мора.', 'Без мешања кувати око 20 минута док пиринач не омекша.'],
      hr: ['Piletinu popržiti na ulju i izvaditi.', 'Papriku kratko popržiti, dodati rižu.', 'Zaliti temeljcem sa šafranom.', 'Rasporediti piletinu, grašak i plodove mora.', 'Bez miješanja kuhati oko 20 minuta dok riža ne omekša.'],
      ba: ['Piletinu popržiti na ulju i izvaditi.', 'Papriku kratko popržiti, dodati rižu.', 'Zaliti supom sa šafranom.', 'Rasporediti piletinu, grašak i plodove mora.', 'Bez miješanja kuhati oko 20 minuta dok riža ne omekša.'],
      en: ['Brown the chicken in oil and remove.', 'Fry the pepper briefly, add the rice.', 'Pour in stock with saffron.', 'Distribute chicken, peas and seafood.', 'Cook without stirring for about 20 minutes until the rice is soft.']
    }
  },

  {
    id: 'tortilla_espanola', kueche: 'spanisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Tortilla Española', sr: 'Шпански омлет', hr: 'Španjolski omlet', ba: 'Španski omlet', en: 'Spanish tortilla' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 6, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 100, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Kartoffeln und Zwiebel in dünne Scheiben schneiden.', 'In Olivenöl weich garen, dann abtropfen.', 'Mit verquirlten Eiern und Salz mischen.', 'Masse in die Pfanne geben und stocken lassen.', 'Wenden und die andere Seite goldbraun braten.'],
      sr: ['Кромпир и лук исећи на танке кришке.', 'У маслиновом уљу скувати до мекоће, па оцедити.', 'Помешати са умућеним јајима и сољу.', 'Смесу сипати у тигањ и оставити да се стегне.', 'Окренути и другу страну испржити до златне боје.'],
      hr: ['Krumpir i luk narezati na tanke kriške.', 'U maslinovom ulju skuhati do mekoće, pa ocijediti.', 'Pomiješati s umućenim jajima i soli.', 'Smjesu uliti u tavu i ostaviti da se stegne.', 'Okrenuti i drugu stranu ispržiti do zlatne boje.'],
      ba: ['Krompir i luk narezati na tanke kriške.', 'U maslinovom ulju skuhati do mekoće, pa ocijediti.', 'Pomiješati sa umućenim jajima i soli.', 'Smjesu uliti u tavu i ostaviti da se stegne.', 'Okrenuti i drugu stranu ispržiti do zlatne boje.'],
      en: ['Slice potatoes and onion thinly.', 'Cook soft in olive oil, then drain.', 'Mix with the beaten eggs and salt.', 'Pour the mixture into the pan and let set.', 'Flip and fry the other side golden.']
    }
  },

  {
    id: 'gazpacho', kueche: 'spanisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Gazpacho', sr: 'Гаспачо', hr: 'Gazpacho', ba: 'Gazpacho', en: 'Gazpacho' },
    zutaten: [
      { menge: 800, einheit: 'g', name: { de: 'reife Tomaten', sr: 'зрели парадајз', hr: 'zrele rajčice', ba: 'zreli paradajz', en: 'ripe tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Salatgurke', sr: 'краставац', hr: 'krastavac', ba: 'krastavac', en: 'cucumber' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 1, einheit: 'zehe', name: { de: 'Knoblauchzehe', sr: 'чен белог лука', hr: 'češanj češnjaka', ba: 'čehno bijelog luka', en: 'garlic clove' } },
      { menge: 3, einheit: 'el', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: 2, einheit: 'el', name: { de: 'Weinessig', sr: 'винско сирће', hr: 'vinski ocat', ba: 'vinsko sirće', en: 'wine vinegar' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Gemüse grob schneiden.', 'Alles mit Öl, Essig und Salz fein pürieren.', 'Bei Bedarf mit etwas kaltem Wasser verdünnen.', 'Mindestens 1 Stunde kalt stellen.', 'Eiskalt servieren.'],
      sr: ['Поврће крупно исећи.', 'Све фино изблендати са уљем, сирћетом и сољу.', 'По потреби разредити мало хладне воде.', 'Ставити у фрижидер најмање 1 сат.', 'Послужити ледено хладно.'],
      hr: ['Povrće krupno narezati.', 'Sve fino izblendati s uljem, octom i soli.', 'Po potrebi razrijediti malo hladne vode.', 'Staviti u hladnjak najmanje 1 sat.', 'Poslužiti ledeno hladno.'],
      ba: ['Povrće krupno narezati.', 'Sve fino izblendati sa uljem, sirćetom i soli.', 'Po potrebi razrijediti malo hladne vode.', 'Staviti u frižider najmanje 1 sat.', 'Poslužiti ledeno hladno.'],
      en: ['Roughly chop the vegetables.', 'Purée everything finely with oil, vinegar and salt.', 'Thin with a little cold water if needed.', 'Chill for at least 1 hour.', 'Serve ice-cold.']
    }
  },

  {
    id: 'patatas_bravas', kueche: 'spanisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Patatas Bravas', sr: 'Пататас бравас', hr: 'Patatas bravas', ba: 'Patatas bravas', en: 'Patatas bravas' },
    zutaten: [
      { menge: 800, einheit: 'g', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 1, einheit: 'tl', name: { de: 'geräuchertes Paprikapulver', sr: 'димљена алева паприка', hr: 'dimljena mljevena paprika', ba: 'dimljena mljevena paprika', en: 'smoked paprika' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Salz, Chili', sr: 'маслиново уље, со, чили', hr: 'maslinovo ulje, sol, čili', ba: 'maslinovo ulje, so, čili', en: 'olive oil, salt, chilli' } }
    ],
    schritte: {
      de: ['Kartoffeln würfeln und in Olivenöl knusprig braten.', 'Für die Sauce Zwiebel anschwitzen.', 'Tomaten, Paprikapulver und Chili zugeben.', 'Sauce 10 Minuten köcheln und würzen.', 'Kartoffeln mit der Sauce beträufelt servieren.'],
      sr: ['Кромпир исецкати и на маслиновом уљу испржити до хрскавости.', 'За сос продинстати лук.', 'Додати парадајз, алеву паприку и чили.', 'Сос кувати 10 минута и зачинити.', 'Кромпир послужити прелити сосом.'],
      hr: ['Krumpir narezati i na maslinovom ulju ispržiti do hrskavosti.', 'Za umak popirjati luk.', 'Dodati rajčice, mljevenu papriku i čili.', 'Umak kuhati 10 minuta i začiniti.', 'Krumpir poslužiti preliven umakom.'],
      ba: ['Krompir narezati i na maslinovom ulju ispržiti do hrskavosti.', 'Za sos podinstati luk.', 'Dodati paradajz, mljevenu papriku i čili.', 'Sos kuhati 10 minuta i začiniti.', 'Krompir poslužiti preliven sosom.'],
      en: ['Dice the potatoes and fry crisp in olive oil.', 'For the sauce, sauté the onion.', 'Add tomatoes, paprika and chilli.', 'Simmer the sauce for 10 minutes and season.', 'Serve the potatoes drizzled with the sauce.']
    }
  },

  {
    id: 'gambas_al_ajillo', kueche: 'spanisch', portionen: 2, dauer_min: 15,
    titel: { de: 'Gambas al Ajillo', sr: 'Шкампи на белом луку', hr: 'Škampi na češnjaku', ba: 'Škampi na bijelom luku', en: 'Garlic prawns' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Garnelen', sr: 'шкампи', hr: 'škampi', ba: 'škampi', en: 'prawns' } },
      { menge: 4, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 80, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: 1, einheit: 'stk', name: { de: 'Chilischote', sr: 'љута папричица', hr: 'ljuta papričica', ba: 'ljuta papričica', en: 'chilli' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Knoblauch in Scheiben schneiden und in Olivenöl erhitzen.', 'Chili zugeben.', 'Garnelen zugeben und kurz braten, bis sie rosa sind.', 'Mit Salz würzen.', 'Mit Petersilie bestreut und Brot servieren.'],
      sr: ['Бели лук исећи на листиће и загрејати у маслиновом уљу.', 'Додати чили.', 'Додати шкампе и кратко пржити док не поруже.', 'Зачинити сољу.', 'Послужити посуто першуном и уз хлеб.'],
      hr: ['Češnjak narezati na listiće i zagrijati u maslinovom ulju.', 'Dodati čili.', 'Dodati škampe i kratko pržiti dok ne porumene.', 'Začiniti soli.', 'Poslužiti posuto peršinom i uz kruh.'],
      ba: ['Bijeli luk narezati na listiće i zagrijati u maslinovom ulju.', 'Dodati čili.', 'Dodati škampe i kratko pržiti dok ne porumene.', 'Začiniti soli.', 'Poslužiti posuto peršunom i uz hljeb.'],
      en: ['Slice the garlic and heat in olive oil.', 'Add the chilli.', 'Add the prawns and fry briefly until pink.', 'Season with salt.', 'Serve sprinkled with parsley and bread.']
    }
  },

  {
    id: 'churros', kueche: 'spanisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Churros', sr: 'Чурос', hr: 'Churros', ba: 'Churros', en: 'Churros' },
    zutaten: [
      { menge: 250, einheit: 'ml', name: { de: 'Wasser', sr: 'вода', hr: 'voda', ba: 'voda', en: 'water' } },
      { menge: 150, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 1, einheit: 'stk', name: { de: 'Ei', sr: 'јаје', hr: 'jaje', ba: 'jaje', en: 'egg' } },
      { menge: 1, einheit: 'prise', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } },
      { menge: 50, einheit: 'g', name: { de: 'Zucker mit Zimt', sr: 'шећер са циметом', hr: 'šećer s cimetom', ba: 'šećer sa cimetom', en: 'sugar with cinnamon' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl zum Frittieren', sr: 'уље за пржење', hr: 'ulje za prženje', ba: 'ulje za prženje', en: 'oil for frying' } }
    ],
    schritte: {
      de: ['Wasser mit Salz aufkochen, Mehl einrühren.', 'Vom Herd nehmen und Ei unterrühren.', 'Teig in einen Spritzbeutel füllen.', 'Streifen in heißes Öl spritzen und goldbraun frittieren.', 'In Zimtzucker wälzen und servieren.'],
      sr: ['Воду са сољу прокувати, умешати брашно.', 'Скинути са ватре и умешати јаје.', 'Тесто ставити у шприц врећу.', 'Траке шприцати у врело уље и пржити до златне боје.', 'Уваљати у шећер са циметом и послужити.'],
      hr: ['Vodu sa soli prokuhati, umiješati brašno.', 'Skinuti s vatre i umiješati jaje.', 'Tijesto staviti u vrećicu za špricanje.', 'Trake špricati u vruće ulje i pržiti do zlatne boje.', 'Uvaljati u šećer s cimetom i poslužiti.'],
      ba: ['Vodu sa soli prokuhati, umiješati brašno.', 'Skinuti sa vatre i umiješati jaje.', 'Tijesto staviti u vrećicu za špricanje.', 'Trake špricati u vruće ulje i pržiti do zlatne boje.', 'Uvaljati u šećer sa cimetom i poslužiti.'],
      en: ['Boil water with salt, stir in the flour.', 'Remove from heat and stir in the egg.', 'Fill the dough into a piping bag.', 'Pipe strips into hot oil and fry golden.', 'Roll in cinnamon sugar and serve.']
    }
  },

  // ---- INDISCH -------------------------------------------------------------
  {
    id: 'butter_chicken', kueche: 'indisch', portionen: 4, dauer_min: 50,
    titel: { de: 'Butter Chicken', sr: 'Пилетина у путеру', hr: 'Butter chicken', ba: 'Butter chicken', en: 'Butter chicken' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Hähnchenbrust', sr: 'пилеће бело месо', hr: 'pileća prsa', ba: 'pileća prsa', en: 'chicken breast' } },
      { menge: 400, einheit: 'g', name: { de: 'passierte Tomaten', sr: 'пасирани парадајз', hr: 'pasirane rajčice', ba: 'pasirani paradajz', en: 'passata' } },
      { menge: 150, einheit: 'ml', name: { de: 'Sahne', sr: 'павлака за кување', hr: 'vrhnje za kuhanje', ba: 'pavlaka za kuhanje', en: 'cream' } },
      { menge: 40, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: 2, einheit: 'el', name: { de: 'Garam Masala', sr: 'гарам масала', hr: 'garam masala', ba: 'garam masala', en: 'garam masala' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: null, einheit: 'ng', name: { de: 'Ingwer, Salz', sr: 'ђумбир, со', hr: 'đumbir, sol', ba: 'đumbir, so', en: 'ginger, salt' } }
    ],
    schritte: {
      de: ['Hähnchen würfeln und in Butter anbraten.', 'Knoblauch, Ingwer und Garam Masala zugeben.', 'Passierte Tomaten angießen und 15 Minuten köcheln.', 'Sahne einrühren und mit Salz abschmecken.', 'Mit Reis oder Naan servieren.'],
      sr: ['Пилетину исецкати и пропржити на путеру.', 'Додати бели лук, ђумбир и гарам масалу.', 'Долити пасирани парадајз и кувати 15 минута.', 'Умешати павлаку и зачинити сољу.', 'Послужити са пиринчем или наан хлебом.'],
      hr: ['Piletinu narezati i popržiti na maslacu.', 'Dodati češnjak, đumbir i garam masalu.', 'Uliti pasirane rajčice i kuhati 15 minuta.', 'Umiješati vrhnje i začiniti soli.', 'Poslužiti s rižom ili naan kruhom.'],
      ba: ['Piletinu narezati i popržiti na maslacu.', 'Dodati bijeli luk, đumbir i garam masalu.', 'Uliti pasirani paradajz i kuhati 15 minuta.', 'Umiješati pavlaku i začiniti soli.', 'Poslužiti sa rižom ili naan hljebom.'],
      en: ['Dice the chicken and fry in butter.', 'Add garlic, ginger and garam masala.', 'Pour in passata and simmer for 15 minutes.', 'Stir in cream and season with salt.', 'Serve with rice or naan.']
    }
  },

  {
    id: 'dal', kueche: 'indisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Dal (Linsen)', sr: 'Дал (сочиво)', hr: 'Dal (leća)', ba: 'Dal (leća)', en: 'Dal (lentils)' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'rote Linsen', sr: 'црвено сочиво', hr: 'crvena leća', ba: 'crvena leća', en: 'red lentils' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kurkuma', sr: 'куркума', hr: 'kurkuma', ba: 'kurkuma', en: 'turmeric' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kreuzkümmel', sr: 'ким', hr: 'kim', ba: 'kim', en: 'cumin' } },
      { menge: 700, einheit: 'ml', name: { de: 'Wasser', sr: 'вода', hr: 'voda', ba: 'voda', en: 'water' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Ingwer', sr: 'со, ђумбир', hr: 'sol, đumbir', ba: 'so, đumbir', en: 'salt, ginger' } }
    ],
    schritte: {
      de: ['Zwiebel, Knoblauch und Ingwer in Öl anbraten.', 'Gewürze kurz mitrösten.', 'Linsen und Wasser zugeben.', 'Ca. 25 Minuten weich köcheln.', 'Mit Salz abschmecken und mit Reis servieren.'],
      sr: ['Лук, бели лук и ђумбир пропржити на уљу.', 'Зачине кратко пропржити.', 'Додати сочиво и воду.', 'Кувати око 25 минута до мекоће.', 'Зачинити сољу и послужити са пиринчем.'],
      hr: ['Luk, češnjak i đumbir popržiti na ulju.', 'Začine kratko popržiti.', 'Dodati leću i vodu.', 'Kuhati oko 25 minuta do mekoće.', 'Začiniti soli i poslužiti s rižom.'],
      ba: ['Luk, bijeli luk i đumbir popržiti na ulju.', 'Začine kratko popržiti.', 'Dodati leću i vodu.', 'Kuhati oko 25 minuta do mekoće.', 'Začiniti soli i poslužiti sa rižom.'],
      en: ['Fry onion, garlic and ginger in oil.', 'Toast the spices briefly.', 'Add the lentils and water.', 'Simmer soft for about 25 minutes.', 'Season with salt and serve with rice.']
    }
  },

  {
    id: 'chicken_biryani', kueche: 'indisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Chicken Biryani', sr: 'Пилећи бирјани', hr: 'Pileći biryani', ba: 'Pileći biryani', en: 'Chicken biryani' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Basmatireis', sr: 'басмати пиринач', hr: 'basmati riža', ba: 'basmati riža', en: 'basmati rice' } },
      { menge: 500, einheit: 'g', name: { de: 'Hähnchen', sr: 'пилетина', hr: 'piletina', ba: 'piletina', en: 'chicken' } },
      { menge: 200, einheit: 'g', name: { de: 'Joghurt', sr: 'јогурт', hr: 'jogurt', ba: 'jogurt', en: 'yoghurt' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 2, einheit: 'el', name: { de: 'Biryani-Gewürz', sr: 'бирјани зачин', hr: 'biryani začin', ba: 'biryani začin', en: 'biryani spice' } },
      { menge: 1, einheit: 'prise', name: { de: 'Safran', sr: 'шафран', hr: 'šafran', ba: 'šafran', en: 'saffron' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Öl', sr: 'со, уље', hr: 'sol, ulje', ba: 'so, ulje', en: 'salt, oil' } }
    ],
    schritte: {
      de: ['Hähnchen im Joghurt mit Gewürzen marinieren.', 'Zwiebeln goldbraun braten.', 'Hähnchen anbraten.', 'Reis halbgar kochen und über das Fleisch schichten.', 'Zugedeckt bei kleiner Hitze ca. 20 Minuten dämpfen.'],
      sr: ['Пилетину маринирати у јогурту са зачинима.', 'Лук испржити до златне боје.', 'Пилетину пропржити.', 'Пиринач полукувати и наслагати преко меса.', 'Поклопљено на тихој ватри парити око 20 минута.'],
      hr: ['Piletinu marinirati u jogurtu sa začinima.', 'Luk ispržiti do zlatne boje.', 'Piletinu popržiti.', 'Rižu polukuhati i naslagati preko mesa.', 'Poklopljeno na laganoj vatri pariti oko 20 minuta.'],
      ba: ['Piletinu marinirati u jogurtu sa začinima.', 'Luk ispržiti do zlatne boje.', 'Piletinu popržiti.', 'Rižu polukuhati i naslagati preko mesa.', 'Poklopljeno na laganoj vatri pariti oko 20 minuta.'],
      en: ['Marinate the chicken in yoghurt with spices.', 'Fry the onions golden.', 'Sear the chicken.', 'Parboil the rice and layer over the meat.', 'Steam covered on low heat for about 20 minutes.']
    }
  },

  {
    id: 'samosa', kueche: 'indisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Samosa', sr: 'Самоса', hr: 'Samosa', ba: 'Samosa', en: 'Samosa' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 400, einheit: 'g', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 100, einheit: 'g', name: { de: 'Erbsen', sr: 'грашак', hr: 'grašak', ba: 'grašak', en: 'peas' } },
      { menge: 1, einheit: 'tl', name: { de: 'Currypulver', sr: 'кари прах', hr: 'curry u prahu', ba: 'curry u prahu', en: 'curry powder' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kreuzkümmel', sr: 'ким', hr: 'kim', ba: 'kim', en: 'cumin' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Öl zum Frittieren', sr: 'со, уље за пржење', hr: 'sol, ulje za prženje', ba: 'so, ulje za prženje', en: 'salt, oil for frying' } }
    ],
    schritte: {
      de: ['Aus Mehl, Wasser und Salz einen Teig kneten.', 'Kartoffeln kochen, zerdrücken und mit Erbsen und Gewürzen mischen.', 'Teig ausrollen, Dreiecke formen und füllen.', 'Ränder gut verschließen.', 'In heißem Öl goldbraun frittieren.'],
      sr: ['Од брашна, воде и соли умесити тесто.', 'Кромпир скувати, изгњечити и помешати са грашком и зачинима.', 'Тесто развући, обликовати троуглове и напунити.', 'Ивице добро затворити.', 'Пржити у врелом уљу до златне боје.'],
      hr: ['Od brašna, vode i soli umijesiti tijesto.', 'Krumpir skuhati, izgnječiti i pomiješati s graškom i začinima.', 'Tijesto razvući, oblikovati trokute i napuniti.', 'Rubove dobro zatvoriti.', 'Pržiti u vrućem ulju do zlatne boje.'],
      ba: ['Od brašna, vode i soli umijesiti tijesto.', 'Krompir skuhati, izgnječiti i pomiješati sa graškom i začinima.', 'Tijesto razvući, oblikovati trokute i napuniti.', 'Rubove dobro zatvoriti.', 'Pržiti u vrućem ulju do zlatne boje.'],
      en: ['Knead a dough from flour, water and salt.', 'Boil the potatoes, mash and mix with peas and spices.', 'Roll out the dough, form triangles and fill.', 'Seal the edges well.', 'Deep-fry in hot oil until golden.']
    }
  },

  {
    id: 'palak_paneer', kueche: 'indisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Palak Paneer', sr: 'Палак панир', hr: 'Palak paneer', ba: 'Palak paneer', en: 'Palak paneer' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Spinat', sr: 'спанаћ', hr: 'špinat', ba: 'špinat', en: 'spinach' } },
      { menge: 250, einheit: 'g', name: { de: 'Paneer (Käse)', sr: 'панир (сир)', hr: 'paneer (sir)', ba: 'paneer (sir)', en: 'paneer (cheese)' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 100, einheit: 'ml', name: { de: 'Sahne', sr: 'павлака за кување', hr: 'vrhnje za kuhanje', ba: 'pavlaka za kuhanje', en: 'cream' } },
      { menge: 1, einheit: 'tl', name: { de: 'Garam Masala', sr: 'гарам масала', hr: 'garam masala', ba: 'garam masala', en: 'garam masala' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Ingwer', sr: 'со, ђумбир', hr: 'sol, đumbir', ba: 'so, đumbir', en: 'salt, ginger' } }
    ],
    schritte: {
      de: ['Spinat blanchieren und fein pürieren.', 'Zwiebel, Knoblauch und Ingwer anbraten.', 'Gewürze und Spinatpüree zugeben.', 'Paneer würfeln und unterheben.', 'Sahne einrühren, würzen und mit Reis servieren.'],
      sr: ['Спанаћ бланширати и фино изблендати.', 'Пропржити лук, бели лук и ђумбир.', 'Додати зачине и пире од спанаћа.', 'Панир исецкати и умешати.', 'Умешати павлаку, зачинити и послужити са пиринчем.'],
      hr: ['Špinat blanširati i fino izblendati.', 'Popržiti luk, češnjak i đumbir.', 'Dodati začine i pire od špinata.', 'Paneer narezati i umiješati.', 'Umiješati vrhnje, začiniti i poslužiti s rižom.'],
      ba: ['Špinat blanširati i fino izblendati.', 'Popržiti luk, bijeli luk i đumbir.', 'Dodati začine i pire od špinata.', 'Paneer narezati i umiješati.', 'Umiješati pavlaku, začiniti i poslužiti sa rižom.'],
      en: ['Blanch the spinach and purée finely.', 'Fry onion, garlic and ginger.', 'Add spices and the spinach purée.', 'Dice the paneer and fold in.', 'Stir in cream, season and serve with rice.']
    }
  },

  {
    id: 'chana_masala', kueche: 'indisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Chana Masala', sr: 'Чана масала', hr: 'Chana masala', ba: 'Chana masala', en: 'Chana masala' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Kichererbsen (gekocht)', sr: 'кувана леблебија', hr: 'kuhani slanutak', ba: 'kuhani slanutak', en: 'cooked chickpeas' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 2, einheit: 'tl', name: { de: 'Garam Masala', sr: 'гарам масала', hr: 'garam masala', ba: 'garam masala', en: 'garam masala' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kurkuma', sr: 'куркума', hr: 'kurkuma', ba: 'kurkuma', en: 'turmeric' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Ingwer, Öl', sr: 'со, ђумбир, уље', hr: 'sol, đumbir, ulje', ba: 'so, đumbir, ulje', en: 'salt, ginger, oil' } }
    ],
    schritte: {
      de: ['Zwiebeln, Knoblauch und Ingwer in Öl anbraten.', 'Gewürze zugeben und kurz rösten.', 'Tomaten zugeben und 5 Minuten köcheln.', 'Kichererbsen zugeben und 15 Minuten schmoren.', 'Mit Salz abschmecken und mit Reis oder Naan servieren.'],
      sr: ['Лук, бели лук и ђумбир пропржити на уљу.', 'Додати зачине и кратко пропржити.', 'Додати парадајз и кувати 5 минута.', 'Додати леблебију и динстати 15 минута.', 'Зачинити сољу и послужити са пиринчем или наан хлебом.'],
      hr: ['Luk, češnjak i đumbir popržiti na ulju.', 'Dodati začine i kratko popržiti.', 'Dodati rajčice i kuhati 5 minuta.', 'Dodati slanutak i pirjati 15 minuta.', 'Začiniti soli i poslužiti s rižom ili naan kruhom.'],
      ba: ['Luk, bijeli luk i đumbir popržiti na ulju.', 'Dodati začine i kratko popržiti.', 'Dodati paradajz i kuhati 5 minuta.', 'Dodati slanutak i dinstati 15 minuta.', 'Začiniti soli i poslužiti sa rižom ili naan hljebom.'],
      en: ['Fry onions, garlic and ginger in oil.', 'Add the spices and toast briefly.', 'Add the tomatoes and simmer for 5 minutes.', 'Add the chickpeas and stew for 15 minutes.', 'Season with salt and serve with rice or naan.']
    }
  },

  // ---- NACHSCHLAG (gemischt) -----------------------------------------------
  {
    id: 'pljeskavica', kueche: 'balkan', portionen: 4, dauer_min: 30,
    titel: { de: 'Pljeskavica', sr: 'Пљескавица', hr: 'Pljeskavica', ba: 'Pljeskavica', en: 'Pljeskavica' },
    zutaten: [
      { menge: 700, einheit: 'g', name: { de: 'gemischtes Hackfleisch', sr: 'мешано млевено месо', hr: 'miješano mljeveno meso', ba: 'miješano mljeveno meso', en: 'mixed minced meat' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'tl', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Zwiebel und Knoblauch sehr fein hacken.', 'Mit Hackfleisch und Gewürzen gut durchkneten.', 'Mindestens 1 Stunde kalt ruhen lassen.', 'Zu großen, flachen Fladen formen.', 'Auf dem Grill oder in der Pfanne beidseitig braten.'],
      sr: ['Лук и бели лук веома ситно исецкати.', 'Добро умесити са млевеним месом и зачинима.', 'Оставити у фрижидеру најмање 1 сат.', 'Обликовати велике, плоснате пљескавице.', 'Пећи на роштиљу или у тигању са обе стране.'],
      hr: ['Luk i češnjak vrlo sitno nasjeckati.', 'Dobro umijesiti s mljevenim mesom i začinima.', 'Ostaviti u hladnjaku najmanje 1 sat.', 'Oblikovati velike, plosnate pljeskavice.', 'Peći na roštilju ili u tavi s obje strane.'],
      ba: ['Luk i bijeli luk vrlo sitno nasjeckati.', 'Dobro umijesiti sa mljevenim mesom i začinima.', 'Ostaviti u frižideru najmanje 1 sat.', 'Oblikovati velike, plosnate pljeskavice.', 'Peći na roštilju ili u tavi sa obje strane.'],
      en: ['Chop the onion and garlic very finely.', 'Knead well with the minced meat and spices.', 'Rest in the fridge for at least 1 hour.', 'Form large, flat patties.', 'Grill or pan-fry on both sides.']
    }
  },

  {
    id: 'sataras', kueche: 'balkan', portionen: 4, dauer_min: 40,
    titel: { de: 'Sataraš', sr: 'Сатараш', hr: 'Sataraš', ba: 'Sataraš', en: 'Sataraš' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell peppers' } },
      { menge: 4, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Salz, Pfeffer', sr: 'уље, со, бибер', hr: 'ulje, sol, papar', ba: 'ulje, so, biber', en: 'oil, salt, pepper' } }
    ],
    schritte: {
      de: ['Zwiebeln in Öl glasig dünsten.', 'Paprika zugeben und andünsten.', 'Tomaten zugeben und 15 Minuten schmoren.', 'Mit Salz und Pfeffer würzen.', 'Verquirlte Eier unterrühren und stocken lassen.'],
      sr: ['Лук продинстати на уљу до стакластости.', 'Додати паприку и продинстати.', 'Додати парадајз и динстати 15 минута.', 'Зачинити сољу и бибером.', 'Умешати умућена јаја и оставити да се стегну.'],
      hr: ['Luk popirjati na ulju do staklastosti.', 'Dodati papriku i popirjati.', 'Dodati rajčice i pirjati 15 minuta.', 'Začiniti soli i paprom.', 'Umiješati umućena jaja i ostaviti da se stegnu.'],
      ba: ['Luk podinstati na ulju do staklastosti.', 'Dodati papriku i podinstati.', 'Dodati paradajz i dinstati 15 minuta.', 'Začiniti soli i biberom.', 'Umiješati umućena jaja i ostaviti da se stegnu.'],
      en: ['Sweat the onions in oil until translucent.', 'Add the peppers and sauté.', 'Add the tomatoes and stew for 15 minutes.', 'Season with salt and pepper.', 'Stir in the beaten eggs and let set.']
    }
  },

  {
    id: 'proja', kueche: 'balkan', portionen: 6, dauer_min: 45,
    titel: { de: 'Proja (Maisbrot)', sr: 'Проја', hr: 'Proja (kruh od kukuruza)', ba: 'Proja (hljeb od kukuruza)', en: 'Proja (cornbread)' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Maismehl', sr: 'кукурузно брашно', hr: 'kukuruzno brašno', ba: 'kukuruzno brašno', en: 'cornmeal' } },
      { menge: 200, einheit: 'g', name: { de: 'Weißkäse', sr: 'бели сир', hr: 'bijeli sir', ba: 'bijeli sir', en: 'white cheese' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 200, einheit: 'ml', name: { de: 'Joghurt', sr: 'јогурт', hr: 'jogurt', ba: 'jogurt', en: 'yoghurt' } },
      { menge: 100, einheit: 'ml', name: { de: 'Öl', sr: 'уље', hr: 'ulje', ba: 'ulje', en: 'oil' } },
      { menge: 1, einheit: 'tl', name: { de: 'Backpulver', sr: 'прашак за пециво', hr: 'prašak za pecivo', ba: 'prašak za pecivo', en: 'baking powder' } }
    ],
    schritte: {
      de: ['Eier mit Joghurt und Öl verquirlen.', 'Maismehl, Backpulver und zerbröckelten Käse zugeben.', 'Zu einem dickflüssigen Teig verrühren.', 'In eine gefettete Form füllen.', 'Bei 200 Grad ca. 30 Minuten goldbraun backen.'],
      sr: ['Јаја умутити са јогуртом и уљем.', 'Додати кукурузно брашно, прашак за пециво и измрвљени сир.', 'Умутити у густо тесто.', 'Сипати у подмазан калуп.', 'Пећи на 200 степени око 30 минута до златне боје.'],
      hr: ['Jaja umutiti s jogurtom i uljem.', 'Dodati kukuruzno brašno, prašak za pecivo i izmrvljeni sir.', 'Umutiti u gusto tijesto.', 'Uliti u podmazan kalup.', 'Peći na 200 stupnjeva oko 30 minuta do zlatne boje.'],
      ba: ['Jaja umutiti sa jogurtom i uljem.', 'Dodati kukuruzno brašno, prašak za pecivo i izmrvljeni sir.', 'Umutiti u gusto tijesto.', 'Uliti u podmazan kalup.', 'Peći na 200 stepeni oko 30 minuta do zlatne boje.'],
      en: ['Whisk eggs with yoghurt and oil.', 'Add cornmeal, baking powder and crumbled cheese.', 'Mix into a thick batter.', 'Pour into a greased tin.', 'Bake at 200 degrees for about 30 minutes until golden.']
    }
  },

  {
    id: 'penne_arrabiata', kueche: 'italienisch', portionen: 4, dauer_min: 25,
    titel: { de: 'Penne all\'Arrabbiata', sr: 'Пене арабијата', hr: 'Penne arrabbiata', ba: 'Penne arrabbiata', en: 'Penne arrabbiata' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Penne', sr: 'пене тестенина', hr: 'penne tjestenina', ba: 'penne tjestenina', en: 'penne pasta' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 3, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'stk', name: { de: 'Chilischote', sr: 'љута папричица', hr: 'ljuta papričica', ba: 'ljuta papričica', en: 'chilli' } },
      { menge: 3, einheit: 'el', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Petersilie', sr: 'со, першун', hr: 'sol, peršin', ba: 'so, peršun', en: 'salt, parsley' } }
    ],
    schritte: {
      de: ['Penne in Salzwasser al dente kochen.', 'Knoblauch und Chili in Olivenöl anbraten.', 'Tomaten zugeben und 10 Minuten köcheln.', 'Mit Salz abschmecken.', 'Nudeln unterheben und mit Petersilie servieren.'],
      sr: ['Пене скувати у сланој води ал денте.', 'Бели лук и чили пропржити на маслиновом уљу.', 'Додати парадајз и кувати 10 минута.', 'Зачинити сољу.', 'Умешати тестенину и послужити са першуном.'],
      hr: ['Penne skuhati u slanoj vodi al dente.', 'Češnjak i čili popržiti na maslinovom ulju.', 'Dodati rajčice i kuhati 10 minuta.', 'Začiniti soli.', 'Umiješati tjesteninu i poslužiti s peršinom.'],
      ba: ['Penne skuhati u slanoj vodi al dente.', 'Bijeli luk i čili popržiti na maslinovom ulju.', 'Dodati paradajz i kuhati 10 minuta.', 'Začiniti soli.', 'Umiješati tjesteninu i poslužiti sa peršunom.'],
      en: ['Cook the penne al dente in salted water.', 'Fry garlic and chilli in olive oil.', 'Add the tomatoes and simmer for 10 minutes.', 'Season with salt.', 'Fold in the pasta and serve with parsley.']
    }
  },

  {
    id: 'saltimbocca', kueche: 'italienisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Saltimbocca', sr: 'Салтимбока', hr: 'Saltimbocca', ba: 'Saltimbocca', en: 'Saltimbocca' },
    zutaten: [
      { menge: 8, einheit: 'stk', name: { de: 'Kalbsschnitzel (dünn)', sr: 'танки телећи шницли', hr: 'tanki teleći odresci', ba: 'tanki teleći odresci', en: 'thin veal escalopes' } },
      { menge: 8, einheit: 'stk', name: { de: 'Scheiben Parmaschinken', sr: 'кришке пршуте', hr: 'kriške pršuta', ba: 'kriške pršuta', en: 'slices of parma ham' } },
      { menge: 8, einheit: 'stk', name: { de: 'Salbeiblätter', sr: 'листови жалфије', hr: 'listovi kadulje', ba: 'listovi žalfije', en: 'sage leaves' } },
      { menge: 100, einheit: 'ml', name: { de: 'Weißwein', sr: 'бело вино', hr: 'bijelo vino', ba: 'bijelo vino', en: 'white wine' } },
      { menge: 40, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Mehl', sr: 'со, бибер, брашно', hr: 'sol, papar, brašno', ba: 'so, biber, brašno', en: 'salt, pepper, flour' } }
    ],
    schritte: {
      de: ['Schnitzel flach klopfen und leicht mehlieren.', 'Je eine Scheibe Schinken und ein Salbeiblatt auflegen und feststecken.', 'In Butter beidseitig braten.', 'Mit Weißwein ablöschen.', 'Sauce kurz einkochen und servieren.'],
      sr: ['Шницле истањити и лагано побрашнити.', 'На сваки ставити кришку пршуте и лист жалфије и причврстити.', 'Пржити у путеру са обе стране.', 'Залити белим вином.', 'Сос кратко укувати и послужити.'],
      hr: ['Odreske stanjiti i lagano pobrašniti.', 'Na svaki staviti krišku pršuta i list kadulje i pričvrstiti.', 'Pržiti u maslacu s obje strane.', 'Zaliti bijelim vinom.', 'Umak kratko ukuhati i poslužiti.'],
      ba: ['Odreske stanjiti i lagano pobrašniti.', 'Na svaki staviti krišku pršuta i list žalfije i pričvrstiti.', 'Pržiti u maslacu sa obje strane.', 'Zaliti bijelim vinom.', 'Sos kratko ukuhati i poslužiti.'],
      en: ['Pound the escalopes flat and dust lightly with flour.', 'Top each with a slice of ham and a sage leaf and pin.', 'Fry in butter on both sides.', 'Deglaze with white wine.', 'Reduce the sauce briefly and serve.']
    }
  },

  {
    id: 'panna_cotta', kueche: 'italienisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Panna Cotta', sr: 'Пана кота', hr: 'Panna cotta', ba: 'Panna cotta', en: 'Panna cotta' },
    zutaten: [
      { menge: 500, einheit: 'ml', name: { de: 'Sahne', sr: 'слатка павлака', hr: 'slatko vrhnje', ba: 'slatka pavlaka', en: 'cream' } },
      { menge: 60, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 3, einheit: 'stk', name: { de: 'Blatt Gelatine', sr: 'листа желатина', hr: 'lista želatine', ba: 'lista želatine', en: 'gelatine leaves' } },
      { menge: 1, einheit: 'stk', name: { de: 'Vanilleschote', sr: 'махуна ваниле', hr: 'mahuna vanilije', ba: 'mahuna vanilije', en: 'vanilla pod' } },
      { menge: 100, einheit: 'g', name: { de: 'Beeren', sr: 'бобичасто воће', hr: 'bobičasto voće', ba: 'bobičasto voće', en: 'berries' } }
    ],
    schritte: {
      de: ['Gelatine in kaltem Wasser einweichen.', 'Sahne mit Zucker und Vanille erwärmen, nicht kochen.', 'Ausgedrückte Gelatine darin auflösen.', 'In Förmchen füllen und mindestens 4 Stunden kalt stellen.', 'Mit Beeren serviert stürzen.'],
      sr: ['Желатин потопити у хладну воду.', 'Павлаку са шећером и ванилом загрејати, не кувати.', 'Оцеђени желатин растворити у њој.', 'Сипати у калупчиће и ставити у фрижидер најмање 4 сата.', 'Извадити из калупа и послужити са бобичастим воћем.'],
      hr: ['Želatinu namočiti u hladnu vodu.', 'Vrhnje sa šećerom i vanilijom zagrijati, ne kuhati.', 'Ocijeđenu želatinu otopiti u njemu.', 'Uliti u kalupe i staviti u hladnjak najmanje 4 sata.', 'Izvaditi iz kalupa i poslužiti s bobičastim voćem.'],
      ba: ['Želatinu namočiti u hladnu vodu.', 'Pavlaku sa šećerom i vanilijom zagrijati, ne kuhati.', 'Ocijeđenu želatinu otopiti u njoj.', 'Uliti u kalupe i staviti u frižider najmanje 4 sata.', 'Izvaditi iz kalupa i poslužiti sa bobičastim voćem.'],
      en: ['Soak the gelatine in cold water.', 'Warm the cream with sugar and vanilla, do not boil.', 'Dissolve the squeezed gelatine in it.', 'Pour into moulds and chill for at least 4 hours.', 'Turn out and serve with berries.']
    }
  },

  {
    id: 'currywurst', kueche: 'deutsch', portionen: 2, dauer_min: 20,
    titel: { de: 'Currywurst', sr: 'Кари кобасица', hr: 'Currywurst', ba: 'Currywurst', en: 'Currywurst' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Bratwürste', sr: 'кобасице за пржење', hr: 'kobasice za prženje', ba: 'kobasice za prženje', en: 'sausages' } },
      { menge: 200, einheit: 'ml', name: { de: 'Ketchup', sr: 'кечап', hr: 'kečap', ba: 'kečap', en: 'ketchup' } },
      { menge: 2, einheit: 'el', name: { de: 'Currypulver', sr: 'кари прах', hr: 'curry u prahu', ba: 'curry u prahu', en: 'curry powder' } },
      { menge: 1, einheit: 'tl', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl', sr: 'уље', hr: 'ulje', ba: 'ulje', en: 'oil' } }
    ],
    schritte: {
      de: ['Würste in Öl rundum knusprig braten.', 'Ketchup mit einem Teil Currypulver und Paprika erwärmen.', 'Würste in Scheiben schneiden.', 'Mit der Sauce übergießen.', 'Mit restlichem Currypulver bestäuben und mit Pommes servieren.'],
      sr: ['Кобасице пржити на уљу до хрскавости са свих страна.', 'Кечап загрејати са делом кари праха и алевом паприком.', 'Кобасице исећи на кришке.', 'Прелити сосом.', 'Посути преосталим кари прахом и послужити са помфритом.'],
      hr: ['Kobasice pržiti na ulju do hrskavosti sa svih strana.', 'Kečap zagrijati s dijelom currya i mljevenom paprikom.', 'Kobasice narezati na kriške.', 'Preliti umakom.', 'Posuti preostalim curryem i poslužiti s pomfritom.'],
      ba: ['Kobasice pržiti na ulju do hrskavosti sa svih strana.', 'Kečap zagrijati sa dijelom currya i mljevenom paprikom.', 'Kobasice narezati na kriške.', 'Preliti sosom.', 'Posuti preostalim curryem i poslužiti sa pomfritom.'],
      en: ['Fry the sausages crisp all over in oil.', 'Warm the ketchup with part of the curry powder and paprika.', 'Slice the sausages.', 'Pour the sauce over.', 'Dust with the rest of the curry powder and serve with fries.']
    }
  },

  {
    id: 'kartoffelgratin', kueche: 'deutsch', portionen: 4, dauer_min: 70,
    titel: { de: 'Kartoffelgratin', sr: 'Гратиниран кромпир', hr: 'Gratinirani krumpir', ba: 'Gratinirani krompir', en: 'Potato gratin' },
    zutaten: [
      { menge: 1, einheit: 'kg', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 300, einheit: 'ml', name: { de: 'Sahne', sr: 'слатка павлака', hr: 'slatko vrhnje', ba: 'slatka pavlaka', en: 'cream' } },
      { menge: 150, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: 1, einheit: 'zehe', name: { de: 'Knoblauchzehe', sr: 'чен белог лука', hr: 'češanj češnjaka', ba: 'čehno bijelog luka', en: 'garlic clove' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Muskat', sr: 'со, бибер, мушкатни орашчић', hr: 'sol, papar, muškatni oraščić', ba: 'so, biber, muškatni oraščić', en: 'salt, pepper, nutmeg' } }
    ],
    schritte: {
      de: ['Kartoffeln in dünne Scheiben schneiden.', 'Form mit Knoblauch ausreiben.', 'Kartoffeln einschichten, mit Salz, Pfeffer und Muskat würzen.', 'Sahne angießen und mit Käse bestreuen.', 'Bei 180 Grad ca. 50 Minuten goldbraun backen.'],
      sr: ['Кромпир исећи на танке кришке.', 'Калуп натрљати белим луком.', 'Кромпир слагати, зачинити сољу, бибером и мушкатним орашчићем.', 'Прелити павлаком и посути сиром.', 'Пећи на 180 степени око 50 минута до златне боје.'],
      hr: ['Krumpir narezati na tanke kriške.', 'Kalup natrljati češnjakom.', 'Krumpir slagati, začiniti soli, paprom i muškatnim oraščićem.', 'Preliti vrhnjem i posuti sirom.', 'Peći na 180 stupnjeva oko 50 minuta do zlatne boje.'],
      ba: ['Krompir narezati na tanke kriške.', 'Kalup natrljati bijelim lukom.', 'Krompir slagati, začiniti soli, biberom i muškatnim oraščićem.', 'Preliti pavlakom i posuti sirom.', 'Peći na 180 stepeni oko 50 minuta do zlatne boje.'],
      en: ['Slice the potatoes thinly.', 'Rub the dish with garlic.', 'Layer the potatoes, season with salt, pepper and nutmeg.', 'Pour in the cream and sprinkle with cheese.', 'Bake at 180 degrees for about 50 minutes until golden.']
    }
  },

  {
    id: 'apfelstrudel', kueche: 'deutsch', portionen: 6, dauer_min: 60,
    titel: { de: 'Apfelstrudel', sr: 'Штрудла са јабукама', hr: 'Štrudla od jabuka', ba: 'Štrudla sa jabukama', en: 'Apple strudel' },
    zutaten: [
      { menge: 1, einheit: 'stk', name: { de: 'Strudelteig (Blätterteig)', sr: 'вучено (лиснато) тесто', hr: 'vučeno (lisnato) tijesto', ba: 'vučeno (lisnato) tijesto', en: 'strudel (puff) pastry' } },
      { menge: 800, einheit: 'g', name: { de: 'Äpfel', sr: 'јабуке', hr: 'jabuke', ba: 'jabuke', en: 'apples' } },
      { menge: 80, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 60, einheit: 'g', name: { de: 'Rosinen', sr: 'суво грожђе', hr: 'grožđice', ba: 'suho grožđe', en: 'raisins' } },
      { menge: 1, einheit: 'tl', name: { de: 'Zimt', sr: 'цимет', hr: 'cimet', ba: 'cimet', en: 'cinnamon' } },
      { menge: 50, einheit: 'g', name: { de: 'Semmelbrösel', sr: 'презле', hr: 'krušne mrvice', ba: 'prezle', en: 'breadcrumbs' } }
    ],
    schritte: {
      de: ['Äpfel schälen und in dünne Scheiben schneiden.', 'Mit Zucker, Zimt und Rosinen mischen.', 'Teig ausrollen und mit Bröseln bestreuen.', 'Füllung auflegen und einrollen.', 'Bei 190 Grad ca. 35 Minuten goldbraun backen.'],
      sr: ['Јабуке огулити и исећи на танке кришке.', 'Помешати са шећером, циметом и сувим грожђем.', 'Тесто развући и посути презлама.', 'Ставити фил и уролати.', 'Пећи на 190 степени око 35 минута до златне боје.'],
      hr: ['Jabuke oguliti i narezati na tanke kriške.', 'Pomiješati sa šećerom, cimetom i grožđicama.', 'Tijesto razvući i posuti mrvicama.', 'Staviti nadjev i urolati.', 'Peći na 190 stupnjeva oko 35 minuta do zlatne boje.'],
      ba: ['Jabuke oguliti i narezati na tanke kriške.', 'Pomiješati sa šećerom, cimetom i suhim grožđem.', 'Tijesto razvući i posuti prezlama.', 'Staviti nadjev i urolati.', 'Peći na 190 stepeni oko 35 minuta do zlatne boje.'],
      en: ['Peel the apples and slice thinly.', 'Mix with sugar, cinnamon and raisins.', 'Roll out the pastry and sprinkle with breadcrumbs.', 'Add the filling and roll up.', 'Bake at 190 degrees for about 35 minutes until golden.']
    }
  },

  {
    id: 'gemuesesuppe', kueche: 'international', portionen: 4, dauer_min: 35,
    titel: { de: 'Gemüsesuppe', sr: 'Супа од поврћа', hr: 'Juha od povrća', ba: 'Supa od povrća', en: 'Vegetable soup' },
    zutaten: [
      { menge: 3, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 2, einheit: 'stk', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Lauchstange', sr: 'празилук', hr: 'poriluk', ba: 'praziluk', en: 'leek' } },
      { menge: 150, einheit: 'g', name: { de: 'Erbsen', sr: 'грашак', hr: 'grašak', ba: 'grašak', en: 'peas' } },
      { menge: 1200, einheit: 'ml', name: { de: 'Gemüsebrühe', sr: 'повртна супа', hr: 'povrtni temeljac', ba: 'povrtna supa', en: 'vegetable broth' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Petersilie', sr: 'со, бибер, першун', hr: 'sol, papar, peršin', ba: 'so, biber, peršun', en: 'salt, pepper, parsley' } }
    ],
    schritte: {
      de: ['Gemüse in kleine Würfel schneiden.', 'Kurz in etwas Öl andünsten.', 'Mit Gemüsebrühe aufgießen.', 'Ca. 20 Minuten köcheln, bis das Gemüse weich ist.', 'Mit Salz, Pfeffer und Petersilie abschmecken.'],
      sr: ['Поврће исећи на ситне коцкице.', 'Кратко продинстати на мало уља.', 'Залити повртном супом.', 'Кувати око 20 минута док поврће не омекша.', 'Зачинити сољу, бибером и першуном.'],
      hr: ['Povrće narezati na sitne kockice.', 'Kratko popirjati na malo ulja.', 'Zaliti povrtnim temeljcem.', 'Kuhati oko 20 minuta dok povrće ne omekša.', 'Začiniti soli, paprom i peršinom.'],
      ba: ['Povrće narezati na sitne kockice.', 'Kratko podinstati na malo ulja.', 'Zaliti povrtnom supom.', 'Kuhati oko 20 minuta dok povrće ne omekša.', 'Začiniti soli, biberom i peršunom.'],
      en: ['Cut the vegetables into small cubes.', 'Sauté briefly in a little oil.', 'Pour in the vegetable broth.', 'Simmer for about 20 minutes until the vegetables are soft.', 'Season with salt, pepper and parsley.']
    }
  },

  // ---- JAPANISCH -----------------------------------------------------------
  {
    id: 'sushi_maki', kueche: 'japanisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Maki-Sushi', sr: 'Маки суши', hr: 'Maki sushi', ba: 'Maki sushi', en: 'Maki sushi' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Sushireis', sr: 'суши пиринач', hr: 'sushi riža', ba: 'sushi riža', en: 'sushi rice' } },
      { menge: 4, einheit: 'stk', name: { de: 'Noriblätter', sr: 'нори листови', hr: 'nori listovi', ba: 'nori listovi', en: 'nori sheets' } },
      { menge: 200, einheit: 'g', name: { de: 'Lachs oder Gurke', sr: 'лосос или краставац', hr: 'losos ili krastavac', ba: 'losos ili krastavac', en: 'salmon or cucumber' } },
      { menge: 3, einheit: 'el', name: { de: 'Reisessig', sr: 'пиринчано сирће', hr: 'rižin ocat', ba: 'rižino sirće', en: 'rice vinegar' } },
      { menge: 1, einheit: 'el', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: null, einheit: 'ng', name: { de: 'Sojasauce, Wasabi', sr: 'соја сос, васаби', hr: 'soja umak, wasabi', ba: 'soja sos, wasabi', en: 'soy sauce, wasabi' } }
    ],
    schritte: {
      de: ['Reis waschen und garen.', 'Mit Essig und Zucker mischen und abkühlen lassen.', 'Nori auf eine Matte legen und Reis verteilen.', 'Füllung auflegen und fest aufrollen.', 'In Stücke schneiden und mit Sojasauce servieren.'],
      sr: ['Пиринач опрати и скувати.', 'Помешати са сирћетом и шећером и охладити.', 'Нори ставити на подлогу и распоредити пиринач.', 'Ставити фил и чврсто уролати.', 'Исећи на комаде и послужити са соја сосом.'],
      hr: ['Rižu oprati i skuhati.', 'Pomiješati s octom i šećerom i ohladiti.', 'Nori staviti na podlogu i rasporediti rižu.', 'Staviti nadjev i čvrsto urolati.', 'Narezati na komade i poslužiti sa soja umakom.'],
      ba: ['Rižu oprati i skuhati.', 'Pomiješati sa sirćetom i šećerom i ohladiti.', 'Nori staviti na podlogu i rasporediti rižu.', 'Staviti nadjev i čvrsto urolati.', 'Narezati na komade i poslužiti sa soja sosom.'],
      en: ['Wash and cook the rice.', 'Mix with vinegar and sugar and let cool.', 'Place nori on a mat and spread the rice.', 'Add the filling and roll up tightly.', 'Cut into pieces and serve with soy sauce.']
    }
  },

  {
    id: 'ramen', kueche: 'japanisch', portionen: 2, dauer_min: 40,
    titel: { de: 'Ramen', sr: 'Рамен', hr: 'Ramen', ba: 'Ramen', en: 'Ramen' },
    zutaten: [
      { menge: 200, einheit: 'g', name: { de: 'Ramennudeln', sr: 'рамен резанци', hr: 'ramen rezanci', ba: 'ramen rezanci', en: 'ramen noodles' } },
      { menge: 1000, einheit: 'ml', name: { de: 'Brühe', sr: 'супа', hr: 'temeljac', ba: 'supa', en: 'broth' } },
      { menge: 2, einheit: 'el', name: { de: 'Miso-Paste', sr: 'мисо паста', hr: 'miso pasta', ba: 'miso pasta', en: 'miso paste' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 150, einheit: 'g', name: { de: 'Hähnchen oder Tofu', sr: 'пилетина или тофу', hr: 'piletina ili tofu', ba: 'piletina ili tofu', en: 'chicken or tofu' } },
      { menge: 2, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } }
    ],
    schritte: {
      de: ['Brühe erhitzen und Miso-Paste einrühren.', 'Eier wachsweich kochen und halbieren.', 'Hähnchen oder Tofu anbraten.', 'Nudeln separat garen und in Schalen verteilen.', 'Mit Brühe übergießen und mit Ei, Fleisch und Lauch anrichten.'],
      sr: ['Супу загрејати и умешати мисо пасту.', 'Јаја скувати да буду мекана и преполовити.', 'Пилетину или тофу пропржити.', 'Резанце посебно скувати и распоредити у чиније.', 'Прелити супом и украсити јајем, месом и младим луком.'],
      hr: ['Temeljac zagrijati i umiješati miso pastu.', 'Jaja skuhati da budu mekana i prepoloviti.', 'Piletinu ili tofu popržiti.', 'Rezance posebno skuhati i rasporediti u zdjele.', 'Preliti temeljcem i ukrasiti jajem, mesom i mladim lukom.'],
      ba: ['Supu zagrijati i umiješati miso pastu.', 'Jaja skuhati da budu mekana i prepoloviti.', 'Piletinu ili tofu popržiti.', 'Rezance posebno skuhati i rasporediti u zdjele.', 'Preliti supom i ukrasiti jajem, mesom i mladim lukom.'],
      en: ['Heat the broth and stir in the miso paste.', 'Soft-boil the eggs and halve them.', 'Fry the chicken or tofu.', 'Cook the noodles separately and divide into bowls.', 'Pour over the broth and top with egg, meat and spring onion.']
    }
  },

  {
    id: 'teriyaki_huhn', kueche: 'japanisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Teriyaki-Hähnchen', sr: 'Теријаки пилетина', hr: 'Teriyaki piletina', ba: 'Teriyaki piletina', en: 'Teriyaki chicken' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Hähnchenschenkel', sr: 'пилећи батаци', hr: 'pileći bataci', ba: 'pileći bataci', en: 'chicken thighs' } },
      { menge: 4, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 2, einheit: 'el', name: { de: 'Mirin', sr: 'мирин', hr: 'mirin', ba: 'mirin', en: 'mirin' } },
      { menge: 2, einheit: 'el', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 1, einheit: 'tl', name: { de: 'Ingwer', sr: 'ђумбир', hr: 'đumbir', ba: 'đumbir', en: 'ginger' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Sesam, Reis', sr: 'уље, сусам, пиринач', hr: 'ulje, sezam, riža', ba: 'ulje, susam, riža', en: 'oil, sesame, rice' } }
    ],
    schritte: {
      de: ['Sojasauce, Mirin, Zucker und Ingwer verrühren.', 'Hähnchen in Öl anbraten.', 'Sauce angießen und einkochen lassen.', 'Hähnchen darin glasieren.', 'Mit Sesam bestreut auf Reis servieren.'],
      sr: ['Умешати соја сос, мирин, шећер и ђумбир.', 'Пилетину пропржити на уљу.', 'Долити сос и оставити да се укува.', 'Пилетину глазирати у сосу.', 'Послужити на пиринчу посуто сусамом.'],
      hr: ['Umiješati soja umak, mirin, šećer i đumbir.', 'Piletinu popržiti na ulju.', 'Uliti umak i ostaviti da se ukuha.', 'Piletinu glazirati u umaku.', 'Poslužiti na riži posuto sezamom.'],
      ba: ['Umiješati soja sos, mirin, šećer i đumbir.', 'Piletinu popržiti na ulju.', 'Uliti sos i ostaviti da se ukuha.', 'Piletinu glazirati u sosu.', 'Poslužiti na riži posuto susamom.'],
      en: ['Mix soy sauce, mirin, sugar and ginger.', 'Fry the chicken in oil.', 'Add the sauce and let it reduce.', 'Glaze the chicken in it.', 'Serve on rice sprinkled with sesame.']
    }
  },

  {
    id: 'miso_suppe', kueche: 'japanisch', portionen: 4, dauer_min: 15,
    titel: { de: 'Miso-Suppe', sr: 'Мисо супа', hr: 'Miso juha', ba: 'Miso supa', en: 'Miso soup' },
    zutaten: [
      { menge: 1000, einheit: 'ml', name: { de: 'Dashi-Brühe', sr: 'даши супа', hr: 'dashi temeljac', ba: 'dashi supa', en: 'dashi broth' } },
      { menge: 3, einheit: 'el', name: { de: 'Miso-Paste', sr: 'мисо паста', hr: 'miso pasta', ba: 'miso pasta', en: 'miso paste' } },
      { menge: 150, einheit: 'g', name: { de: 'Tofu', sr: 'тофу', hr: 'tofu', ba: 'tofu', en: 'tofu' } },
      { menge: 10, einheit: 'g', name: { de: 'Wakame-Algen', sr: 'вакаме алге', hr: 'wakame alge', ba: 'wakame alge', en: 'wakame seaweed' } },
      { menge: 2, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } }
    ],
    schritte: {
      de: ['Dashi-Brühe erhitzen, nicht kochen.', 'Miso-Paste in etwas Brühe auflösen und einrühren.', 'Tofu würfeln und zugeben.', 'Wakame kurz ziehen lassen.', 'Mit Frühlingszwiebeln bestreut servieren.'],
      sr: ['Даши супу загрејати, не кувати.', 'Мисо пасту растворити у мало супе и умешати.', 'Тофу исецкати и додати.', 'Вакаме кратко оставити да одстоји.', 'Послужити посуто младим луком.'],
      hr: ['Dashi temeljac zagrijati, ne kuhati.', 'Miso pastu otopiti u malo temeljca i umiješati.', 'Tofu narezati i dodati.', 'Wakame kratko ostaviti da odstoji.', 'Poslužiti posuto mladim lukom.'],
      ba: ['Dashi supu zagrijati, ne kuhati.', 'Miso pastu otopiti u malo supe i umiješati.', 'Tofu narezati i dodati.', 'Wakame kratko ostaviti da odstoji.', 'Poslužiti posuto mladim lukom.'],
      en: ['Heat the dashi broth, do not boil.', 'Dissolve the miso paste in a little broth and stir in.', 'Dice the tofu and add.', 'Let the wakame steep briefly.', 'Serve sprinkled with spring onions.']
    }
  },

  {
    id: 'gyoza', kueche: 'japanisch', portionen: 4, dauer_min: 45,
    titel: { de: 'Gyoza', sr: 'Гјоза', hr: 'Gyoza', ba: 'Gyoza', en: 'Gyoza' },
    zutaten: [
      { menge: 24, einheit: 'stk', name: { de: 'Teigblätter', sr: 'листови теста', hr: 'listovi tijesta', ba: 'listovi tijesta', en: 'dumpling wrappers' } },
      { menge: 300, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 150, einheit: 'g', name: { de: 'Chinakohl', sr: 'кинески купус', hr: 'kineski kupus', ba: 'kineski kupus', en: 'chinese cabbage' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Ingwer', sr: 'уље, ђумбир', hr: 'ulje, đumbir', ba: 'ulje, đumbir', en: 'oil, ginger' } }
    ],
    schritte: {
      de: ['Kohl fein hacken und mit Hackfleisch, Knoblauch, Ingwer und Sojasauce mischen.', 'Teigblätter füllen und die Ränder verschließen.', 'In Öl mit der Unterseite anbraten.', 'Etwas Wasser zugeben und zugedeckt dämpfen.', 'Mit Dip servieren.'],
      sr: ['Купус ситно исецкати и помешати са месом, белим луком, ђумбиром и соја сосом.', 'Напунити листове теста и затворити ивице.', 'Пржити у уљу са доње стране.', 'Додати мало воде и парити поклопљено.', 'Послужити са дипом.'],
      hr: ['Kupus sitno nasjeckati i pomiješati s mesom, češnjakom, đumbirom i soja umakom.', 'Napuniti listove tijesta i zatvoriti rubove.', 'Pržiti u ulju s donje strane.', 'Dodati malo vode i pariti poklopljeno.', 'Poslužiti s umakom.'],
      ba: ['Kupus sitno nasjeckati i pomiješati sa mesom, bijelim lukom, đumbirom i soja sosom.', 'Napuniti listove tijesta i zatvoriti rubove.', 'Pržiti u ulju sa donje strane.', 'Dodati malo vode i pariti poklopljeno.', 'Poslužiti sa dipom.'],
      en: ['Finely chop the cabbage and mix with meat, garlic, ginger and soy sauce.', 'Fill the wrappers and seal the edges.', 'Fry in oil on the base.', 'Add a little water and steam covered.', 'Serve with a dip.']
    }
  },

  {
    id: 'katsu_curry', kueche: 'japanisch', portionen: 4, dauer_min: 45,
    titel: { de: 'Katsu Curry', sr: 'Кацу кари', hr: 'Katsu curry', ba: 'Katsu curry', en: 'Katsu curry' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Hähnchenbrust', sr: 'пилеће бело месо', hr: 'pileća prsa', ba: 'pileća prsa', en: 'chicken breasts' } },
      { menge: 100, einheit: 'g', name: { de: 'Panko-Brösel', sr: 'панко презле', hr: 'panko mrvice', ba: 'panko prezle', en: 'panko crumbs' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 2, einheit: 'el', name: { de: 'Currypulver', sr: 'кари прах', hr: 'curry u prahu', ba: 'curry u prahu', en: 'curry powder' } },
      { menge: 500, einheit: 'ml', name: { de: 'Brühe', sr: 'супа', hr: 'temeljac', ba: 'supa', en: 'stock' } },
      { menge: null, einheit: 'ng', name: { de: 'Ei, Mehl, Öl, Reis', sr: 'јаје, брашно, уље, пиринач', hr: 'jaje, brašno, ulje, riža', ba: 'jaje, brašno, ulje, riža', en: 'egg, flour, oil, rice' } }
    ],
    schritte: {
      de: ['Für die Sauce Zwiebel und Karotten anbraten, Curry zugeben.', 'Mit Brühe aufgießen und cremig einkochen.', 'Hähnchen in Mehl, Ei und Panko wenden.', 'In Öl goldbraun ausbacken und in Streifen schneiden.', 'Auf Reis mit Currysauce servieren.'],
      sr: ['За сос пропржити лук и шаргарепу, додати кари.', 'Залити супом и укувати до кремастости.', 'Пилетину уваљати у брашно, јаје и панко.', 'Испржити у уљу до златне боје и исећи на траке.', 'Послужити на пиринчу са кари сосом.'],
      hr: ['Za umak popržiti luk i mrkvu, dodati curry.', 'Zaliti temeljcem i ukuhati do kremastosti.', 'Piletinu uvaljati u brašno, jaje i panko.', 'Ispržiti u ulju do zlatne boje i narezati na trake.', 'Poslužiti na riži s curry umakom.'],
      ba: ['Za sos popržiti luk i mrkvu, dodati curry.', 'Zaliti supom i ukuhati do kremastosti.', 'Piletinu uvaljati u brašno, jaje i panko.', 'Ispržiti u ulju do zlatne boje i narezati na trake.', 'Poslužiti na riži sa curry sosom.'],
      en: ['For the sauce fry onion and carrots, add curry.', 'Pour in stock and reduce until creamy.', 'Coat the chicken in flour, egg and panko.', 'Fry golden in oil and cut into strips.', 'Serve on rice with the curry sauce.']
    }
  },

  {
    id: 'yakitori', kueche: 'japanisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Yakitori', sr: 'Јакитори', hr: 'Yakitori', ba: 'Yakitori', en: 'Yakitori' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Hähnchenschenkel', sr: 'пилећи батаци', hr: 'pileći bataci', ba: 'pileći bataci', en: 'chicken thighs' } },
      { menge: 4, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 2, einheit: 'el', name: { de: 'Mirin', sr: 'мирин', hr: 'mirin', ba: 'mirin', en: 'mirin' } },
      { menge: 1, einheit: 'el', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 3, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } }
    ],
    schritte: {
      de: ['Hähnchen in mundgerechte Stücke schneiden.', 'Mit Lauchstücken abwechselnd auf Spieße stecken.', 'Sojasauce, Mirin und Zucker zu einer Glasur einkochen.', 'Spieße grillen und mehrfach mit Glasur bestreichen.', 'Heiß servieren.'],
      sr: ['Пилетину исећи на залогаје.', 'Наизменично са комадима лука нанизати на штапиће.', 'Соја сос, мирин и шећер укувати у глазуру.', 'Ражњиће пећи и више пута премазати глазуром.', 'Послужити вруће.'],
      hr: ['Piletinu narezati na zalogaje.', 'Naizmjenično s komadima luka nanizati na štapiće.', 'Soja umak, mirin i šećer ukuhati u glazuru.', 'Ražnjiće peći i više puta premazati glazurom.', 'Poslužiti vruće.'],
      ba: ['Piletinu narezati na zalogaje.', 'Naizmjenično sa komadima luka nanizati na štapiće.', 'Soja sos, mirin i šećer ukuhati u glazuru.', 'Ražnjiće peći i više puta premazati glazurom.', 'Poslužiti vruće.'],
      en: ['Cut the chicken into bite-sized pieces.', 'Thread onto skewers alternating with leek pieces.', 'Reduce soy sauce, mirin and sugar into a glaze.', 'Grill the skewers, brushing repeatedly with glaze.', 'Serve hot.']
    }
  },

  {
    id: 'onigiri', kueche: 'japanisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Onigiri', sr: 'Онигири', hr: 'Onigiri', ba: 'Onigiri', en: 'Onigiri' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Sushireis', sr: 'суши пиринач', hr: 'sushi riža', ba: 'sushi riža', en: 'sushi rice' } },
      { menge: 2, einheit: 'stk', name: { de: 'Noriblätter', sr: 'нори листови', hr: 'nori listovi', ba: 'nori listovi', en: 'nori sheets' } },
      { menge: 100, einheit: 'g', name: { de: 'Thunfisch oder Lachs', sr: 'туњевина или лосос', hr: 'tuna ili losos', ba: 'tuna ili losos', en: 'tuna or salmon' } },
      { menge: 1, einheit: 'tl', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } },
      { menge: null, einheit: 'ng', name: { de: 'Sesam', sr: 'сусам', hr: 'sezam', ba: 'susam', en: 'sesame' } }
    ],
    schritte: {
      de: ['Reis kochen und leicht abkühlen lassen.', 'Hände anfeuchten und salzen.', 'Etwas Reis mit Füllung in der Mitte zu Dreiecken formen.', 'Mit einem Streifen Nori umwickeln.', 'Mit Sesam bestreuen und servieren.'],
      sr: ['Пиринач скувати и мало охладити.', 'Руке навлажити и посолити.', 'Мало пиринча са филом у средини обликовати у троуглове.', 'Обмотати траком нори алге.', 'Посути сусамом и послужити.'],
      hr: ['Rižu skuhati i malo ohladiti.', 'Ruke navlažiti i posoliti.', 'Malo riže s nadjevom u sredini oblikovati u trokute.', 'Omotati trakom nori alge.', 'Posuti sezamom i poslužiti.'],
      ba: ['Rižu skuhati i malo ohladiti.', 'Ruke navlažiti i posoliti.', 'Malo riže sa nadjevom u sredini oblikovati u trokute.', 'Omotati trakom nori alge.', 'Posuti susamom i poslužiti.'],
      en: ['Cook the rice and let cool slightly.', 'Moisten and salt your hands.', 'Shape rice with filling in the centre into triangles.', 'Wrap with a strip of nori.', 'Sprinkle with sesame and serve.']
    }
  },

  // ---- THAILÄNDISCH --------------------------------------------------------
  {
    id: 'pad_thai', kueche: 'thailaendisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Pad Thai', sr: 'Пад тај', hr: 'Pad Thai', ba: 'Pad Thai', en: 'Pad Thai' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'Reisnudeln', sr: 'пиринчани резанци', hr: 'rižini rezanci', ba: 'rižini rezanci', en: 'rice noodles' } },
      { menge: 200, einheit: 'g', name: { de: 'Garnelen oder Hähnchen', sr: 'шкампи или пилетина', hr: 'škampi ili piletina', ba: 'škampi ili piletina', en: 'prawns or chicken' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 100, einheit: 'g', name: { de: 'Sojasprossen', sr: 'клице соје', hr: 'klice soje', ba: 'klice soje', en: 'bean sprouts' } },
      { menge: 3, einheit: 'el', name: { de: 'Fischsauce', sr: 'риба сос', hr: 'riblji umak', ba: 'riblji sos', en: 'fish sauce' } },
      { menge: 50, einheit: 'g', name: { de: 'Erdnüsse', sr: 'кикирики', hr: 'kikiriki', ba: 'kikiriki', en: 'peanuts' } },
      { menge: null, einheit: 'ng', name: { de: 'Limette, Öl, Zucker', sr: 'лимета, уље, шећер', hr: 'limeta, ulje, šećer', ba: 'limeta, ulje, šećer', en: 'lime, oil, sugar' } }
    ],
    schritte: {
      de: ['Reisnudeln einweichen.', 'Garnelen oder Hähnchen in Öl anbraten.', 'Eier dazugeben und stocken lassen.', 'Nudeln, Fischsauce und Zucker zugeben und pfannenrühren.', 'Mit Sprossen, Erdnüssen und Limette servieren.'],
      sr: ['Пиринчане резанце потопити.', 'Шкампе или пилетину пропржити на уљу.', 'Додати јаја и оставити да се стегну.', 'Додати резанце, риба сос и шећер и пропржити.', 'Послужити са клицама, кикирикијем и лиметом.'],
      hr: ['Rižine rezance namočiti.', 'Škampe ili piletinu popržiti na ulju.', 'Dodati jaja i ostaviti da se stegnu.', 'Dodati rezance, riblji umak i šećer i propržiti.', 'Poslužiti s klicama, kikirikijem i limetom.'],
      ba: ['Rižine rezance namočiti.', 'Škampe ili piletinu popržiti na ulju.', 'Dodati jaja i ostaviti da se stegnu.', 'Dodati rezance, riblji sos i šećer i propržiti.', 'Poslužiti sa klicama, kikirikijem i limetom.'],
      en: ['Soak the rice noodles.', 'Fry the prawns or chicken in oil.', 'Add the eggs and let set.', 'Add noodles, fish sauce and sugar and stir-fry.', 'Serve with sprouts, peanuts and lime.']
    }
  },

  {
    id: 'gruenes_curry', kueche: 'thailaendisch', portionen: 4, dauer_min: 35,
    titel: { de: 'Grünes Thai-Curry', sr: 'Зелени тај кари', hr: 'Zeleni Thai curry', ba: 'Zeleni Thai curry', en: 'Green Thai curry' },
    zutaten: [
      { menge: 400, einheit: 'ml', name: { de: 'Kokosmilch', sr: 'кокосово млеко', hr: 'kokosovo mlijeko', ba: 'kokosovo mlijeko', en: 'coconut milk' } },
      { menge: 2, einheit: 'el', name: { de: 'grüne Currypaste', sr: 'зелена кари паста', hr: 'zelena curry pasta', ba: 'zelena curry pasta', en: 'green curry paste' } },
      { menge: 400, einheit: 'g', name: { de: 'Hähnchen', sr: 'пилетина', hr: 'piletina', ba: 'piletina', en: 'chicken' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zucchini', sr: 'тиквица', hr: 'tikvica', ba: 'tikvica', en: 'courgette' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 2, einheit: 'el', name: { de: 'Fischsauce', sr: 'риба сос', hr: 'riblji umak', ba: 'riblji sos', en: 'fish sauce' } },
      { menge: 1, einheit: 'bund', name: { de: 'Thai-Basilikum', sr: 'тај босиљак', hr: 'thai bosiljak', ba: 'thai bosiljak', en: 'thai basil' } }
    ],
    schritte: {
      de: ['Currypaste in etwas Kokosmilch anrösten.', 'Hähnchen zugeben und anbraten.', 'Restliche Kokosmilch angießen.', 'Gemüse und Fischsauce zugeben und 15 Minuten köcheln.', 'Mit Thai-Basilikum und Reis servieren.'],
      sr: ['Кари пасту пропржити у мало кокосовог млека.', 'Додати пилетину и пропржити.', 'Долити остатак кокосовог млека.', 'Додати поврће и риба сос и кувати 15 минута.', 'Послужити са тај босиљком и пиринчем.'],
      hr: ['Curry pastu popržiti u malo kokosovog mlijeka.', 'Dodati piletinu i popržiti.', 'Uliti ostatak kokosovog mlijeka.', 'Dodati povrće i riblji umak i kuhati 15 minuta.', 'Poslužiti s thai bosiljkom i rižom.'],
      ba: ['Curry pastu popržiti u malo kokosovog mlijeka.', 'Dodati piletinu i popržiti.', 'Uliti ostatak kokosovog mlijeka.', 'Dodati povrće i riblji sos i kuhati 15 minuta.', 'Poslužiti sa thai bosiljkom i rižom.'],
      en: ['Toast the curry paste in a little coconut milk.', 'Add the chicken and fry.', 'Pour in the remaining coconut milk.', 'Add vegetables and fish sauce and simmer for 15 minutes.', 'Serve with thai basil and rice.']
    }
  },

  {
    id: 'tom_yum', kueche: 'thailaendisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Tom Yum Suppe', sr: 'Том јам супа', hr: 'Tom Yum juha', ba: 'Tom Yum supa', en: 'Tom Yum soup' },
    zutaten: [
      { menge: 1000, einheit: 'ml', name: { de: 'Brühe', sr: 'супа', hr: 'temeljac', ba: 'supa', en: 'broth' } },
      { menge: 250, einheit: 'g', name: { de: 'Garnelen', sr: 'шкампи', hr: 'škampi', ba: 'škampi', en: 'prawns' } },
      { menge: 150, einheit: 'g', name: { de: 'Champignons', sr: 'печурке', hr: 'šampinjoni', ba: 'šampinjoni', en: 'mushrooms' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zitronengras', sr: 'лимунска трава', hr: 'limunska trava', ba: 'limunska trava', en: 'lemongrass' } },
      { menge: 2, einheit: 'el', name: { de: 'Fischsauce', sr: 'риба сос', hr: 'riblji umak', ba: 'riblji sos', en: 'fish sauce' } },
      { menge: 1, einheit: 'stk', name: { de: 'Limette', sr: 'лимета', hr: 'limeta', ba: 'limeta', en: 'lime' } },
      { menge: null, einheit: 'ng', name: { de: 'Chili, Koriander', sr: 'чили, коријандер', hr: 'čili, korijandar', ba: 'čili, korijander', en: 'chilli, coriander' } }
    ],
    schritte: {
      de: ['Brühe mit Zitronengras und Chili aufkochen.', 'Champignons zugeben und kurz kochen.', 'Garnelen zugeben und garen.', 'Mit Fischsauce und Limettensaft abschmecken.', 'Mit Koriander bestreut servieren.'],
      sr: ['Супу прокувати са лимунском травом и чилијем.', 'Додати печурке и кратко кувати.', 'Додати шкампе и скувати.', 'Зачинити риба сосом и соком лимете.', 'Послужити посуто коријандером.'],
      hr: ['Temeljac prokuhati s limunskom travom i čilijem.', 'Dodati šampinjone i kratko kuhati.', 'Dodati škampe i skuhati.', 'Začiniti ribljim umakom i sokom limete.', 'Poslužiti posuto korijandrom.'],
      ba: ['Supu prokuhati sa limunskom travom i čilijem.', 'Dodati šampinjone i kratko kuhati.', 'Dodati škampe i skuhati.', 'Začiniti ribljim sosom i sokom limete.', 'Poslužiti posuto korijanderom.'],
      en: ['Boil the broth with lemongrass and chilli.', 'Add mushrooms and cook briefly.', 'Add the prawns and cook through.', 'Season with fish sauce and lime juice.', 'Serve sprinkled with coriander.']
    }
  },

  {
    id: 'mango_sticky_rice', kueche: 'thailaendisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Mango Sticky Rice', sr: 'Лепљиви пиринач са мангом', hr: 'Ljepljiva riža s mangom', ba: 'Ljepljiva riža sa mangom', en: 'Mango sticky rice' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Klebreis', sr: 'лепљиви пиринач', hr: 'ljepljiva riža', ba: 'ljepljiva riža', en: 'sticky rice' } },
      { menge: 300, einheit: 'ml', name: { de: 'Kokosmilch', sr: 'кокосово млеко', hr: 'kokosovo mlijeko', ba: 'kokosovo mlijeko', en: 'coconut milk' } },
      { menge: 60, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 2, einheit: 'stk', name: { de: 'reife Mangos', sr: 'зреле манго', hr: 'zreli mango', ba: 'zreli mango', en: 'ripe mangos' } },
      { menge: 1, einheit: 'prise', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Klebreis einweichen und dämpfen.', 'Kokosmilch mit Zucker und Salz erwärmen.', 'Den warmen Reis mit der Hälfte der Kokosmilch mischen.', 'Mango in Scheiben schneiden.', 'Reis mit Mango anrichten und restliche Kokosmilch darüber geben.'],
      sr: ['Лепљиви пиринач потопити и парити.', 'Кокосово млеко загрејати са шећером и сољу.', 'Топли пиринач помешати са пола кокосовог млека.', 'Манго исећи на кришке.', 'Пиринач сервирати са мангом и прелити остатком кокосовог млека.'],
      hr: ['Ljepljivu rižu namočiti i pariti.', 'Kokosovo mlijeko zagrijati sa šećerom i soli.', 'Toplu rižu pomiješati s pola kokosovog mlijeka.', 'Mango narezati na kriške.', 'Rižu servirati s mangom i preliti ostatkom kokosovog mlijeka.'],
      ba: ['Ljepljivu rižu namočiti i pariti.', 'Kokosovo mlijeko zagrijati sa šećerom i soli.', 'Toplu rižu pomiješati sa pola kokosovog mlijeka.', 'Mango narezati na kriške.', 'Rižu servirati sa mangom i preliti ostatkom kokosovog mlijeka.'],
      en: ['Soak and steam the sticky rice.', 'Warm the coconut milk with sugar and salt.', 'Mix the warm rice with half the coconut milk.', 'Slice the mango.', 'Serve the rice with mango and drizzle the rest of the coconut milk over.']
    }
  },

  {
    id: 'pad_kra_pao', kueche: 'thailaendisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Pad Kra Pao (Basilikum-Hähnchen)', sr: 'Пилетина са босиљком', hr: 'Piletina s bosiljkom', ba: 'Piletina sa bosiljkom', en: 'Thai basil chicken' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Hähnchenhack', sr: 'млевена пилетина', hr: 'mljevena piletina', ba: 'mljevena piletina', en: 'minced chicken' } },
      { menge: 4, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 2, einheit: 'stk', name: { de: 'Chilischoten', sr: 'љуте папричице', hr: 'ljute papričice', ba: 'ljute papričice', en: 'chillies' } },
      { menge: 2, einheit: 'el', name: { de: 'Austernsauce', sr: 'острига сос', hr: 'umak od kamenica', ba: 'sos od kamenica', en: 'oyster sauce' } },
      { menge: 1, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 1, einheit: 'bund', name: { de: 'Thai-Basilikum', sr: 'тај босиљак', hr: 'thai bosiljak', ba: 'thai bosiljak', en: 'thai basil' } }
    ],
    schritte: {
      de: ['Knoblauch und Chili in Öl anbraten.', 'Hähnchenhack zugeben und krümelig braten.', 'Austern- und Sojasauce zugeben.', 'Basilikum unterheben, bis es zusammenfällt.', 'Mit Reis und Spiegelei servieren.'],
      sr: ['Бели лук и чили пропржити на уљу.', 'Додати млевену пилетину и пржити мрвичасто.', 'Додати острига и соја сос.', 'Умешати босиљак док не спласне.', 'Послужити са пиринчем и јајем на око.'],
      hr: ['Češnjak i čili popržiti na ulju.', 'Dodati mljevenu piletinu i pržiti mrvičasto.', 'Dodati umak od kamenica i soja umak.', 'Umiješati bosiljak dok ne splasne.', 'Poslužiti s rižom i jajem na oko.'],
      ba: ['Bijeli luk i čili popržiti na ulju.', 'Dodati mljevenu piletinu i pržiti mrvičasto.', 'Dodati sos od kamenica i soja sos.', 'Umiješati bosiljak dok ne splasne.', 'Poslužiti sa rižom i jajem na oko.'],
      en: ['Fry garlic and chilli in oil.', 'Add the minced chicken and fry crumbly.', 'Add oyster and soy sauce.', 'Fold in the basil until it wilts.', 'Serve with rice and a fried egg.']
    }
  },

  {
    id: 'som_tam', kueche: 'thailaendisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Som Tam (Papayasalat)', sr: 'Салата од папаје', hr: 'Salata od papaje', ba: 'Salata od papaje', en: 'Papaya salad' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'grüne Papaya', sr: 'зелена папаја', hr: 'zelena papaja', ba: 'zelena papaja', en: 'green papaya' } },
      { menge: 2, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 2, einheit: 'el', name: { de: 'Fischsauce', sr: 'риба сос', hr: 'riblji umak', ba: 'riblji sos', en: 'fish sauce' } },
      { menge: 1, einheit: 'stk', name: { de: 'Limette', sr: 'лимета', hr: 'limeta', ba: 'limeta', en: 'lime' } },
      { menge: 40, einheit: 'g', name: { de: 'Erdnüsse', sr: 'кикирики', hr: 'kikiriki', ba: 'kikiriki', en: 'peanuts' } },
      { menge: null, einheit: 'ng', name: { de: 'Chili, Zucker', sr: 'чили, шећер', hr: 'čili, šećer', ba: 'čili, šećer', en: 'chilli, sugar' } }
    ],
    schritte: {
      de: ['Papaya raspeln.', 'Knoblauch und Chili im Mörser zerstoßen.', 'Fischsauce, Limette und Zucker zugeben.', 'Papaya und Tomaten unterheben.', 'Mit Erdnüssen bestreut servieren.'],
      sr: ['Папају изрендати.', 'Бели лук и чили изгњечити у авану.', 'Додати риба сос, лимету и шећер.', 'Умешати папају и парадајз.', 'Послужити посуто кикирикијем.'],
      hr: ['Papaju naribati.', 'Češnjak i čili zgnječiti u mužaru.', 'Dodati riblji umak, limetu i šećer.', 'Umiješati papaju i rajčice.', 'Poslužiti posuto kikirikijem.'],
      ba: ['Papaju naribati.', 'Bijeli luk i čili zgnječiti u avanu.', 'Dodati riblji sos, limetu i šećer.', 'Umiješati papaju i paradajz.', 'Poslužiti posuto kikirikijem.'],
      en: ['Grate the papaya.', 'Pound garlic and chilli in a mortar.', 'Add fish sauce, lime and sugar.', 'Fold in papaya and tomatoes.', 'Serve sprinkled with peanuts.']
    }
  },

  {
    id: 'massaman_curry', kueche: 'thailaendisch', portionen: 4, dauer_min: 50,
    titel: { de: 'Massaman Curry', sr: 'Масаман кари', hr: 'Massaman curry', ba: 'Massaman curry', en: 'Massaman curry' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Rindfleisch', sr: 'говедина', hr: 'govedina', ba: 'govedina', en: 'beef' } },
      { menge: 400, einheit: 'ml', name: { de: 'Kokosmilch', sr: 'кокосово млеко', hr: 'kokosovo mlijeko', ba: 'kokosovo mlijeko', en: 'coconut milk' } },
      { menge: 3, einheit: 'el', name: { de: 'Massaman-Currypaste', sr: 'масаман кари паста', hr: 'massaman curry pasta', ba: 'massaman curry pasta', en: 'massaman curry paste' } },
      { menge: 300, einheit: 'g', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 50, einheit: 'g', name: { de: 'Erdnüsse', sr: 'кикирики', hr: 'kikiriki', ba: 'kikiriki', en: 'peanuts' } },
      { menge: null, einheit: 'ng', name: { de: 'Fischsauce, Zucker', sr: 'риба сос, шећер', hr: 'riblji umak, šećer', ba: 'riblji sos, šećer', en: 'fish sauce, sugar' } }
    ],
    schritte: {
      de: ['Currypaste in etwas Kokosmilch anrösten.', 'Rindfleisch zugeben und anbraten.', 'Restliche Kokosmilch und Kartoffeln zugeben.', 'Zugedeckt ca. 40 Minuten schmoren.', 'Mit Erdnüssen, Fischsauce und Zucker abschmecken.'],
      sr: ['Кари пасту пропржити у мало кокосовог млека.', 'Додати говедину и пропржити.', 'Додати остатак кокосовог млека и кромпир.', 'Поклопљено динстати око 40 минута.', 'Зачинити кикирикијем, риба сосом и шећером.'],
      hr: ['Curry pastu popržiti u malo kokosovog mlijeka.', 'Dodati govedinu i popržiti.', 'Dodati ostatak kokosovog mlijeka i krumpir.', 'Poklopljeno pirjati oko 40 minuta.', 'Začiniti kikirikijem, ribljim umakom i šećerom.'],
      ba: ['Curry pastu popržiti u malo kokosovog mlijeka.', 'Dodati govedinu i popržiti.', 'Dodati ostatak kokosovog mlijeka i krompir.', 'Poklopljeno dinstati oko 40 minuta.', 'Začiniti kikirikijem, ribljim sosom i šećerom.'],
      en: ['Toast the curry paste in a little coconut milk.', 'Add the beef and fry.', 'Add the rest of the coconut milk and potatoes.', 'Stew covered for about 40 minutes.', 'Season with peanuts, fish sauce and sugar.']
    }
  },

  {
    id: 'thai_fried_rice', kueche: 'thailaendisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Thailändischer Bratreis', sr: 'Тајландски пржени пиринач', hr: 'Tajlandska pržena riža', ba: 'Tajlandska pržena riža', en: 'Thai fried rice' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'gekochter Reis', sr: 'кувани пиринач', hr: 'kuhana riža', ba: 'kuhana riža', en: 'cooked rice' } },
      { menge: 200, einheit: 'g', name: { de: 'Hähnchen', sr: 'пилетина', hr: 'piletina', ba: 'piletina', en: 'chicken' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 100, einheit: 'g', name: { de: 'Erbsen und Karotten', sr: 'грашак и шаргарепа', hr: 'grašak i mrkva', ba: 'grašak i mrkva', en: 'peas and carrots' } },
      { menge: 2, einheit: 'el', name: { de: 'Fischsauce', sr: 'риба сос', hr: 'riblji umak', ba: 'riblji sos', en: 'fish sauce' } },
      { menge: 1, einheit: 'stk', name: { de: 'Limette', sr: 'лимета', hr: 'limeta', ba: 'limeta', en: 'lime' } }
    ],
    schritte: {
      de: ['Hähnchen in Öl anbraten.', 'Eier dazugeben und stocken lassen.', 'Gemüse zugeben und kurz braten.', 'Reis und Fischsauce zugeben und pfannenrühren.', 'Mit Limette beträufelt servieren.'],
      sr: ['Пилетину пропржити на уљу.', 'Додати јаја и оставити да се стегну.', 'Додати поврће и кратко пропржити.', 'Додати пиринач и риба сос и пропржити.', 'Послужити прелито лиметом.'],
      hr: ['Piletinu popržiti na ulju.', 'Dodati jaja i ostaviti da se stegnu.', 'Dodati povrće i kratko popržiti.', 'Dodati rižu i riblji umak i propržiti.', 'Poslužiti preliveno limetom.'],
      ba: ['Piletinu popržiti na ulju.', 'Dodati jaja i ostaviti da se stegnu.', 'Dodati povrće i kratko popržiti.', 'Dodati rižu i riblji sos i propržiti.', 'Poslužiti preliveno limetom.'],
      en: ['Fry the chicken in oil.', 'Add the eggs and let set.', 'Add the vegetables and fry briefly.', 'Add rice and fish sauce and stir-fry.', 'Serve drizzled with lime.']
    }
  },

  // ---- TÜRKISCH ------------------------------------------------------------
  {
    id: 'doener', kueche: 'tuerkisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Döner Kebab', sr: 'Донер кебаб', hr: 'Döner kebab', ba: 'Döner kebab', en: 'Doner kebab' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Hähnchen- oder Kalbfleisch', sr: 'пилетина или телетина', hr: 'piletina ili teletina', ba: 'piletina ili teletina', en: 'chicken or veal' } },
      { menge: 4, einheit: 'stk', name: { de: 'Fladenbrote', sr: 'лепиње', hr: 'lepinje', ba: 'lepinje', en: 'flatbreads' } },
      { menge: 200, einheit: 'g', name: { de: 'Joghurt', sr: 'јогурт', hr: 'jogurt', ba: 'jogurt', en: 'yoghurt' } },
      { menge: 2, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 200, einheit: 'g', name: { de: 'Salat', sr: 'зелена салата', hr: 'zelena salata', ba: 'zelena salata', en: 'lettuce' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Gewürze, Öl', sr: 'зачини, уље', hr: 'začini, ulje', ba: 'začini, ulje', en: 'spices, oil' } }
    ],
    schritte: {
      de: ['Fleisch in Streifen schneiden und würzen.', 'In Öl kräftig anbraten.', 'Fladenbrot aufschneiden und mit Joghurt bestreichen.', 'Fleisch, Salat, Tomaten und Zwiebel einfüllen.', 'Zusammenklappen und servieren.'],
      sr: ['Месо исећи на траке и зачинити.', 'Јако пропржити на уљу.', 'Лепињу расећи и премазати јогуртом.', 'Ставити месо, салату, парадајз и лук.', 'Склопити и послужити.'],
      hr: ['Meso narezati na trake i začiniti.', 'Jako popržiti na ulju.', 'Lepinju razrezati i premazati jogurtom.', 'Staviti meso, salatu, rajčice i luk.', 'Sklopiti i poslužiti.'],
      ba: ['Meso narezati na trake i začiniti.', 'Jako popržiti na ulju.', 'Lepinju razrezati i premazati jogurtom.', 'Staviti meso, salatu, paradajz i luk.', 'Sklopiti i poslužiti.'],
      en: ['Cut the meat into strips and season.', 'Fry hard in oil.', 'Cut open the flatbread and spread with yoghurt.', 'Fill with meat, salad, tomatoes and onion.', 'Fold over and serve.']
    }
  },

  {
    id: 'lahmacun', kueche: 'tuerkisch', portionen: 4, dauer_min: 45,
    titel: { de: 'Lahmacun', sr: 'Лахмаџун', hr: 'Lahmacun', ba: 'Lahmacun', en: 'Lahmacun' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'dünne Teigfladen', sr: 'танке коре', hr: 'tanke kore', ba: 'tanke kore', en: 'thin dough bases' } },
      { menge: 300, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 2, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } },
      { menge: null, einheit: 'ng', name: { de: 'Gewürze, Zitrone', sr: 'зачини, лимун', hr: 'začini, limun', ba: 'začini, limun', en: 'spices, lemon' } }
    ],
    schritte: {
      de: ['Tomaten, Paprika und Zwiebel sehr fein hacken.', 'Mit Hackfleisch und Gewürzen zu einer Paste mischen.', 'Dünn auf die Teigfladen streichen.', 'Bei hoher Hitze ca. 8 Minuten backen.', 'Mit Petersilie und Zitrone rollen und servieren.'],
      sr: ['Парадајз, паприку и лук веома ситно исецкати.', 'Помешати са млевеним месом и зачинима у пасту.', 'Танко размазати по корама.', 'Пећи на јакој ватри око 8 минута.', 'Уролати са першуном и лимуном и послужити.'],
      hr: ['Rajčice, papriku i luk vrlo sitno nasjeckati.', 'Pomiješati s mljevenim mesom i začinima u pastu.', 'Tanko namazati po korama.', 'Peći na jakoj vatri oko 8 minuta.', 'Urolati s peršinom i limunom i poslužiti.'],
      ba: ['Paradajz, papriku i luk vrlo sitno nasjeckati.', 'Pomiješati sa mljevenim mesom i začinima u pastu.', 'Tanko namazati po korama.', 'Peći na jakoj vatri oko 8 minuta.', 'Urolati sa peršunom i limunom i poslužiti.'],
      en: ['Very finely chop tomatoes, pepper and onion.', 'Mix with minced meat and spices into a paste.', 'Spread thinly over the dough bases.', 'Bake at high heat for about 8 minutes.', 'Roll with parsley and lemon and serve.']
    }
  },

  {
    id: 'boerek', kueche: 'tuerkisch', portionen: 6, dauer_min: 60,
    titel: { de: 'Börek mit Käse', sr: 'Бурек са сиром', hr: 'Burek sa sirom', ba: 'Burek sa sirom', en: 'Cheese börek' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Yufka-/Filoteig', sr: 'јуфка коре', hr: 'jufka kore', ba: 'jufka kore', en: 'yufka/filo pastry' } },
      { menge: 300, einheit: 'g', name: { de: 'Weißkäse', sr: 'бели сир', hr: 'bijeli sir', ba: 'bijeli sir', en: 'white cheese' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 100, einheit: 'ml', name: { de: 'Öl', sr: 'уље', hr: 'ulje', ba: 'ulje', en: 'oil' } },
      { menge: 200, einheit: 'ml', name: { de: 'Mineralwasser', sr: 'кисела вода', hr: 'mineralna voda', ba: 'mineralna voda', en: 'sparkling water' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } }
    ],
    schritte: {
      de: ['Käse mit Ei und Petersilie mischen.', 'Öl mit Wasser und einem Ei verquirlen.', 'Yufka-Blätter damit bestreichen.', 'Käse auflegen und einrollen.', 'Bei 190 Grad ca. 35 Minuten goldbraun backen.'],
      sr: ['Сир помешати са јајем и першуном.', 'Уље умутити са водом и јајетом.', 'Јуфка коре тиме премазати.', 'Ставити сир и уролати.', 'Пећи на 190 степени око 35 минута до златне боје.'],
      hr: ['Sir pomiješati s jajem i peršinom.', 'Ulje umutiti s vodom i jajem.', 'Jufka kore time premazati.', 'Staviti sir i urolati.', 'Peći na 190 stupnjeva oko 35 minuta do zlatne boje.'],
      ba: ['Sir pomiješati sa jajem i peršunom.', 'Ulje umutiti sa vodom i jajem.', 'Jufka kore time premazati.', 'Staviti sir i urolati.', 'Peći na 190 stepeni oko 35 minuta do zlatne boje.'],
      en: ['Mix the cheese with egg and parsley.', 'Whisk oil with water and an egg.', 'Brush the yufka sheets with it.', 'Add cheese and roll up.', 'Bake at 190 degrees for about 35 minutes until golden.']
    }
  },

  {
    id: 'menemen', kueche: 'tuerkisch', portionen: 2, dauer_min: 20,
    titel: { de: 'Menemen', sr: 'Менемен', hr: 'Menemen', ba: 'Menemen', en: 'Menemen' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 3, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 2, einheit: 'stk', name: { de: 'grüne Paprika', sr: 'зелена паприка', hr: 'zelena paprika', ba: 'zelena paprika', en: 'green peppers' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Salz, Pfeffer', sr: 'уље, со, бибер', hr: 'ulje, sol, papar', ba: 'ulje, so, biber', en: 'oil, salt, pepper' } }
    ],
    schritte: {
      de: ['Zwiebel und Paprika in Öl anbraten.', 'Tomaten zugeben und einkochen lassen.', 'Mit Salz und Pfeffer würzen.', 'Eier darübergeben und langsam stocken lassen.', 'Mit Brot servieren.'],
      sr: ['Лук и паприку пропржити на уљу.', 'Додати парадајз и оставити да се укува.', 'Зачинити сољу и бибером.', 'Прелити јајима и полако стезати.', 'Послужити са хлебом.'],
      hr: ['Luk i papriku popržiti na ulju.', 'Dodati rajčice i ostaviti da se ukuha.', 'Začiniti soli i paprom.', 'Preliti jajima i polako stezati.', 'Poslužiti s kruhom.'],
      ba: ['Luk i papriku popržiti na ulju.', 'Dodati paradajz i ostaviti da se ukuha.', 'Začiniti soli i biberom.', 'Preliti jajima i polako stezati.', 'Poslužiti sa hljebom.'],
      en: ['Fry onion and pepper in oil.', 'Add the tomatoes and let reduce.', 'Season with salt and pepper.', 'Pour the eggs over and let set slowly.', 'Serve with bread.']
    }
  },

  {
    id: 'kisir', kueche: 'tuerkisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Kısır (Bulgursalat)', sr: 'Кисир (салата од булгура)', hr: 'Kısır (salata od bulgura)', ba: 'Kısır (salata od bulgura)', en: 'Kısır (bulgur salad)' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'feiner Bulgur', sr: 'ситни булгур', hr: 'sitni bulgur', ba: 'sitni bulgur', en: 'fine bulgur' } },
      { menge: 2, einheit: 'el', name: { de: 'Tomatenmark', sr: 'паста од парадајза', hr: 'pasta od rajčice', ba: 'pasta od paradajza', en: 'tomato paste' } },
      { menge: 3, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone', sr: 'лимун', hr: 'limun', ba: 'limun', en: 'lemon' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Salz', sr: 'маслиново уље, со', hr: 'maslinovo ulje, sol', ba: 'maslinovo ulje, so', en: 'olive oil, salt' } }
    ],
    schritte: {
      de: ['Bulgur mit heißem Wasser übergießen und quellen lassen.', 'Tomatenmark und Olivenöl unterrühren.', 'Frühlingszwiebeln und Petersilie hacken und zugeben.', 'Mit Zitronensaft und Salz abschmecken.', 'Gut durchmischen und kühl servieren.'],
      sr: ['Булгур прелити врелом водом и оставити да набубри.', 'Умешати пасту од парадајза и маслиново уље.', 'Исецкати млади лук и першун и додати.', 'Зачинити соком лимуна и сољу.', 'Добро промешати и послужити расхлађено.'],
      hr: ['Bulgur preliti vrućom vodom i ostaviti da nabubri.', 'Umiješati pastu od rajčice i maslinovo ulje.', 'Nasjeckati mladi luk i peršin i dodati.', 'Začiniti sokom limuna i soli.', 'Dobro promiješati i poslužiti rashlađeno.'],
      ba: ['Bulgur preliti vrućom vodom i ostaviti da nabubri.', 'Umiješati pastu od paradajza i maslinovo ulje.', 'Nasjeckati mladi luk i peršun i dodati.', 'Začiniti sokom limuna i soli.', 'Dobro promiješati i poslužiti rashlađeno.'],
      en: ['Pour hot water over the bulgur and let it swell.', 'Stir in tomato paste and olive oil.', 'Chop spring onions and parsley and add.', 'Season with lemon juice and salt.', 'Mix well and serve chilled.']
    }
  },

  {
    id: 'imam_bayildi', kueche: 'tuerkisch', portionen: 4, dauer_min: 60,
    titel: { de: 'İmam Bayıldı (gefüllte Aubergine)', sr: 'Пуњени плави патлиџан', hr: 'Punjeni patlidžan', ba: 'Punjeni patlidžan', en: 'Imam bayildi (stuffed aubergine)' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Auberginen', sr: 'плави патлиџани', hr: 'patlidžani', ba: 'plavi patlidžani', en: 'aubergines' } },
      { menge: 3, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 4, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 100, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } }
    ],
    schritte: {
      de: ['Auberginen längs einschneiden und vorbraten.', 'Zwiebeln, Knoblauch und Tomaten zu einer Füllung dünsten.', 'Auberginen mit der Füllung befüllen.', 'Mit Olivenöl und etwas Wasser in eine Form legen.', 'Zugedeckt bei 180 Grad ca. 40 Minuten schmoren.'],
      sr: ['Патлиџане уздужно засећи и претпржити.', 'Лук, бели лук и парадајз продинстати у фил.', 'Патлиџане напунити филом.', 'Ставити у калуп са маслиновим уљем и мало воде.', 'Поклопљено на 180 степени динстати око 40 минута.'],
      hr: ['Patlidžane uzdužno zarezati i pretpržiti.', 'Luk, češnjak i rajčice popirjati u nadjev.', 'Patlidžane napuniti nadjevom.', 'Staviti u kalup s maslinovim uljem i malo vode.', 'Poklopljeno na 180 stupnjeva pirjati oko 40 minuta.'],
      ba: ['Patlidžane uzdužno zarezati i pretpržiti.', 'Luk, bijeli luk i paradajz podinstati u nadjev.', 'Patlidžane napuniti nadjevom.', 'Staviti u kalup sa maslinovim uljem i malo vode.', 'Poklopljeno na 180 stepeni dinstati oko 40 minuta.'],
      en: ['Slit the aubergines lengthwise and pre-fry.', 'Sweat onions, garlic and tomatoes into a filling.', 'Fill the aubergines with the mixture.', 'Place in a dish with olive oil and a little water.', 'Stew covered at 180 degrees for about 40 minutes.']
    }
  },

  {
    id: 'sutlac', kueche: 'tuerkisch', portionen: 6, dauer_min: 45,
    titel: { de: 'Sütlaç (Milchreis)', sr: 'Сутлач (мледени пиринач)', hr: 'Sütlaç (mliječna riža)', ba: 'Sütlaç (mliječna riža)', en: 'Sütlaç (rice pudding)' },
    zutaten: [
      { menge: 150, einheit: 'g', name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 1000, einheit: 'ml', name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 120, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 2, einheit: 'el', name: { de: 'Speisestärke', sr: 'гриз скроб', hr: 'škrob', ba: 'škrob', en: 'cornstarch' } },
      { menge: 1, einheit: 'tl', name: { de: 'Vanille', sr: 'ванила', hr: 'vanilija', ba: 'vanilija', en: 'vanilla' } },
      { menge: null, einheit: 'ng', name: { de: 'Zimt', sr: 'цимет', hr: 'cimet', ba: 'cimet', en: 'cinnamon' } }
    ],
    schritte: {
      de: ['Reis in Wasser weich kochen.', 'Milch und Zucker zugeben und erhitzen.', 'Stärke mit etwas Milch anrühren und einrühren.', 'Unter Rühren eindicken lassen.', 'In Schälchen füllen, kühlen und mit Zimt bestreuen.'],
      sr: ['Пиринач скувати у води до мекоће.', 'Додати млеко и шећер и загрејати.', 'Скроб размутити у мало млека и умешати.', 'Уз мешање оставити да се згусне.', 'Сипати у чинијице, охладити и посути циметом.'],
      hr: ['Rižu skuhati u vodi do mekoće.', 'Dodati mlijeko i šećer i zagrijati.', 'Škrob razmutiti u malo mlijeka i umiješati.', 'Uz miješanje ostaviti da se zgusne.', 'Uliti u zdjelice, ohladiti i posuti cimetom.'],
      ba: ['Rižu skuhati u vodi do mekoće.', 'Dodati mlijeko i šećer i zagrijati.', 'Škrob razmutiti u malo mlijeka i umiješati.', 'Uz miješanje ostaviti da se zgusne.', 'Uliti u zdjelice, ohladiti i posuti cimetom.'],
      en: ['Cook the rice soft in water.', 'Add milk and sugar and heat.', 'Mix the starch with a little milk and stir in.', 'Let thicken while stirring.', 'Pour into bowls, chill and dust with cinnamon.']
    }
  },

  {
    id: 'pide', kueche: 'tuerkisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Pide (türkisches Schiffchen)', sr: 'Пиде', hr: 'Pide', ba: 'Pide', en: 'Pide' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 7, einheit: 'g', name: { de: 'Trockenhefe', sr: 'суви квасац', hr: 'suhi kvasac', ba: 'suhi kvasac', en: 'dry yeast' } },
      { menge: 300, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 150, einheit: 'g', name: { de: 'Käse', sr: 'сир', hr: 'sir', ba: 'sir', en: 'cheese' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Salz, Ei', sr: 'уље, со, јаје', hr: 'ulje, sol, jaje', ba: 'ulje, so, jaje', en: 'oil, salt, egg' } }
    ],
    schritte: {
      de: ['Aus Mehl, Hefe, Wasser und Salz einen Teig kneten und gehen lassen.', 'Zu ovalen Fladen ausrollen.', 'Mit Hackfleisch bzw. Käse und Paprika belegen.', 'Ränder einschlagen und mit Ei bestreichen.', 'Bei 220 Grad ca. 15 Minuten backen.'],
      sr: ['Од брашна, квасца, воде и соли умесити тесто и оставити да нарасте.', 'Развући у овалне лепиње.', 'Обложити млевеним месом односно сиром и паприком.', 'Ивице преклопити и премазати јајетом.', 'Пећи на 220 степени око 15 минута.'],
      hr: ['Od brašna, kvasca, vode i soli umijesiti tijesto i ostaviti da naraste.', 'Razvući u ovalne lepinje.', 'Obložiti mljevenim mesom odnosno sirom i paprikom.', 'Rubove preklopiti i premazati jajem.', 'Peći na 220 stupnjeva oko 15 minuta.'],
      ba: ['Od brašna, kvasca, vode i soli umijesiti tijesto i ostaviti da naraste.', 'Razvući u ovalne lepinje.', 'Obložiti mljevenim mesom odnosno sirom i paprikom.', 'Rubove preklopiti i premazati jajem.', 'Peći na 220 stepeni oko 15 minuta.'],
      en: ['Knead a dough from flour, yeast, water and salt and let rise.', 'Roll into oval flatbreads.', 'Top with minced meat or cheese and pepper.', 'Fold in the edges and brush with egg.', 'Bake at 220 degrees for about 15 minutes.']
    }
  },

  // ---- UNGARISCH -----------------------------------------------------------
  {
    id: 'porkolt', kueche: 'ungarisch', portionen: 4, dauer_min: 90,
    titel: { de: 'Pörkölt', sr: 'Перкелт', hr: 'Pörkölt', ba: 'Pörkölt', en: 'Pörkölt' },
    zutaten: [
      { menge: 800, einheit: 'g', name: { de: 'Rindergulasch', sr: 'говеђи гулаш', hr: 'goveđi gulaš', ba: 'goveđi gulaš', en: 'diced beef' } },
      { menge: 3, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 2, einheit: 'el', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: 2, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell peppers' } },
      { menge: 2, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Salz, Kümmel', sr: 'уље, со, ким', hr: 'ulje, sol, kim', ba: 'ulje, so, kim', en: 'oil, salt, caraway' } }
    ],
    schritte: {
      de: ['Zwiebeln in Öl goldgelb dünsten.', 'Topf vom Herd nehmen und Paprikapulver einrühren.', 'Fleisch zugeben und anbraten.', 'Paprika und Tomaten zugeben.', 'Zugedeckt bei kleiner Hitze ca. 75 Minuten schmoren.'],
      sr: ['Лук продинстати на уљу до златножуте боје.', 'Скинути лонац са ватре и умешати алеву паприку.', 'Додати месо и пропржити.', 'Додати паприку и парадајз.', 'Поклопљено на тихој ватри динстати око 75 минута.'],
      hr: ['Luk popirjati na ulju do zlatnožute boje.', 'Skinuti lonac s vatre i umiješati mljevenu papriku.', 'Dodati meso i popržiti.', 'Dodati papriku i rajčice.', 'Poklopljeno na laganoj vatri pirjati oko 75 minuta.'],
      ba: ['Luk podinstati na ulju do zlatnožute boje.', 'Skinuti lonac sa vatre i umiješati mljevenu papriku.', 'Dodati meso i popržiti.', 'Dodati papriku i paradajz.', 'Poklopljeno na laganoj vatri dinstati oko 75 minuta.'],
      en: ['Sweat the onions in oil until golden.', 'Take the pot off the heat and stir in the paprika.', 'Add the meat and sear.', 'Add peppers and tomatoes.', 'Stew covered on low heat for about 75 minutes.']
    }
  },

  {
    id: 'langos', kueche: 'ungarisch', portionen: 4, dauer_min: 90,
    titel: { de: 'Lángos', sr: 'Лангош', hr: 'Langoši', ba: 'Langoši', en: 'Lángos' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 7, einheit: 'g', name: { de: 'Trockenhefe', sr: 'суви квасац', hr: 'suhi kvasac', ba: 'suhi kvasac', en: 'dry yeast' } },
      { menge: 250, einheit: 'ml', name: { de: 'lauwarme Milch', sr: 'млако млеко', hr: 'mlako mlijeko', ba: 'mlako mlijeko', en: 'lukewarm milk' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 150, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl zum Frittieren, Sauerrahm', sr: 'уље за пржење, кисела павлака', hr: 'ulje za prženje, kiselo vrhnje', ba: 'ulje za prženje, kisela pavlaka', en: 'oil for frying, sour cream' } }
    ],
    schritte: {
      de: ['Aus Mehl, Hefe, Milch und Salz einen Teig kneten.', 'Zugedeckt ca. 1 Stunde gehen lassen.', 'Zu Fladen ausziehen.', 'In heißem Öl beidseitig goldbraun frittieren.', 'Mit Knoblauch, Sauerrahm und Käse bestreichen.'],
      sr: ['Од брашна, квасца, млека и соли умесити тесто.', 'Поклопљено оставити да нарасте око 1 сат.', 'Развући у лепиње.', 'Пржити у врелом уљу са обе стране до златне боје.', 'Премазати белим луком, киселом павлаком и сиром.'],
      hr: ['Od brašna, kvasca, mlijeka i soli umijesiti tijesto.', 'Poklopljeno ostaviti da naraste oko 1 sat.', 'Razvući u lepinje.', 'Pržiti u vrućem ulju s obje strane do zlatne boje.', 'Premazati češnjakom, kiselim vrhnjem i sirom.'],
      ba: ['Od brašna, kvasca, mlijeka i soli umijesiti tijesto.', 'Poklopljeno ostaviti da naraste oko 1 sat.', 'Razvući u lepinje.', 'Pržiti u vrućem ulju sa obje strane do zlatne boje.', 'Premazati bijelim lukom, kiselom pavlakom i sirom.'],
      en: ['Knead a dough from flour, yeast, milk and salt.', 'Cover and let rise for about 1 hour.', 'Stretch into flatbreads.', 'Deep-fry in hot oil golden on both sides.', 'Spread with garlic, sour cream and cheese.']
    }
  },

  {
    id: 'letscho', kueche: 'ungarisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Letscho', sr: 'Лечо', hr: 'Lečo', ba: 'Lečo', en: 'Lecsó' },
    zutaten: [
      { menge: 6, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell peppers' } },
      { menge: 4, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 200, einheit: 'g', name: { de: 'geräucherte Wurst', sr: 'димљена кобасица', hr: 'dimljena kobasica', ba: 'dimljena kobasica', en: 'smoked sausage' } },
      { menge: 1, einheit: 'el', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Salz', sr: 'уље, со', hr: 'ulje, sol', ba: 'ulje, so', en: 'oil, salt' } }
    ],
    schritte: {
      de: ['Zwiebeln in Öl anschwitzen.', 'Wurst in Scheiben zugeben und anbraten.', 'Paprika zugeben und andünsten.', 'Tomaten und Paprikapulver zugeben.', 'Ca. 20 Minuten schmoren und mit Brot servieren.'],
      sr: ['Лук продинстати на уљу.', 'Додати кобасицу на кришке и пропржити.', 'Додати паприку и продинстати.', 'Додати парадајз и алеву паприку.', 'Динстати око 20 минута и послужити са хлебом.'],
      hr: ['Luk popirjati na ulju.', 'Dodati kobasicu na kriške i popržiti.', 'Dodati papriku i popirjati.', 'Dodati rajčice i mljevenu papriku.', 'Pirjati oko 20 minuta i poslužiti s kruhom.'],
      ba: ['Luk podinstati na ulju.', 'Dodati kobasicu na kriške i popržiti.', 'Dodati papriku i podinstati.', 'Dodati paradajz i mljevenu papriku.', 'Dinstati oko 20 minuta i poslužiti sa hljebom.'],
      en: ['Sweat the onions in oil.', 'Add sliced sausage and fry.', 'Add the peppers and sauté.', 'Add tomatoes and paprika.', 'Stew for about 20 minutes and serve with bread.']
    }
  },

  {
    id: 'chicken_paprikash', kueche: 'ungarisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Paprikahuhn', sr: 'Пилетина паприкаш', hr: 'Pileći paprikaš', ba: 'Pileći paprikaš', en: 'Chicken paprikash' },
    zutaten: [
      { menge: 1, einheit: 'kg', name: { de: 'Hähnchenteile', sr: 'делови пилетине', hr: 'dijelovi piletine', ba: 'dijelovi piletine', en: 'chicken pieces' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 2, einheit: 'el', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: 200, einheit: 'ml', name: { de: 'Sauerrahm', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'sour cream' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Salz, Mehl', sr: 'уље, со, брашно', hr: 'ulje, sol, brašno', ba: 'ulje, so, brašno', en: 'oil, salt, flour' } }
    ],
    schritte: {
      de: ['Zwiebeln in Öl anschwitzen und Paprikapulver einrühren.', 'Hähnchen zugeben und anbraten.', 'Mit etwas Wasser aufgießen und schmoren.', 'Sauerrahm mit etwas Mehl verrühren und einrühren.', 'Kurz aufkochen und mit Nockerln servieren.'],
      sr: ['Лук продинстати на уљу и умешати алеву паприку.', 'Додати пилетину и пропржити.', 'Залити мало воде и динстати.', 'Киселу павлаку размутити са мало брашна и умешати.', 'Кратко прокувати и послужити са кнедлама.'],
      hr: ['Luk popirjati na ulju i umiješati mljevenu papriku.', 'Dodati piletinu i popržiti.', 'Zaliti malo vode i pirjati.', 'Kiselo vrhnje razmutiti s malo brašna i umiješati.', 'Kratko prokuhati i poslužiti s njokama.'],
      ba: ['Luk podinstati na ulju i umiješati mljevenu papriku.', 'Dodati piletinu i popržiti.', 'Zaliti malo vode i dinstati.', 'Kiselu pavlaku razmutiti sa malo brašna i umiješati.', 'Kratko prokuhati i poslužiti sa njokama.'],
      en: ['Sweat the onions in oil and stir in the paprika.', 'Add the chicken and sear.', 'Pour in a little water and stew.', 'Mix the sour cream with a little flour and stir in.', 'Bring briefly to the boil and serve with dumplings.']
    }
  },

  {
    id: 'toltott_kaposzta', kueche: 'ungarisch', portionen: 6, dauer_min: 120,
    titel: { de: 'Töltött Káposzta (Krautwickel)', sr: 'Мађарска сарма', hr: 'Mađarska sarma', ba: 'Mađarska sarma', en: 'Stuffed cabbage rolls' },
    zutaten: [
      { menge: 1, einheit: 'kopf', name: { de: 'Sauerkrautkopf', sr: 'глава киселог купуса', hr: 'glava kiselog kupusa', ba: 'glava kiselog kupusa', en: 'head of sour cabbage' } },
      { menge: 500, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 100, einheit: 'g', name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 200, einheit: 'g', name: { de: 'geräucherter Speck', sr: 'димљена сланина', hr: 'dimljena slanina', ba: 'dimljena slanina', en: 'smoked bacon' } },
      { menge: 1, einheit: 'el', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Sauerrahm, Salz', sr: 'кисела павлака, со', hr: 'kiselo vrhnje, sol', ba: 'kisela pavlaka, so', en: 'sour cream, salt' } }
    ],
    schritte: {
      de: ['Hackfleisch mit Reis, Paprikapulver und Salz mischen.', 'Krautblätter mit der Masse füllen und aufrollen.', 'In einen Topf schichten, Speck dazwischen legen.', 'Mit Wasser bedecken und ca. 90 Minuten schmoren.', 'Mit Sauerrahm servieren.'],
      sr: ['Млевено месо помешати са пиринчем, алевом паприком и сољу.', 'Листове купуса напунити масом и уролати.', 'Слагати у лонац, између ставити сланину.', 'Прелити водом и динстати око 90 минута.', 'Послужити са киселом павлаком.'],
      hr: ['Mljeveno meso pomiješati s rižom, mljevenom paprikom i soli.', 'Listove kupusa napuniti masom i urolati.', 'Slagati u lonac, između staviti slaninu.', 'Preliti vodom i pirjati oko 90 minuta.', 'Poslužiti s kiselim vrhnjem.'],
      ba: ['Mljeveno meso pomiješati sa rižom, mljevenom paprikom i soli.', 'Listove kupusa napuniti masom i urolati.', 'Slagati u lonac, između staviti slaninu.', 'Preliti vodom i dinstati oko 90 minuta.', 'Poslužiti sa kiselom pavlakom.'],
      en: ['Mix the minced meat with rice, paprika and salt.', 'Fill the cabbage leaves with the mixture and roll up.', 'Layer in a pot, placing bacon in between.', 'Cover with water and stew for about 90 minutes.', 'Serve with sour cream.']
    }
  },

  {
    id: 'halaszle', kueche: 'ungarisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Halászlé (Fischsuppe)', sr: 'Мађарска рибља чорба', hr: 'Mađarska riblja juha', ba: 'Mađarska riblja čorba', en: 'Halászlé (fish soup)' },
    zutaten: [
      { menge: 1, einheit: 'kg', name: { de: 'Süßwasserfisch', sr: 'речна риба', hr: 'riječna riba', ba: 'riječna riba', en: 'freshwater fish' } },
      { menge: 3, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 2, einheit: 'el', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: 2, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell pepper' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Chili', sr: 'со, чили', hr: 'sol, čili', ba: 'so, čili', en: 'salt, chilli' } }
    ],
    schritte: {
      de: ['Zwiebeln in Wasser weich kochen.', 'Paprikapulver, Tomaten und Paprika zugeben.', 'Fischstücke einlegen.', 'Ohne Rühren ca. 30 Minuten köcheln.', 'Mit Salz und Chili abschmecken und mit Brot servieren.'],
      sr: ['Лук скувати у води до мекоће.', 'Додати алеву паприку, парадајз и паприку.', 'Уложити комаде рибе.', 'Без мешања кувати око 30 минута.', 'Зачинити сољу и чилијем и послужити са хлебом.'],
      hr: ['Luk skuhati u vodi do mekoće.', 'Dodati mljevenu papriku, rajčice i papriku.', 'Uložiti komade ribe.', 'Bez miješanja kuhati oko 30 minuta.', 'Začiniti soli i čilijem i poslužiti s kruhom.'],
      ba: ['Luk skuhati u vodi do mekoće.', 'Dodati mljevenu papriku, paradajz i papriku.', 'Uložiti komade ribe.', 'Bez miješanja kuhati oko 30 minuta.', 'Začiniti soli i čilijem i poslužiti sa hljebom.'],
      en: ['Boil the onions soft in water.', 'Add paprika, tomatoes and pepper.', 'Add the fish pieces.', 'Simmer without stirring for about 30 minutes.', 'Season with salt and chilli and serve with bread.']
    }
  },

  // ---- RUSSISCH ------------------------------------------------------------
  {
    id: 'borschtsch', kueche: 'russisch', portionen: 6, dauer_min: 90,
    titel: { de: 'Borschtsch', sr: 'Борш', hr: 'Boršč', ba: 'Boršč', en: 'Borscht' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Rote Bete', sr: 'цвекла', hr: 'cikla', ba: 'cikla', en: 'beetroot' } },
      { menge: 400, einheit: 'g', name: { de: 'Rindfleisch', sr: 'говедина', hr: 'govedina', ba: 'govedina', en: 'beef' } },
      { menge: 300, einheit: 'g', name: { de: 'Weißkohl', sr: 'бели купус', hr: 'bijeli kupus', ba: 'bijeli kupus', en: 'white cabbage' } },
      { menge: 2, einheit: 'stk', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Karotte', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrot' } },
      { menge: 200, einheit: 'ml', name: { de: 'Sauerrahm', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'sour cream' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Dill, Essig', sr: 'со, мирођија, сирће', hr: 'sol, kopar, ocat', ba: 'so, mirođija, sirće', en: 'salt, dill, vinegar' } }
    ],
    schritte: {
      de: ['Rindfleisch in Wasser weich kochen und Brühe abseihen.', 'Rote Bete, Karotte und Zwiebel andünsten.', 'Kohl und Kartoffeln in die Brühe geben.', 'Rote-Bete-Mischung und Fleisch zugeben und köcheln.', 'Mit Essig, Salz, Dill und Sauerrahm servieren.'],
      sr: ['Говедину скувати у води до мекоће и процедити супу.', 'Цвеклу, шаргарепу и лук продинстати.', 'Купус и кромпир ставити у супу.', 'Додати смесу од цвекле и месо и кувати.', 'Послужити са сирћетом, сољу, мирођијом и киселом павлаком.'],
      hr: ['Govedinu skuhati u vodi do mekoće i procijediti temeljac.', 'Ciklu, mrkvu i luk popirjati.', 'Kupus i krumpir staviti u temeljac.', 'Dodati smjesu od cikle i meso i kuhati.', 'Poslužiti s octom, soli, koprom i kiselim vrhnjem.'],
      ba: ['Govedinu skuhati u vodi do mekoće i procijediti supu.', 'Ciklu, mrkvu i luk podinstati.', 'Kupus i krompir staviti u supu.', 'Dodati smjesu od cikle i meso i kuhati.', 'Poslužiti sa sirćetom, soli, mirođijom i kiselom pavlakom.'],
      en: ['Boil the beef soft in water and strain the broth.', 'Sauté beetroot, carrot and onion.', 'Add cabbage and potatoes to the broth.', 'Add the beetroot mixture and meat and simmer.', 'Serve with vinegar, salt, dill and sour cream.']
    }
  },

  {
    id: 'pelmeni', kueche: 'russisch', portionen: 4, dauer_min: 75,
    titel: { de: 'Pelmeni', sr: 'Пељмени', hr: 'Pelmeni', ba: 'Pelmeni', en: 'Pelmeni' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 400, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 200, einheit: 'ml', name: { de: 'Sauerrahm', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'sour cream' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Aus Mehl, Ei, Wasser und Salz einen Teig kneten.', 'Hackfleisch mit geriebener Zwiebel und Gewürzen mischen.', 'Teig dünn ausrollen und Kreise ausstechen.', 'Füllen und zu Teigtaschen formen.', 'In Salzwasser garen und mit Sauerrahm servieren.'],
      sr: ['Од брашна, јаја, воде и соли умесити тесто.', 'Млевено месо помешати са ренданим луком и зачинима.', 'Тесто танко развући и извадити кругове.', 'Напунити и обликовати кнедле.', 'Скувати у сланој води и послужити са киселом павлаком.'],
      hr: ['Od brašna, jaja, vode i soli umijesiti tijesto.', 'Mljeveno meso pomiješati s naribanim lukom i začinima.', 'Tijesto tanko razvući i izvaditi krugove.', 'Napuniti i oblikovati okruglice.', 'Skuhati u slanoj vodi i poslužiti s kiselim vrhnjem.'],
      ba: ['Od brašna, jaja, vode i soli umijesiti tijesto.', 'Mljeveno meso pomiješati sa naribanim lukom i začinima.', 'Tijesto tanko razvući i izvaditi krugove.', 'Napuniti i oblikovati okruglice.', 'Skuhati u slanoj vodi i poslužiti sa kiselom pavlakom.'],
      en: ['Knead a dough from flour, egg, water and salt.', 'Mix minced meat with grated onion and spices.', 'Roll out the dough thinly and cut circles.', 'Fill and shape into dumplings.', 'Cook in salted water and serve with sour cream.']
    }
  },

  {
    id: 'beef_stroganoff', kueche: 'russisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Beef Stroganoff', sr: 'Беф строганов', hr: 'Beef stroganoff', ba: 'Beef stroganoff', en: 'Beef stroganoff' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Rinderfilet', sr: 'говеђи филе', hr: 'goveđi file', ba: 'goveđi file', en: 'beef fillet' } },
      { menge: 250, einheit: 'g', name: { de: 'Champignons', sr: 'печурке', hr: 'šampinjoni', ba: 'šampinjoni', en: 'mushrooms' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 200, einheit: 'ml', name: { de: 'Sauerrahm', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'sour cream' } },
      { menge: 1, einheit: 'el', name: { de: 'Senf', sr: 'сенф', hr: 'senf', ba: 'senf', en: 'mustard' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Salz, Pfeffer', sr: 'уље, со, бибер', hr: 'ulje, sol, papar', ba: 'ulje, so, biber', en: 'oil, salt, pepper' } }
    ],
    schritte: {
      de: ['Fleisch in feine Streifen schneiden und scharf anbraten.', 'Zwiebel und Champignons zugeben und braten.', 'Senf und etwas Wasser zugeben.', 'Sauerrahm einrühren und kurz erwärmen.', 'Mit Salz und Pfeffer würzen und mit Reis servieren.'],
      sr: ['Месо исећи на танке траке и јако пропржити.', 'Додати лук и печурке и пропржити.', 'Додати сенф и мало воде.', 'Умешати киселу павлаку и кратко загрејати.', 'Зачинити сољу и бибером и послужити са пиринчем.'],
      hr: ['Meso narezati na tanke trake i jako popržiti.', 'Dodati luk i šampinjone i popržiti.', 'Dodati senf i malo vode.', 'Umiješati kiselo vrhnje i kratko zagrijati.', 'Začiniti soli i paprom i poslužiti s rižom.'],
      ba: ['Meso narezati na tanke trake i jako popržiti.', 'Dodati luk i šampinjone i popržiti.', 'Dodati senf i malo vode.', 'Umiješati kiselu pavlaku i kratko zagrijati.', 'Začiniti soli i biberom i poslužiti sa rižom.'],
      en: ['Cut the meat into fine strips and sear hard.', 'Add onion and mushrooms and fry.', 'Add mustard and a little water.', 'Stir in the sour cream and warm briefly.', 'Season with salt and pepper and serve with rice.']
    }
  },

  {
    id: 'blini', kueche: 'russisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Blini', sr: 'Блини', hr: 'Blini', ba: 'Blini', en: 'Blini' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 400, einheit: 'ml', name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 7, einheit: 'g', name: { de: 'Trockenhefe', sr: 'суви квасац', hr: 'suhi kvasac', ba: 'suhi kvasac', en: 'dry yeast' } },
      { menge: null, einheit: 'ng', name: { de: 'Butter, Sauerrahm', sr: 'путер, кисела павлака', hr: 'maslac, kiselo vrhnje', ba: 'maslac, kisela pavlaka', en: 'butter, sour cream' } }
    ],
    schritte: {
      de: ['Mehl, Milch, Eier und Hefe zu einem Teig verrühren.', 'Zugedeckt 30 Minuten gehen lassen.', 'Butter in der Pfanne erhitzen.', 'Kleine Pfannkuchen beidseitig backen.', 'Mit Sauerrahm oder Marmelade servieren.'],
      sr: ['Брашно, млеко, јаја и квасац умутити у тесто.', 'Поклопљено оставити да нарасте 30 минута.', 'Путер загрејати у тигању.', 'Мале палачинке испећи са обе стране.', 'Послужити са киселом павлаком или мармеладом.'],
      hr: ['Brašno, mlijeko, jaja i kvasac umutiti u tijesto.', 'Poklopljeno ostaviti da naraste 30 minuta.', 'Maslac zagrijati u tavi.', 'Male palačinke ispeći s obje strane.', 'Poslužiti s kiselim vrhnjem ili marmeladom.'],
      ba: ['Brašno, mlijeko, jaja i kvasac umutiti u tijesto.', 'Poklopljeno ostaviti da naraste 30 minuta.', 'Maslac zagrijati u tavi.', 'Male palačinke ispeći sa obje strane.', 'Poslužiti sa kiselom pavlakom ili marmeladom.'],
      en: ['Whisk flour, milk, eggs and yeast into a batter.', 'Cover and let rise for 30 minutes.', 'Heat butter in the pan.', 'Bake small pancakes on both sides.', 'Serve with sour cream or jam.']
    }
  },

  {
    id: 'olivier_salat', kueche: 'russisch', portionen: 6, dauer_min: 40,
    titel: { de: 'Olivier-Salat (russischer Salat)', sr: 'Оливије салата (руска салата)', hr: 'Olivier salata (ruska salata)', ba: 'Olivije salata (ruska salata)', en: 'Olivier salad (russian salad)' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 3, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 4, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 150, einheit: 'g', name: { de: 'Erbsen', sr: 'грашак', hr: 'grašak', ba: 'grašak', en: 'peas' } },
      { menge: 200, einheit: 'g', name: { de: 'Fleischwurst', sr: 'виршла', hr: 'hrenovke', ba: 'viršle', en: 'sausage' } },
      { menge: 200, einheit: 'g', name: { de: 'Mayonnaise', sr: 'мајонез', hr: 'majoneza', ba: 'majoneza', en: 'mayonnaise' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Gewürzgurken', sr: 'со, кисели краставци', hr: 'sol, kiseli krastavci', ba: 'so, kiseli krastavci', en: 'salt, pickles' } }
    ],
    schritte: {
      de: ['Kartoffeln, Karotten und Eier kochen und würfeln.', 'Wurst und Gewürzgurken würfeln.', 'Alles mit Erbsen mischen.', 'Mit Mayonnaise und Salz vermengen.', 'Gut durchkühlen lassen und servieren.'],
      sr: ['Кромпир, шаргарепу и јаја скувати и исецкати.', 'Виршлу и киселе краставце исецкати.', 'Све помешати са грашком.', 'Сјединити са мајонезом и сољу.', 'Добро расхладити и послужити.'],
      hr: ['Krumpir, mrkvu i jaja skuhati i narezati.', 'Hrenovke i kisele krastavce narezati.', 'Sve pomiješati s graškom.', 'Sjediniti s majonezom i soli.', 'Dobro rashladiti i poslužiti.'],
      ba: ['Krompir, mrkvu i jaja skuhati i narezati.', 'Viršle i kisele krastavce narezati.', 'Sve pomiješati sa graškom.', 'Sjediniti sa majonezom i soli.', 'Dobro rashladiti i poslužiti.'],
      en: ['Boil potatoes, carrots and eggs and dice.', 'Dice sausage and pickles.', 'Mix everything with the peas.', 'Combine with mayonnaise and salt.', 'Chill well and serve.']
    }
  },

  // ---- PORTUGIESISCH -------------------------------------------------------
  {
    id: 'bacalhau', kueche: 'portugiesisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Bacalhau (Stockfisch-Auflauf)', sr: 'Бакалар', hr: 'Bakalar', ba: 'Bakalar', en: 'Bacalhau' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Stockfisch (gewässert)', sr: 'бакалар (намочен)', hr: 'bakalar (namočen)', ba: 'bakalar (namočen)', en: 'salt cod (soaked)' } },
      { menge: 600, einheit: 'g', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 100, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } }
    ],
    schritte: {
      de: ['Stockfisch kochen und in Stücke zupfen.', 'Kartoffeln kochen und in Scheiben schneiden.', 'Zwiebeln in Olivenöl weich dünsten.', 'Alles in eine Form schichten.', 'Mit Olivenöl beträufeln, überbacken und mit Ei servieren.'],
      sr: ['Бакалар скувати и раздвојити на комаде.', 'Кромпир скувати и исећи на кришке.', 'Лук продинстати на маслиновом уљу до мекоће.', 'Све сложити у калуп.', 'Прелити маслиновим уљем, запећи и послужити са јајем.'],
      hr: ['Bakalar skuhati i razdvojiti na komade.', 'Krumpir skuhati i narezati na kriške.', 'Luk popirjati na maslinovom ulju do mekoće.', 'Sve složiti u kalup.', 'Preliti maslinovim uljem, zapeći i poslužiti s jajem.'],
      ba: ['Bakalar skuhati i razdvojiti na komade.', 'Krompir skuhati i narezati na kriške.', 'Luk podinstati na maslinovom ulju do mekoće.', 'Sve složiti u kalup.', 'Preliti maslinovim uljem, zapeći i poslužiti sa jajem.'],
      en: ['Boil the salt cod and flake into pieces.', 'Boil the potatoes and slice.', 'Sweat the onions soft in olive oil.', 'Layer everything in a dish.', 'Drizzle with olive oil, bake and serve with egg.']
    }
  },

  {
    id: 'caldo_verde', kueche: 'portugiesisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Caldo Verde', sr: 'Калдо верде', hr: 'Caldo verde', ba: 'Caldo verde', en: 'Caldo verde' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 200, einheit: 'g', name: { de: 'Grünkohl', sr: 'кељ', hr: 'kelj', ba: 'kelj', en: 'kale' } },
      { menge: 150, einheit: 'g', name: { de: 'Chorizo-Wurst', sr: 'чоризо кобасица', hr: 'chorizo kobasica', ba: 'chorizo kobasica', en: 'chorizo sausage' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1200, einheit: 'ml', name: { de: 'Brühe', sr: 'супа', hr: 'temeljac', ba: 'supa', en: 'stock' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Salz', sr: 'маслиново уље, со', hr: 'maslinovo ulje, sol', ba: 'maslinovo ulje, so', en: 'olive oil, salt' } }
    ],
    schritte: {
      de: ['Zwiebel in Olivenöl anschwitzen.', 'Kartoffeln zugeben und mit Brühe aufgießen.', 'Weich kochen und pürieren.', 'Chorizo anbraten und zugeben.', 'Fein geschnittenen Grünkohl zugeben und kurz garen.'],
      sr: ['Лук продинстати на маслиновом уљу.', 'Додати кромпир и залити супом.', 'Скувати до мекоће и изблендати.', 'Чоризо пропржити и додати.', 'Додати ситно сечени кељ и кратко скувати.'],
      hr: ['Luk popirjati na maslinovom ulju.', 'Dodati krumpir i zaliti temeljcem.', 'Skuhati do mekoće i izblendati.', 'Chorizo popržiti i dodati.', 'Dodati sitno narezan kelj i kratko skuhati.'],
      ba: ['Luk podinstati na maslinovom ulju.', 'Dodati krompir i zaliti supom.', 'Skuhati do mekoće i izblendati.', 'Chorizo popržiti i dodati.', 'Dodati sitno narezan kelj i kratko skuhati.'],
      en: ['Sweat the onion in olive oil.', 'Add potatoes and pour in the stock.', 'Cook soft and purée.', 'Fry the chorizo and add.', 'Add finely sliced kale and cook briefly.']
    }
  },

  {
    id: 'piri_piri_huhn', kueche: 'portugiesisch', portionen: 4, dauer_min: 50,
    titel: { de: 'Piri-Piri-Hähnchen', sr: 'Пири пири пилетина', hr: 'Piri piri piletina', ba: 'Piri piri piletina', en: 'Piri piri chicken' },
    zutaten: [
      { menge: 1, einheit: 'kg', name: { de: 'Hähnchen', sr: 'пилетина', hr: 'piletina', ba: 'piletina', en: 'chicken' } },
      { menge: 3, einheit: 'stk', name: { de: 'Chilischoten', sr: 'љуте папричице', hr: 'ljute papričice', ba: 'ljute papričice', en: 'chillies' } },
      { menge: 4, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone', sr: 'лимун', hr: 'limun', ba: 'limun', en: 'lemon' } },
      { menge: 80, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Paprikapulver, Salz', sr: 'алева паприка, со', hr: 'mljevena paprika, sol', ba: 'mljevena paprika, so', en: 'paprika, salt' } }
    ],
    schritte: {
      de: ['Chili, Knoblauch, Zitrone und Öl zu einer Marinade mixen.', 'Hähnchen damit einreiben und marinieren.', 'Auf dem Grill oder im Ofen garen.', 'Mehrfach mit Marinade bestreichen.', 'Mit Pommes und Salat servieren.'],
      sr: ['Чили, бели лук, лимун и уље изблендати у маринаду.', 'Пилетину премазати и маринирати.', 'Пећи на роштиљу или у рерни.', 'Више пута премазати маринадом.', 'Послужити са помфритом и салатом.'],
      hr: ['Čili, češnjak, limun i ulje izblendati u marinadu.', 'Piletinu premazati i marinirati.', 'Peći na roštilju ili u pećnici.', 'Više puta premazati marinadom.', 'Poslužiti s pomfritom i salatom.'],
      ba: ['Čili, bijeli luk, limun i ulje izblendati u marinadu.', 'Piletinu premazati i marinirati.', 'Peći na roštilju ili u rerni.', 'Više puta premazati marinadom.', 'Poslužiti sa pomfritom i salatom.'],
      en: ['Blend chilli, garlic, lemon and oil into a marinade.', 'Rub the chicken with it and marinate.', 'Cook on the grill or in the oven.', 'Brush repeatedly with marinade.', 'Serve with fries and salad.']
    }
  },

  {
    id: 'pastel_de_nata', kueche: 'portugiesisch', portionen: 12, dauer_min: 60,
    titel: { de: 'Pastel de Nata', sr: 'Пастел де ната', hr: 'Pastel de nata', ba: 'Pastel de nata', en: 'Pastel de nata' },
    zutaten: [
      { menge: 1, einheit: 'stk', name: { de: 'Blätterteig', sr: 'лиснато тесто', hr: 'lisnato tijesto', ba: 'lisnato tijesto', en: 'puff pastry' } },
      { menge: 500, einheit: 'ml', name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 150, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 4, einheit: 'stk', name: { de: 'Eigelb', sr: 'жуманца', hr: 'žumanjci', ba: 'žumanca', en: 'egg yolks' } },
      { menge: 40, einheit: 'g', name: { de: 'Speisestärke', sr: 'гриз скроб', hr: 'škrob', ba: 'škrob', en: 'cornstarch' } },
      { menge: null, einheit: 'ng', name: { de: 'Zimt, Zitronenschale', sr: 'цимет, кора лимуна', hr: 'cimet, korica limuna', ba: 'cimet, korica limuna', en: 'cinnamon, lemon zest' } }
    ],
    schritte: {
      de: ['Milch mit Zucker, Stärke und Zitronenschale zu einer Creme kochen.', 'Eigelb einrühren und abkühlen lassen.', 'Blätterteig in Muffinform drücken.', 'Creme einfüllen.', 'Bei 230 Grad ca. 15 Minuten backen, bis Flecken entstehen.'],
      sr: ['Млеко са шећером, скробом и кором лимуна укувати у крем.', 'Умешати жуманца и охладити.', 'Лиснато тесто утиснути у калуп за мафине.', 'Насути крем.', 'Пећи на 230 степени око 15 минута док не добије флеке.'],
      hr: ['Mlijeko sa šećerom, škrobom i koricom limuna ukuhati u kremu.', 'Umiješati žumanjke i ohladiti.', 'Lisnato tijesto utisnuti u kalup za muffine.', 'Napuniti kremom.', 'Peći na 230 stupnjeva oko 15 minuta dok ne dobije mrlje.'],
      ba: ['Mlijeko sa šećerom, škrobom i koricom limuna ukuhati u kremu.', 'Umiješati žumanca i ohladiti.', 'Lisnato tijesto utisnuti u kalup za muffine.', 'Napuniti kremom.', 'Peći na 230 stepeni oko 15 minuta dok ne dobije mrlje.'],
      en: ['Cook milk with sugar, starch and lemon zest into a custard.', 'Stir in the egg yolks and let cool.', 'Press puff pastry into a muffin tin.', 'Fill with the custard.', 'Bake at 230 degrees for about 15 minutes until spots form.']
    }
  },

  {
    id: 'francesinha', kueche: 'portugiesisch', portionen: 2, dauer_min: 40,
    titel: { de: 'Francesinha', sr: 'Франсезиња', hr: 'Francesinha', ba: 'Francesinha', en: 'Francesinha' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Toastscheiben', sr: 'кришке тост хлеба', hr: 'kriške tost kruha', ba: 'kriške tost hljeba', en: 'slices of toast' } },
      { menge: 200, einheit: 'g', name: { de: 'Steak oder Wurst', sr: 'бифтек или кобасица', hr: 'biftek ili kobasica', ba: 'biftek ili kobasica', en: 'steak or sausage' } },
      { menge: 4, einheit: 'stk', name: { de: 'Scheiben Käse', sr: 'кришке сира', hr: 'kriške sira', ba: 'kriške sira', en: 'slices of cheese' } },
      { menge: 200, einheit: 'ml', name: { de: 'Tomaten-Bier-Sauce', sr: 'сос од парадајза и пива', hr: 'umak od rajčice i piva', ba: 'sos od paradajza i piva', en: 'tomato-beer sauce' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } }
    ],
    schritte: {
      de: ['Fleisch braten und zwischen Toast und Käse schichten.', 'Sandwich mit Käse bedecken und überbacken.', 'Für die Sauce Tomaten mit Bier und Gewürzen einkochen.', 'Ein Spiegelei braten.', 'Sandwich mit Sauce übergießen und mit Ei servieren.'],
      sr: ['Месо испржити и наслагати између тоста и сира.', 'Сендвич прекрити сиром и запећи.', 'За сос парадајз са пивом и зачинима укувати.', 'Испржити јаје на око.', 'Сендвич прелити сосом и послужити са јајем.'],
      hr: ['Meso ispržiti i naslagati između tosta i sira.', 'Sendvič prekriti sirom i zapeći.', 'Za umak rajčice s pivom i začinima ukuhati.', 'Ispržiti jaje na oko.', 'Sendvič preliti umakom i poslužiti s jajem.'],
      ba: ['Meso ispržiti i naslagati između tosta i sira.', 'Sendvič prekriti sirom i zapeći.', 'Za sos paradajz sa pivom i začinima ukuhati.', 'Ispržiti jaje na oko.', 'Sendvič preliti sosom i poslužiti sa jajem.'],
      en: ['Fry the meat and layer between toast and cheese.', 'Cover the sandwich with cheese and grill.', 'For the sauce reduce tomatoes with beer and spices.', 'Fry an egg.', 'Pour sauce over the sandwich and serve with the egg.']
    }
  },

  {
    id: 'arroz_de_marisco', kueche: 'portugiesisch', portionen: 4, dauer_min: 45,
    titel: { de: 'Arroz de Marisco', sr: 'Пиринач са плодовима мора', hr: 'Riža s plodovima mora', ba: 'Riža sa plodovima mora', en: 'Seafood rice' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 400, einheit: 'g', name: { de: 'gemischte Meeresfrüchte', sr: 'мешани плодови мора', hr: 'miješani plodovi mora', ba: 'miješani plodovi mora', en: 'mixed seafood' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1000, einheit: 'ml', name: { de: 'Fischbrühe', sr: 'рибља супа', hr: 'riblji temeljac', ba: 'riblja supa', en: 'fish stock' } },
      { menge: 1, einheit: 'bund', name: { de: 'Koriander', sr: 'коријандер', hr: 'korijandar', ba: 'korijander', en: 'coriander' } }
    ],
    schritte: {
      de: ['Zwiebel in Olivenöl anschwitzen.', 'Tomaten zugeben und einkochen.', 'Reis zugeben und mit Fischbrühe aufgießen.', 'Ca. 15 Minuten köcheln, bis der Reis fast gar ist.', 'Meeresfrüchte zugeben, garen und mit Koriander servieren.'],
      sr: ['Лук продинстати на маслиновом уљу.', 'Додати парадајз и укувати.', 'Додати пиринач и залити рибљом супом.', 'Кувати око 15 минута док пиринач скоро не омекша.', 'Додати плодове мора, скувати и послужити са коријандером.'],
      hr: ['Luk popirjati na maslinovom ulju.', 'Dodati rajčice i ukuhati.', 'Dodati rižu i zaliti ribljim temeljcem.', 'Kuhati oko 15 minuta dok riža skoro ne omekša.', 'Dodati plodove mora, skuhati i poslužiti s korijandrom.'],
      ba: ['Luk podinstati na maslinovom ulju.', 'Dodati paradajz i ukuhati.', 'Dodati rižu i zaliti ribljom supom.', 'Kuhati oko 15 minuta dok riža skoro ne omekša.', 'Dodati plodove mora, skuhati i poslužiti sa korijanderom.'],
      en: ['Sweat the onion in olive oil.', 'Add tomatoes and reduce.', 'Add rice and pour in fish stock.', 'Simmer for about 15 minutes until the rice is almost done.', 'Add seafood, cook and serve with coriander.']
    }
  },

  // ---- NACHSCHLAG BALKAN ---------------------------------------------------
  {
    id: 'japrak', kueche: 'balkan', portionen: 6, dauer_min: 90,
    titel: { de: 'Japrak (Weinblatt-Sarma)', sr: 'Јапрак', hr: 'Japrak', ba: 'Japrak', en: 'Vine leaf sarma' },
    zutaten: [
      { menge: 40, einheit: 'stk', name: { de: 'Weinblätter', sr: 'виново лишће', hr: 'vinovo lišće', ba: 'vinovo lišće', en: 'vine leaves' } },
      { menge: 500, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 100, einheit: 'g', name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Joghurt', sr: 'со, бибер, јогурт', hr: 'sol, papar, jogurt', ba: 'so, biber, jogurt', en: 'salt, pepper, yoghurt' } }
    ],
    schritte: {
      de: ['Hackfleisch mit Reis, Zwiebel und Gewürzen mischen.', 'Weinblätter mit der Masse füllen und aufrollen.', 'Eng in einen Topf schichten.', 'Mit Wasser bedecken und ca. 60 Minuten schmoren.', 'Mit Joghurt servieren.'],
      sr: ['Млевено месо помешати са пиринчем, луком и зачинима.', 'Виново лишће напунити масом и уролати.', 'Збијено сложити у лонац.', 'Прелити водом и динстати око 60 минута.', 'Послужити са јогуртом.'],
      hr: ['Mljeveno meso pomiješati s rižom, lukom i začinima.', 'Vinovo lišće napuniti masom i urolati.', 'Zbijeno složiti u lonac.', 'Preliti vodom i pirjati oko 60 minuta.', 'Poslužiti s jogurtom.'],
      ba: ['Mljeveno meso pomiješati sa rižom, lukom i začinima.', 'Vinovo lišće napuniti masom i urolati.', 'Zbijeno složiti u lonac.', 'Preliti vodom i dinstati oko 60 minuta.', 'Poslužiti sa jogurtom.'],
      en: ['Mix minced meat with rice, onion and spices.', 'Fill the vine leaves with the mixture and roll up.', 'Layer tightly in a pot.', 'Cover with water and stew for about 60 minutes.', 'Serve with yoghurt.']
    }
  },

  {
    id: 'podvarak', kueche: 'balkan', portionen: 6, dauer_min: 90,
    titel: { de: 'Podvarak (Kraut mit Fleisch)', sr: 'Подварак', hr: 'Podvarak', ba: 'Podvarak', en: 'Podvarak (baked cabbage)' },
    zutaten: [
      { menge: 1, einheit: 'kg', name: { de: 'Sauerkraut', sr: 'кисели купус', hr: 'kiseli kupus', ba: 'kiseli kupus', en: 'sauerkraut' } },
      { menge: 800, einheit: 'g', name: { de: 'Fleisch oder Hähnchen', sr: 'месо или пилетина', hr: 'meso ili piletina', ba: 'meso ili piletina', en: 'meat or chicken' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 1, einheit: 'el', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Salz, Lorbeer', sr: 'уље, со, ловоров лист', hr: 'ulje, sol, lovorov list', ba: 'ulje, so, lovorov list', en: 'oil, salt, bay leaf' } }
    ],
    schritte: {
      de: ['Zwiebeln in Öl anschwitzen und Kraut zugeben.', 'Mit Paprikapulver würzen und andünsten.', 'Fleisch anbraten.', 'Alles in eine Form schichten.', 'Bei 180 Grad ca. 60 Minuten backen.'],
      sr: ['Лук продинстати на уљу и додати купус.', 'Зачинити алевом паприком и продинстати.', 'Месо пропржити.', 'Све сложити у калуп.', 'Пећи на 180 степени око 60 минута.'],
      hr: ['Luk popirjati na ulju i dodati kupus.', 'Začiniti mljevenom paprikom i popirjati.', 'Meso popržiti.', 'Sve složiti u kalup.', 'Peći na 180 stupnjeva oko 60 minuta.'],
      ba: ['Luk podinstati na ulju i dodati kupus.', 'Začiniti mljevenom paprikom i podinstati.', 'Meso popržiti.', 'Sve složiti u kalup.', 'Peći na 180 stepeni oko 60 minuta.'],
      en: ['Sweat the onions in oil and add the cabbage.', 'Season with paprika and sauté.', 'Sear the meat.', 'Layer everything in a dish.', 'Bake at 180 degrees for about 60 minutes.']
    }
  },

  {
    id: 'pihtije', kueche: 'balkan', portionen: 8, dauer_min: 180,
    titel: { de: 'Pihtije (Sülze)', sr: 'Пихтије', hr: 'Hladetina', ba: 'Pihtije', en: 'Pork aspic' },
    zutaten: [
      { menge: 1, einheit: 'kg', name: { de: 'Schweinshaxe/Eisbein', sr: 'свињска колењица', hr: 'svinjska koljenica', ba: 'svinjska koljenica', en: 'pork knuckle' } },
      { menge: 4, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'stk', name: { de: 'Karotte', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrot' } },
      { menge: 2, einheit: 'stk', name: { de: 'Lorbeerblätter', sr: 'ловорови листови', hr: 'lovorovi listovi', ba: 'lovorovi listovi', en: 'bay leaves' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Paprikapulver', sr: 'со, бибер, алева паприка', hr: 'sol, papar, mljevena paprika', ba: 'so, biber, mljevena paprika', en: 'salt, pepper, paprika' } }
    ],
    schritte: {
      de: ['Fleisch mit Gewürzen ca. 3 Stunden weich kochen.', 'Fleisch von den Knochen lösen und in Schalen legen.', 'Knoblauch in die Brühe rühren.', 'Brühe abseihen und über das Fleisch gießen.', 'Über Nacht kalt fest werden lassen.'],
      sr: ['Месо са зачинима кувати око 3 сата до мекоће.', 'Месо одвојити од костију и ставити у чиније.', 'Умешати бели лук у супу.', 'Супу процедити и прелити преко меса.', 'Оставити преко ноћи на хладном да се стегне.'],
      hr: ['Meso sa začinima kuhati oko 3 sata do mekoće.', 'Meso odvojiti od kostiju i staviti u zdjele.', 'Umiješati češnjak u temeljac.', 'Temeljac procijediti i preliti preko mesa.', 'Ostaviti preko noći na hladnom da se stegne.'],
      ba: ['Meso sa začinima kuhati oko 3 sata do mekoće.', 'Meso odvojiti od kostiju i staviti u zdjele.', 'Umiješati bijeli luk u supu.', 'Supu procijediti i preliti preko mesa.', 'Ostaviti preko noći na hladnom da se stegne.'],
      en: ['Boil the meat with spices for about 3 hours until soft.', 'Remove the meat from the bones and place in bowls.', 'Stir garlic into the broth.', 'Strain the broth and pour over the meat.', 'Let set cold overnight.']
    }
  },

  {
    id: 'ustipci', kueche: 'balkan', portionen: 4, dauer_min: 40,
    titel: { de: 'Uštipci (Teigbällchen)', sr: 'Уштипци', hr: 'Uštipci', ba: 'Uštipci', en: 'Uštipci (fried dough)' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 200, einheit: 'ml', name: { de: 'Joghurt', sr: 'јогурт', hr: 'jogurt', ba: 'jogurt', en: 'yoghurt' } },
      { menge: 1, einheit: 'tl', name: { de: 'Backpulver', sr: 'прашак за пециво', hr: 'prašak za pecivo', ba: 'prašak za pecivo', en: 'baking powder' } },
      { menge: 1, einheit: 'stk', name: { de: 'Ei', sr: 'јаје', hr: 'jaje', ba: 'jaje', en: 'egg' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Öl zum Frittieren', sr: 'со, уље за пржење', hr: 'sol, ulje za prženje', ba: 'so, ulje za prženje', en: 'salt, oil for frying' } }
    ],
    schritte: {
      de: ['Mehl, Joghurt, Ei, Backpulver und Salz zu einem Teig verrühren.', 'Kurz ruhen lassen.', 'Mit einem Löffel Portionen abstechen.', 'In heißem Öl goldbraun frittieren.', 'Mit Käse oder Kajmak servieren.'],
      sr: ['Брашно, јогурт, јаје, прашак за пециво и со умутити у тесто.', 'Кратко оставити да одстоји.', 'Кашиком вадити порције.', 'Пржити у врелом уљу до златне боје.', 'Послужити са сиром или кајмаком.'],
      hr: ['Brašno, jogurt, jaje, prašak za pecivo i sol umutiti u tijesto.', 'Kratko ostaviti da odstoji.', 'Žlicom vaditi porcije.', 'Pržiti u vrućem ulju do zlatne boje.', 'Poslužiti sa sirom ili kajmakom.'],
      ba: ['Brašno, jogurt, jaje, prašak za pecivo i so umutiti u tijesto.', 'Kratko ostaviti da odstoji.', 'Kašikom vaditi porcije.', 'Pržiti u vrućem ulju do zlatne boje.', 'Poslužiti sa sirom ili kajmakom.'],
      en: ['Whisk flour, yoghurt, egg, baking powder and salt into a batter.', 'Let rest briefly.', 'Scoop portions with a spoon.', 'Deep-fry in hot oil until golden.', 'Serve with cheese or kajmak.']
    }
  },

  {
    id: 'riblja_corba', kueche: 'balkan', portionen: 4, dauer_min: 60,
    titel: { de: 'Fischsuppe (Riblja čorba)', sr: 'Рибља чорба', hr: 'Riblja juha', ba: 'Riblja čorba', en: 'Fish soup' },
    zutaten: [
      { menge: 800, einheit: 'g', name: { de: 'Süßwasserfisch', sr: 'речна риба', hr: 'riječna riba', ba: 'riječna riba', en: 'freshwater fish' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 1, einheit: 'stk', name: { de: 'Karotte', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrot' } },
      { menge: 1, einheit: 'el', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Chili, Öl', sr: 'со, чили, уље', hr: 'sol, čili, ulje', ba: 'so, čili, ulje', en: 'salt, chilli, oil' } }
    ],
    schritte: {
      de: ['Zwiebeln und Karotte in Wasser kochen.', 'Paprikapulver einrühren.', 'Fischstücke einlegen.', 'Ohne viel Rühren ca. 30 Minuten köcheln.', 'Mit Salz und Chili abschmecken.'],
      sr: ['Лук и шаргарепу кувати у води.', 'Умешати алеву паприку.', 'Уложити комаде рибе.', 'Без много мешања кувати око 30 минута.', 'Зачинити сољу и чилијем.'],
      hr: ['Luk i mrkvu kuhati u vodi.', 'Umiješati mljevenu papriku.', 'Uložiti komade ribe.', 'Bez puno miješanja kuhati oko 30 minuta.', 'Začiniti soli i čilijem.'],
      ba: ['Luk i mrkvu kuhati u vodi.', 'Umiješati mljevenu papriku.', 'Uložiti komade ribe.', 'Bez puno miješanja kuhati oko 30 minuta.', 'Začiniti soli i čilijem.'],
      en: ['Boil onions and carrot in water.', 'Stir in the paprika.', 'Add the fish pieces.', 'Simmer without much stirring for about 30 minutes.', 'Season with salt and chilli.']
    }
  },

  {
    id: 'karadjordjeva', kueche: 'balkan', portionen: 4, dauer_min: 45,
    titel: { de: 'Karađorđeva Schnitzel', sr: 'Карађорђева шницла', hr: 'Karađorđeva šnicla', ba: 'Karađorđeva šnicla', en: 'Karadjordje schnitzel' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Schweine- oder Kalbsschnitzel', sr: 'свињски или телећи шницли', hr: 'svinjski ili teleći odresci', ba: 'svinjski ili teleći odresci', en: 'pork or veal escalopes' } },
      { menge: 150, einheit: 'g', name: { de: 'Kajmak', sr: 'кајмак', hr: 'kajmak', ba: 'kajmak', en: 'kajmak' } },
      { menge: 100, einheit: 'g', name: { de: 'Schinken', sr: 'шунка', hr: 'šunka', ba: 'šunka', en: 'ham' } },
      { menge: 100, einheit: 'g', name: { de: 'Semmelbrösel', sr: 'презле', hr: 'krušne mrvice', ba: 'prezle', en: 'breadcrumbs' } },
      { menge: null, einheit: 'ng', name: { de: 'Ei, Mehl, Öl, Salz', sr: 'јаје, брашно, уље, со', hr: 'jaje, brašno, ulje, sol', ba: 'jaje, brašno, ulje, so', en: 'egg, flour, oil, salt' } }
    ],
    schritte: {
      de: ['Schnitzel flach klopfen.', 'Mit Kajmak und Schinken belegen und aufrollen.', 'In Mehl, Ei und Bröseln wenden.', 'In heißem Öl goldbraun ausbacken.', 'Mit Tatarsauce servieren.'],
      sr: ['Шницле истањити.', 'Обложити кајмаком и шунком и уролати.', 'Уваљати у брашно, јаје и презле.', 'Испржити у врелом уљу до златне боје.', 'Послужити са тартар сосом.'],
      hr: ['Odreske stanjiti.', 'Obložiti kajmakom i šunkom i urolati.', 'Uvaljati u brašno, jaje i mrvice.', 'Ispržiti u vrućem ulju do zlatne boje.', 'Poslužiti s tartar umakom.'],
      ba: ['Odreske stanjiti.', 'Obložiti kajmakom i šunkom i urolati.', 'Uvaljati u brašno, jaje i prezle.', 'Ispržiti u vrućem ulju do zlatne boje.', 'Poslužiti sa tartar sosom.'],
      en: ['Pound the escalopes flat.', 'Top with kajmak and ham and roll up.', 'Coat in flour, egg and breadcrumbs.', 'Fry golden in hot oil.', 'Serve with tartare sauce.']
    }
  },

  {
    id: 'muckalica', kueche: 'balkan', portionen: 4, dauer_min: 50,
    titel: { de: 'Mućkalica', sr: 'Мућкалица', hr: 'Mućkalica', ba: 'Mućkalica', en: 'Mućkalica' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'gemischtes Fleisch', sr: 'мешано месо', hr: 'miješano meso', ba: 'miješano meso', en: 'mixed meat' } },
      { menge: 3, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell peppers' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 3, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Paprikapulver, Chili', sr: 'уље, алева паприка, чили', hr: 'ulje, mljevena paprika, čili', ba: 'ulje, mljevena paprika, čili', en: 'oil, paprika, chilli' } }
    ],
    schritte: {
      de: ['Fleisch in Stücke schneiden und anbraten.', 'Zwiebeln und Paprika zugeben.', 'Tomaten und Paprikapulver zugeben.', 'Zugedeckt ca. 30 Minuten schmoren.', 'Scharf abschmecken und mit Brot servieren.'],
      sr: ['Месо исећи на комаде и пропржити.', 'Додати лук и паприку.', 'Додати парадајз и алеву паприку.', 'Поклопљено динстати око 30 минута.', 'Зачинити љуто и послужити са хлебом.'],
      hr: ['Meso narezati na komade i popržiti.', 'Dodati luk i papriku.', 'Dodati rajčice i mljevenu papriku.', 'Poklopljeno pirjati oko 30 minuta.', 'Začiniti ljuto i poslužiti s kruhom.'],
      ba: ['Meso narezati na komade i popržiti.', 'Dodati luk i papriku.', 'Dodati paradajz i mljevenu papriku.', 'Poklopljeno dinstati oko 30 minuta.', 'Začiniti ljuto i poslužiti sa hljebom.'],
      en: ['Cut the meat into pieces and sear.', 'Add onions and peppers.', 'Add tomatoes and paprika.', 'Stew covered for about 30 minutes.', 'Season spicy and serve with bread.']
    }
  },

  {
    id: 'punjene_tikvice', kueche: 'balkan', portionen: 4, dauer_min: 60,
    titel: { de: 'Gefüllte Zucchini', sr: 'Пуњене тиквице', hr: 'Punjene tikvice', ba: 'Punjene tikvice', en: 'Stuffed courgettes' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Zucchini', sr: 'тиквице', hr: 'tikvice', ba: 'tikvice', en: 'courgettes' } },
      { menge: 400, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 80, einheit: 'g', name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 200, einheit: 'ml', name: { de: 'Sauerrahm', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'sour cream' } },
      { menge: null, einheit: 'ng', name: { de: 'Zwiebel, Salz, Öl', sr: 'лук, со, уље', hr: 'luk, sol, ulje', ba: 'luk, so, ulje', en: 'onion, salt, oil' } }
    ],
    schritte: {
      de: ['Zucchini aushöhlen.', 'Hackfleisch mit Reis, Zwiebel und Salz mischen.', 'Zucchini mit der Masse füllen.', 'In eine Form legen und mit etwas Wasser bei 180 Grad backen.', 'Mit Sauerrahm servieren.'],
      sr: ['Тиквице издубити.', 'Млевено месо помешати са пиринчем, луком и сољу.', 'Тиквице напунити масом.', 'Ставити у калуп са мало воде и пећи на 180 степени.', 'Послужити са киселом павлаком.'],
      hr: ['Tikvice izdubiti.', 'Mljeveno meso pomiješati s rižom, lukom i soli.', 'Tikvice napuniti masom.', 'Staviti u kalup s malo vode i peći na 180 stupnjeva.', 'Poslužiti s kiselim vrhnjem.'],
      ba: ['Tikvice izdubiti.', 'Mljeveno meso pomiješati sa rižom, lukom i soli.', 'Tikvice napuniti masom.', 'Staviti u kalup sa malo vode i peći na 180 stepeni.', 'Poslužiti sa kiselom pavlakom.'],
      en: ['Hollow out the courgettes.', 'Mix minced meat with rice, onion and salt.', 'Fill the courgettes with the mixture.', 'Place in a dish with a little water and bake at 180 degrees.', 'Serve with sour cream.']
    }
  },

  {
    id: 'tufahije', kueche: 'balkan', portionen: 6, dauer_min: 60,
    titel: { de: 'Tufahije (gefüllte Äpfel)', sr: 'Туфахије', hr: 'Tufahije', ba: 'Tufahije', en: 'Tufahije (stuffed apples)' },
    zutaten: [
      { menge: 6, einheit: 'stk', name: { de: 'Äpfel', sr: 'јабуке', hr: 'jabuke', ba: 'jabuke', en: 'apples' } },
      { menge: 150, einheit: 'g', name: { de: 'gemahlene Walnüsse', sr: 'млевени ораси', hr: 'mljeveni orasi', ba: 'mljeveni orasi', en: 'ground walnuts' } },
      { menge: 200, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 200, einheit: 'ml', name: { de: 'Schlagsahne', sr: 'слатка павлака', hr: 'slatko vrhnje', ba: 'slatka pavlaka', en: 'whipped cream' } },
      { menge: null, einheit: 'ng', name: { de: 'Wasser, Zitrone', sr: 'вода, лимун', hr: 'voda, limun', ba: 'voda, limun', en: 'water, lemon' } }
    ],
    schritte: {
      de: ['Äpfel schälen und im Zuckersirup weich kochen.', 'Kerngehäuse aushöhlen.', 'Walnüsse mit etwas Zucker und Sirup mischen.', 'Äpfel mit der Nussmasse füllen.', 'Kühlen und mit Schlagsahne servieren.'],
      sr: ['Јабуке огулити и скувати у шећерном сирупу до мекоће.', 'Издубити средину.', 'Орахе помешати са мало шећера и сирупа.', 'Јабуке напунити масом од ораха.', 'Охладити и послужити са шлагом.'],
      hr: ['Jabuke oguliti i skuhati u šećernom sirupu do mekoće.', 'Izdubiti sredinu.', 'Orahe pomiješati s malo šećera i sirupa.', 'Jabuke napuniti masom od oraha.', 'Ohladiti i poslužiti sa šlagom.'],
      ba: ['Jabuke oguliti i skuhati u šećernom sirupu do mekoće.', 'Izdubiti sredinu.', 'Orahe pomiješati sa malo šećera i sirupa.', 'Jabuke napuniti masom od oraha.', 'Ohladiti i poslužiti sa šlagom.'],
      en: ['Peel the apples and cook soft in sugar syrup.', 'Hollow out the cores.', 'Mix walnuts with a little sugar and syrup.', 'Fill the apples with the walnut mixture.', 'Chill and serve with whipped cream.']
    }
  },

  {
    id: 'begova_corba', kueche: 'balkan', portionen: 4, dauer_min: 60,
    titel: { de: 'Bosnische Begova Čorba', sr: 'Бегова чорба', hr: 'Begova juha', ba: 'Begova čorba', en: 'Bey\'s soup' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Hähnchen', sr: 'пилетина', hr: 'piletina', ba: 'piletina', en: 'chicken' } },
      { menge: 100, einheit: 'g', name: { de: 'Okra (Bamia)', sr: 'бамија', hr: 'bamija', ba: 'bamija', en: 'okra' } },
      { menge: 1, einheit: 'stk', name: { de: 'Karotte', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrot' } },
      { menge: 200, einheit: 'ml', name: { de: 'Sauerrahm', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'sour cream' } },
      { menge: null, einheit: 'ng', name: { de: 'Mehl, Salz, Butter', sr: 'брашно, со, путер', hr: 'brašno, sol, maslac', ba: 'brašno, so, maslac', en: 'flour, salt, butter' } }
    ],
    schritte: {
      de: ['Hähnchen mit Karotte weich kochen und Brühe aufheben.', 'Fleisch würfeln, Okra zugeben.', 'Eine helle Mehlschwitze zubereiten und mit Brühe ablöschen.', 'Alles verrühren und köcheln.', 'Mit Sauerrahm verfeinern und servieren.'],
      sr: ['Пилетину са шаргарепом скувати и сачувати супу.', 'Месо исецкати, додати бамију.', 'Направити светлу запршку и разредити супом.', 'Све сјединити и кувати.', 'Дотерати киселом павлаком и послужити.'],
      hr: ['Piletinu s mrkvom skuhati i sačuvati temeljac.', 'Meso narezati, dodati bamiju.', 'Napraviti svijetlu zapršku i razrijediti temeljcem.', 'Sve sjediniti i kuhati.', 'Doraditi kiselim vrhnjem i poslužiti.'],
      ba: ['Piletinu sa mrkvom skuhati i sačuvati supu.', 'Meso narezati, dodati bamiju.', 'Napraviti svijetlu zapršku i razrijediti supom.', 'Sve sjediniti i kuhati.', 'Doraditi kiselom pavlakom i poslužiti.'],
      en: ['Boil the chicken with carrot soft and keep the broth.', 'Dice the meat, add the okra.', 'Make a light roux and deglaze with broth.', 'Combine everything and simmer.', 'Finish with sour cream and serve.']
    }
  },

  {
    id: 'klepe', kueche: 'balkan', portionen: 4, dauer_min: 75,
    titel: { de: 'Klepe (bosnische Teigtaschen)', sr: 'Клепе', hr: 'Klepe', ba: 'Klepe', en: 'Klepe (dumplings)' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 1, einheit: 'stk', name: { de: 'Ei', sr: 'јаје', hr: 'jaje', ba: 'jaje', en: 'egg' } },
      { menge: 300, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 200, einheit: 'g', name: { de: 'Joghurt', sr: 'јогурт', hr: 'jogurt', ba: 'jogurt', en: 'yoghurt' } },
      { menge: null, einheit: 'ng', name: { de: 'Knoblauch, Salz, Butter', sr: 'бели лук, со, путер', hr: 'češnjak, sol, maslac', ba: 'bijeli luk, so, maslac', en: 'garlic, salt, butter' } }
    ],
    schritte: {
      de: ['Aus Mehl, Ei, Wasser und Salz einen Teig kneten.', 'Dünn ausrollen und mit Hackfleisch füllen.', 'Kleine Quadrate formen und verschließen.', 'In Salzwasser garen.', 'Mit Knoblauch-Joghurt und zerlassener Butter servieren.'],
      sr: ['Од брашна, јаја, воде и соли умесити тесто.', 'Танко развући и напунити млевеним месом.', 'Обликовати мале квадрате и затворити.', 'Скувати у сланој води.', 'Послужити са јогуртом од белог лука и отопљеним путером.'],
      hr: ['Od brašna, jaja, vode i soli umijesiti tijesto.', 'Tanko razvući i napuniti mljevenim mesom.', 'Oblikovati male kvadrate i zatvoriti.', 'Skuhati u slanoj vodi.', 'Poslužiti s jogurtom od češnjaka i otopljenim maslacem.'],
      ba: ['Od brašna, jaja, vode i soli umijesiti tijesto.', 'Tanko razvući i napuniti mljevenim mesom.', 'Oblikovati male kvadrate i zatvoriti.', 'Skuhati u slanoj vodi.', 'Poslužiti sa jogurtom od bijelog luka i otopljenim maslacem.'],
      en: ['Knead a dough from flour, egg, water and salt.', 'Roll out thinly and fill with minced meat.', 'Form small squares and seal.', 'Cook in salted water.', 'Serve with garlic yoghurt and melted butter.']
    }
  },

  {
    id: 'urnebes', kueche: 'balkan', portionen: 6, dauer_min: 15,
    titel: { de: 'Urnebes-Salat', sr: 'Урнебес салата', hr: 'Urnebes salata', ba: 'Urnebes salata', en: 'Urnebes (spicy cheese salad)' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Weißkäse', sr: 'бели сир', hr: 'bijeli sir', ba: 'bijeli sir', en: 'white cheese' } },
      { menge: 2, einheit: 'stk', name: { de: 'scharfe Paprika', sr: 'љуте паприке', hr: 'ljute paprike', ba: 'ljute paprike', en: 'hot peppers' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'tl', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Mayonnaise', sr: 'уље, мајонез', hr: 'ulje, majoneza', ba: 'ulje, majoneza', en: 'oil, mayonnaise' } }
    ],
    schritte: {
      de: ['Käse zerbröckeln.', 'Scharfe Paprika und Knoblauch fein hacken.', 'Alles mit Paprikapulver mischen.', 'Mit Öl und etwas Mayonnaise cremig rühren.', 'Als Aufstrich oder Beilage servieren.'],
      sr: ['Сир измрвити.', 'Љуте паприке и бели лук ситно исецкати.', 'Све помешати са алевом паприком.', 'Уљем и мало мајонеза умутити до кремастости.', 'Послужити као намаз или прилог.'],
      hr: ['Sir izmrviti.', 'Ljute paprike i češnjak sitno nasjeckati.', 'Sve pomiješati s mljevenom paprikom.', 'Uljem i malo majoneze umutiti do kremastosti.', 'Poslužiti kao namaz ili prilog.'],
      ba: ['Sir izmrviti.', 'Ljute paprike i bijeli luk sitno nasjeckati.', 'Sve pomiješati sa mljevenom paprikom.', 'Uljem i malo majoneze umutiti do kremastosti.', 'Poslužiti kao namaz ili prilog.'],
      en: ['Crumble the cheese.', 'Finely chop hot peppers and garlic.', 'Mix everything with paprika.', 'Whisk creamy with oil and a little mayonnaise.', 'Serve as a spread or side.']
    }
  },

  // ---- NACHSCHLAG ITALIENISCH ----------------------------------------------
  {
    id: 'spaghetti_aglio_olio', kueche: 'italienisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Spaghetti Aglio e Olio', sr: 'Шпагете са белим луком', hr: 'Špageti s češnjakom', ba: 'Špagete sa bijelim lukom', en: 'Spaghetti aglio e olio' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Spaghetti', sr: 'шпагете', hr: 'špageti', ba: 'špagete', en: 'spaghetti' } },
      { menge: 5, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 80, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: 1, einheit: 'stk', name: { de: 'Chilischote', sr: 'љута папричица', hr: 'ljuta papričica', ba: 'ljuta papričica', en: 'chilli' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } }
    ],
    schritte: {
      de: ['Spaghetti al dente kochen.', 'Knoblauch in Scheiben in Olivenöl sanft anbraten.', 'Chili zugeben.', 'Nudeln mit etwas Kochwasser zugeben und schwenken.', 'Mit Petersilie servieren.'],
      sr: ['Шпагете скувати ал денте.', 'Бели лук на листиће лагано пропржити на маслиновом уљу.', 'Додати чили.', 'Додати тестенину са мало воде од кувања и промешати.', 'Послужити са першуном.'],
      hr: ['Špagete skuhati al dente.', 'Češnjak na listiće lagano popržiti na maslinovom ulju.', 'Dodati čili.', 'Dodati tjesteninu s malo vode od kuhanja i promiješati.', 'Poslužiti s peršinom.'],
      ba: ['Špagete skuhati al dente.', 'Bijeli luk na listiće lagano popržiti na maslinovom ulju.', 'Dodati čili.', 'Dodati tjesteninu sa malo vode od kuhanja i promiješati.', 'Poslužiti sa peršunom.'],
      en: ['Cook the spaghetti al dente.', 'Gently fry sliced garlic in olive oil.', 'Add the chilli.', 'Add pasta with a little cooking water and toss.', 'Serve with parsley.']
    }
  },

  {
    id: 'penne_al_forno', kueche: 'italienisch', portionen: 4, dauer_min: 50,
    titel: { de: 'Überbackene Penne', sr: 'Запечене пене', hr: 'Zapečeni penne', ba: 'Zapečeni penne', en: 'Baked penne' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Penne', sr: 'пене тестенина', hr: 'penne tjestenina', ba: 'penne tjestenina', en: 'penne pasta' } },
      { menge: 500, einheit: 'ml', name: { de: 'Tomatensauce', sr: 'сос од парадајза', hr: 'umak od rajčice', ba: 'sos od paradajza', en: 'tomato sauce' } },
      { menge: 200, einheit: 'g', name: { de: 'Mozzarella', sr: 'моцарела', hr: 'mozzarella', ba: 'mozzarella', en: 'mozzarella' } },
      { menge: 80, einheit: 'g', name: { de: 'Parmesan', sr: 'пармезан', hr: 'parmezan', ba: 'parmezan', en: 'parmesan' } },
      { menge: null, einheit: 'ng', name: { de: 'Basilikum, Salz', sr: 'босиљак, со', hr: 'bosiljak, sol', ba: 'bosiljak, so', en: 'basil, salt' } }
    ],
    schritte: {
      de: ['Penne halbgar kochen.', 'Mit Tomatensauce mischen.', 'In eine Form geben und mit Mozzarella belegen.', 'Mit Parmesan bestreuen.', 'Bei 200 Grad ca. 20 Minuten goldbraun überbacken.'],
      sr: ['Пене полукувати.', 'Помешати са сосом од парадајза.', 'Ставити у калуп и обложити моцарелом.', 'Посути пармезаном.', 'Запећи на 200 степени око 20 минута до златне боје.'],
      hr: ['Penne polukuhati.', 'Pomiješati s umakom od rajčice.', 'Staviti u kalup i obložiti mozzarellom.', 'Posuti parmezanom.', 'Zapeći na 200 stupnjeva oko 20 minuta do zlatne boje.'],
      ba: ['Penne polukuhati.', 'Pomiješati sa sosom od paradajza.', 'Staviti u kalup i obložiti mozzarellom.', 'Posuti parmezanom.', 'Zapeći na 200 stepeni oko 20 minuta do zlatne boje.'],
      en: ['Parboil the penne.', 'Mix with tomato sauce.', 'Put in a dish and top with mozzarella.', 'Sprinkle with parmesan.', 'Bake at 200 degrees for about 20 minutes until golden.']
    }
  },

  {
    id: 'tortellini_panna', kueche: 'italienisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Tortellini in Sahnesauce', sr: 'Тортелини у павлаци', hr: 'Tortellini u vrhnju', ba: 'Tortellini u pavlaci', en: 'Tortellini in cream sauce' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Tortellini', sr: 'тортелини', hr: 'tortellini', ba: 'tortellini', en: 'tortellini' } },
      { menge: 250, einheit: 'ml', name: { de: 'Sahne', sr: 'слатка павлака', hr: 'slatko vrhnje', ba: 'slatka pavlaka', en: 'cream' } },
      { menge: 100, einheit: 'g', name: { de: 'Schinken', sr: 'шунка', hr: 'šunka', ba: 'šunka', en: 'ham' } },
      { menge: 80, einheit: 'g', name: { de: 'Parmesan', sr: 'пармезан', hr: 'parmezan', ba: 'parmezan', en: 'parmesan' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Muskat', sr: 'со, мушкатни орашчић', hr: 'sol, muškatni oraščić', ba: 'so, muškatni oraščić', en: 'salt, nutmeg' } }
    ],
    schritte: {
      de: ['Tortellini in Salzwasser garen.', 'Schinken in der Sahne erwärmen.', 'Parmesan einrühren.', 'Mit Salz und Muskat würzen.', 'Tortellini unterheben und servieren.'],
      sr: ['Тортелине скувати у сланој води.', 'Шунку загрејати у павлаци.', 'Умешати пармезан.', 'Зачинити сољу и мушкатним орашчићем.', 'Умешати тортелине и послужити.'],
      hr: ['Tortellini skuhati u slanoj vodi.', 'Šunku zagrijati u vrhnju.', 'Umiješati parmezan.', 'Začiniti soli i muškatnim oraščićem.', 'Umiješati tortellini i poslužiti.'],
      ba: ['Tortellini skuhati u slanoj vodi.', 'Šunku zagrijati u pavlaci.', 'Umiješati parmezan.', 'Začiniti soli i muškatnim oraščićem.', 'Umiješati tortellini i poslužiti.'],
      en: ['Cook the tortellini in salted water.', 'Warm the ham in the cream.', 'Stir in the parmesan.', 'Season with salt and nutmeg.', 'Fold in the tortellini and serve.']
    }
  },

  {
    id: 'ossobuco', kueche: 'italienisch', portionen: 4, dauer_min: 120,
    titel: { de: 'Ossobuco', sr: 'Особуко', hr: 'Ossobuco', ba: 'Ossobuco', en: 'Ossobuco' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Kalbsbeinscheiben', sr: 'телеће коленице', hr: 'teleće koljenice', ba: 'teleće koljenice', en: 'veal shanks' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 200, einheit: 'ml', name: { de: 'Weißwein', sr: 'бело вино', hr: 'bijelo vino', ba: 'bijelo vino', en: 'white wine' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: null, einheit: 'ng', name: { de: 'Mehl, Öl, Salz', sr: 'брашно, уље, со', hr: 'brašno, ulje, sol', ba: 'brašno, ulje, so', en: 'flour, oil, salt' } }
    ],
    schritte: {
      de: ['Beinscheiben mehlieren und rundum anbraten.', 'Gemüse zugeben und andünsten.', 'Mit Weißwein ablöschen.', 'Tomaten zugeben und zugedeckt ca. 90 Minuten schmoren.', 'Mit Risotto servieren.'],
      sr: ['Коленице побрашнити и пропржити са свих страна.', 'Додати поврће и продинстати.', 'Залити белим вином.', 'Додати парадајз и поклопљено динстати око 90 минута.', 'Послужити са ризотом.'],
      hr: ['Koljenice pobrašniti i popržiti sa svih strana.', 'Dodati povrće i popirjati.', 'Zaliti bijelim vinom.', 'Dodati rajčice i poklopljeno pirjati oko 90 minuta.', 'Poslužiti s rižotom.'],
      ba: ['Koljenice pobrašniti i popržiti sa svih strana.', 'Dodati povrće i podinstati.', 'Zaliti bijelim vinom.', 'Dodati paradajz i poklopljeno dinstati oko 90 minuta.', 'Poslužiti sa rižotom.'],
      en: ['Flour the shanks and brown all over.', 'Add the vegetables and sauté.', 'Deglaze with white wine.', 'Add tomatoes and stew covered for about 90 minutes.', 'Serve with risotto.']
    }
  },

  {
    id: 'bruschetta', kueche: 'italienisch', portionen: 4, dauer_min: 15,
    titel: { de: 'Bruschetta', sr: 'Брускета', hr: 'Bruschetta', ba: 'Bruschetta', en: 'Bruschetta' },
    zutaten: [
      { menge: 8, einheit: 'stk', name: { de: 'Brotscheiben', sr: 'кришке хлеба', hr: 'kriške kruha', ba: 'kriške hljeba', en: 'slices of bread' } },
      { menge: 4, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 2, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 1, einheit: 'bund', name: { de: 'Basilikum', sr: 'босиљак', hr: 'bosiljak', ba: 'bosiljak', en: 'basil' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Salz', sr: 'маслиново уље, со', hr: 'maslinovo ulje, sol', ba: 'maslinovo ulje, so', en: 'olive oil, salt' } }
    ],
    schritte: {
      de: ['Brotscheiben rösten.', 'Mit Knoblauch einreiben.', 'Tomaten würfeln und mit Basilikum, Öl und Salz mischen.', 'Auf das Brot geben.', 'Mit Olivenöl beträufeln und servieren.'],
      sr: ['Кришке хлеба препећи.', 'Натрљати белим луком.', 'Парадајз исецкати и помешати са босиљком, уљем и сољу.', 'Ставити на хлеб.', 'Прелити маслиновим уљем и послужити.'],
      hr: ['Kriške kruha popeći.', 'Natrljati češnjakom.', 'Rajčice narezati i pomiješati s bosiljkom, uljem i soli.', 'Staviti na kruh.', 'Preliti maslinovim uljem i poslužiti.'],
      ba: ['Kriške hljeba popeći.', 'Natrljati bijelim lukom.', 'Paradajz narezati i pomiješati sa bosiljkom, uljem i soli.', 'Staviti na hljeb.', 'Preliti maslinovim uljem i poslužiti.'],
      en: ['Toast the bread slices.', 'Rub with garlic.', 'Dice the tomatoes and mix with basil, oil and salt.', 'Spoon onto the bread.', 'Drizzle with olive oil and serve.']
    }
  },

  {
    id: 'focaccia', kueche: 'italienisch', portionen: 8, dauer_min: 120,
    titel: { de: 'Focaccia', sr: 'Фокача', hr: 'Focaccia', ba: 'Focaccia', en: 'Focaccia' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 7, einheit: 'g', name: { de: 'Trockenhefe', sr: 'суви квасац', hr: 'suhi kvasac', ba: 'suhi kvasac', en: 'dry yeast' } },
      { menge: 350, einheit: 'ml', name: { de: 'lauwarmes Wasser', sr: 'млака вода', hr: 'mlaka voda', ba: 'mlaka voda', en: 'lukewarm water' } },
      { menge: 60, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Rosmarin', sr: 'со, рузмарин', hr: 'sol, ružmarin', ba: 'so, ružmarin', en: 'salt, rosemary' } }
    ],
    schritte: {
      de: ['Mehl, Hefe, Wasser, Öl und Salz zu einem Teig verrühren.', 'Ca. 1 Stunde gehen lassen.', 'In ein geöltes Blech drücken und Mulden eindrücken.', 'Mit Olivenöl, Salz und Rosmarin bestreuen.', 'Bei 220 Grad ca. 20 Minuten backen.'],
      sr: ['Брашно, квасац, воду, уље и со умутити у тесто.', 'Оставити да нарасте око 1 сат.', 'Утиснути у подмазан плех и направити удубљења.', 'Посути маслиновим уљем, сољу и рузмарином.', 'Пећи на 220 степени око 20 минута.'],
      hr: ['Brašno, kvasac, vodu, ulje i sol umutiti u tijesto.', 'Ostaviti da naraste oko 1 sat.', 'Utisnuti u podmazan lim i napraviti udubljenja.', 'Posuti maslinovim uljem, soli i ružmarinom.', 'Peći na 220 stupnjeva oko 20 minuta.'],
      ba: ['Brašno, kvasac, vodu, ulje i so umutiti u tijesto.', 'Ostaviti da naraste oko 1 sat.', 'Utisnuti u podmazan pleh i napraviti udubljenja.', 'Posuti maslinovim uljem, soli i ružmarinom.', 'Peći na 220 stepeni oko 20 minuta.'],
      en: ['Mix flour, yeast, water, oil and salt into a dough.', 'Let rise for about 1 hour.', 'Press into an oiled tray and make dimples.', 'Sprinkle with olive oil, salt and rosemary.', 'Bake at 220 degrees for about 20 minutes.']
    }
  },

  {
    id: 'pesto_pasta', kueche: 'italienisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Pasta mit Pesto', sr: 'Тестенина са пестом', hr: 'Tjestenina s pestom', ba: 'Tjestenina sa pestom', en: 'Pasta with pesto' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Pasta', sr: 'тестенина', hr: 'tjestenina', ba: 'tjestenina', en: 'pasta' } },
      { menge: 60, einheit: 'g', name: { de: 'Basilikum', sr: 'босиљак', hr: 'bosiljak', ba: 'bosiljak', en: 'basil' } },
      { menge: 40, einheit: 'g', name: { de: 'Pinienkerne', sr: 'пињоли', hr: 'pinjoli', ba: 'pinjoli', en: 'pine nuts' } },
      { menge: 60, einheit: 'g', name: { de: 'Parmesan', sr: 'пармезан', hr: 'parmezan', ba: 'parmezan', en: 'parmesan' } },
      { menge: 80, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } }
    ],
    schritte: {
      de: ['Pasta al dente kochen.', 'Basilikum, Pinienkerne, Parmesan und Öl fein pürieren.', 'Pesto mit Salz abschmecken.', 'Pasta mit etwas Kochwasser und Pesto mischen.', 'Sofort servieren.'],
      sr: ['Тестенину скувати ал денте.', 'Босиљак, пињоле, пармезан и уље фино изблендати.', 'Песто зачинити сољу.', 'Тестенину помешати са мало воде од кувања и пестом.', 'Одмах послужити.'],
      hr: ['Tjesteninu skuhati al dente.', 'Bosiljak, pinjole, parmezan i ulje fino izblendati.', 'Pesto začiniti soli.', 'Tjesteninu pomiješati s malo vode od kuhanja i pestom.', 'Odmah poslužiti.'],
      ba: ['Tjesteninu skuhati al dente.', 'Bosiljak, pinjole, parmezan i ulje fino izblendati.', 'Pesto začiniti soli.', 'Tjesteninu pomiješati sa malo vode od kuhanja i pestom.', 'Odmah poslužiti.'],
      en: ['Cook the pasta al dente.', 'Purée basil, pine nuts, parmesan and oil finely.', 'Season the pesto with salt.', 'Mix pasta with a little cooking water and pesto.', 'Serve immediately.']
    }
  },

  {
    id: 'calzone', kueche: 'italienisch', portionen: 2, dauer_min: 40,
    titel: { de: 'Calzone', sr: 'Калцоне', hr: 'Calzone', ba: 'Calzone', en: 'Calzone' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Pizzateig', sr: 'тесто за пицу', hr: 'tijesto za pizzu', ba: 'tijesto za pizzu', en: 'pizza dough' } },
      { menge: 150, einheit: 'g', name: { de: 'Tomatensauce', sr: 'сос од парадајза', hr: 'umak od rajčice', ba: 'sos od paradajza', en: 'tomato sauce' } },
      { menge: 150, einheit: 'g', name: { de: 'Mozzarella', sr: 'моцарела', hr: 'mozzarella', ba: 'mozzarella', en: 'mozzarella' } },
      { menge: 100, einheit: 'g', name: { de: 'Schinken', sr: 'шунка', hr: 'šunka', ba: 'šunka', en: 'ham' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Oregano', sr: 'маслиново уље, оригано', hr: 'maslinovo ulje, origano', ba: 'maslinovo ulje, origano', en: 'olive oil, oregano' } }
    ],
    schritte: {
      de: ['Teig zu einem Kreis ausrollen.', 'Eine Hälfte mit Sauce, Käse und Schinken belegen.', 'Zuklappen und die Ränder fest andrücken.', 'Mit Olivenöl bestreichen.', 'Bei 220 Grad ca. 15 Minuten goldbraun backen.'],
      sr: ['Тесто развући у круг.', 'Једну половину обложити сосом, сиром и шунком.', 'Преклопити и добро притиснути ивице.', 'Премазати маслиновим уљем.', 'Пећи на 220 степени око 15 минута до златне боје.'],
      hr: ['Tijesto razvući u krug.', 'Jednu polovinu obložiti umakom, sirom i šunkom.', 'Preklopiti i dobro pritisnuti rubove.', 'Premazati maslinovim uljem.', 'Peći na 220 stupnjeva oko 15 minuta do zlatne boje.'],
      ba: ['Tijesto razvući u krug.', 'Jednu polovinu obložiti sosom, sirom i šunkom.', 'Preklopiti i dobro pritisnuti rubove.', 'Premazati maslinovim uljem.', 'Peći na 220 stepeni oko 15 minuta do zlatne boje.'],
      en: ['Roll the dough into a circle.', 'Top one half with sauce, cheese and ham.', 'Fold over and press the edges firmly.', 'Brush with olive oil.', 'Bake at 220 degrees for about 15 minutes until golden.']
    }
  },

  {
    id: 'arancini', kueche: 'italienisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Arancini (Reisbällchen)', sr: 'Аранчини', hr: 'Arancini', ba: 'Arancini', en: 'Arancini' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Risottoreis', sr: 'пиринач за ризото', hr: 'riža za rižoto', ba: 'riža za rižoto', en: 'risotto rice' } },
      { menge: 100, einheit: 'g', name: { de: 'Mozzarella', sr: 'моцарела', hr: 'mozzarella', ba: 'mozzarella', en: 'mozzarella' } },
      { menge: 100, einheit: 'g', name: { de: 'Erbsen', sr: 'грашак', hr: 'grašak', ba: 'grašak', en: 'peas' } },
      { menge: 150, einheit: 'g', name: { de: 'Semmelbrösel', sr: 'презле', hr: 'krušne mrvice', ba: 'prezle', en: 'breadcrumbs' } },
      { menge: null, einheit: 'ng', name: { de: 'Ei, Öl, Salz', sr: 'јаје, уље, со', hr: 'jaje, ulje, sol', ba: 'jaje, ulje, so', en: 'egg, oil, salt' } }
    ],
    schritte: {
      de: ['Risotto kochen und abkühlen lassen.', 'Mit Erbsen mischen.', 'Portionen formen und je ein Stück Mozzarella einschließen.', 'In Ei und Bröseln wenden.', 'In heißem Öl goldbraun frittieren.'],
      sr: ['Ризото скувати и охладити.', 'Помешати са грашком.', 'Обликовати порције и у сваку ставити комад моцареле.', 'Уваљати у јаје и презле.', 'Пржити у врелом уљу до златне боје.'],
      hr: ['Rižoto skuhati i ohladiti.', 'Pomiješati s graškom.', 'Oblikovati porcije i u svaku staviti komad mozzarelle.', 'Uvaljati u jaje i mrvice.', 'Pržiti u vrućem ulju do zlatne boje.'],
      ba: ['Rižoto skuhati i ohladiti.', 'Pomiješati sa graškom.', 'Oblikovati porcije i u svaku staviti komad mozzarelle.', 'Uvaljati u jaje i prezle.', 'Pržiti u vrućem ulju do zlatne boje.'],
      en: ['Cook the risotto and let cool.', 'Mix with peas.', 'Form portions and enclose a piece of mozzarella in each.', 'Coat in egg and breadcrumbs.', 'Deep-fry in hot oil until golden.']
    }
  },

  {
    id: 'cannelloni', kueche: 'italienisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Cannelloni', sr: 'Канелони', hr: 'Cannelloni', ba: 'Cannelloni', en: 'Cannelloni' },
    zutaten: [
      { menge: 16, einheit: 'stk', name: { de: 'Cannelloni-Röhren', sr: 'канелони цеви', hr: 'cannelloni cijevi', ba: 'cannelloni cijevi', en: 'cannelloni tubes' } },
      { menge: 400, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 500, einheit: 'ml', name: { de: 'Tomatensauce', sr: 'сос од парадајза', hr: 'umak od rajčice', ba: 'sos od paradajza', en: 'tomato sauce' } },
      { menge: 300, einheit: 'ml', name: { de: 'Béchamelsauce', sr: 'бешамел сос', hr: 'bešamel umak', ba: 'bešamel sos', en: 'béchamel sauce' } },
      { menge: 80, einheit: 'g', name: { de: 'Parmesan', sr: 'пармезан', hr: 'parmezan', ba: 'parmezan', en: 'parmesan' } }
    ],
    schritte: {
      de: ['Hackfleisch anbraten und würzen.', 'Cannelloni mit dem Fleisch füllen.', 'Etwas Tomatensauce in die Form geben und Röhren einlegen.', 'Mit restlicher Tomaten- und Béchamelsauce bedecken.', 'Mit Parmesan bestreuen und bei 190 Grad ca. 30 Minuten backen.'],
      sr: ['Млевено месо пропржити и зачинити.', 'Канелоне напунити месом.', 'Мало соса од парадајза ставити у калуп и сложити цеви.', 'Прекрити остатком соса од парадајза и бешамелом.', 'Посути пармезаном и пећи на 190 степени око 30 минута.'],
      hr: ['Mljeveno meso popržiti i začiniti.', 'Cannelloni napuniti mesom.', 'Malo umaka od rajčice staviti u kalup i složiti cijevi.', 'Prekriti ostatkom umaka od rajčice i bešamelom.', 'Posuti parmezanom i peći na 190 stupnjeva oko 30 minuta.'],
      ba: ['Mljeveno meso popržiti i začiniti.', 'Cannelloni napuniti mesom.', 'Malo sosa od paradajza staviti u kalup i složiti cijevi.', 'Prekriti ostatkom sosa od paradajza i bešamelom.', 'Posuti parmezanom i peći na 190 stepeni oko 30 minuta.'],
      en: ['Fry the minced meat and season.', 'Fill the cannelloni with the meat.', 'Spread a little tomato sauce in the dish and lay in the tubes.', 'Cover with the rest of the tomato and béchamel sauce.', 'Sprinkle with parmesan and bake at 190 degrees for about 30 minutes.']
    }
  },

  // ---- NACHSCHLAG DEUTSCH --------------------------------------------------
  {
    id: 'gulaschsuppe', kueche: 'deutsch', portionen: 4, dauer_min: 60,
    titel: { de: 'Gulaschsuppe', sr: 'Гулаш супа', hr: 'Gulaš juha', ba: 'Gulaš supa', en: 'Goulash soup' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Rindergulasch', sr: 'говеђи гулаш', hr: 'goveđi gulaš', ba: 'goveđi gulaš', en: 'diced beef' } },
      { menge: 3, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 3, einheit: 'stk', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 2, einheit: 'el', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Salz, Kümmel', sr: 'уље, со, ким', hr: 'ulje, sol, kim', ba: 'ulje, so, kim', en: 'oil, salt, caraway' } }
    ],
    schritte: {
      de: ['Zwiebeln in Öl anschwitzen.', 'Fleisch zugeben und anbraten.', 'Paprikapulver einrühren und mit Wasser aufgießen.', 'Kartoffelwürfel zugeben.', 'Ca. 45 Minuten köcheln und abschmecken.'],
      sr: ['Лук продинстати на уљу.', 'Додати месо и пропржити.', 'Умешати алеву паприку и залити водом.', 'Додати коцкице кромпира.', 'Кувати око 45 минута и зачинити.'],
      hr: ['Luk popirjati na ulju.', 'Dodati meso i popržiti.', 'Umiješati mljevenu papriku i zaliti vodom.', 'Dodati kockice krumpira.', 'Kuhati oko 45 minuta i začiniti.'],
      ba: ['Luk podinstati na ulju.', 'Dodati meso i popržiti.', 'Umiješati mljevenu papriku i zaliti vodom.', 'Dodati kockice krompira.', 'Kuhati oko 45 minuta i začiniti.'],
      en: ['Sweat the onions in oil.', 'Add the meat and sear.', 'Stir in paprika and pour in water.', 'Add diced potatoes.', 'Simmer for about 45 minutes and season.']
    }
  },

  {
    id: 'koenigsberger_klopse', kueche: 'deutsch', portionen: 4, dauer_min: 50,
    titel: { de: 'Königsberger Klopse', sr: 'Кенигсбершке ћуфте', hr: 'Kraljevske okruglice', ba: 'Kraljevske ćufte', en: 'Königsberger Klopse' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 1, einheit: 'stk', name: { de: 'Brötchen', sr: 'земичка', hr: 'peciva', ba: 'zemička', en: 'bread roll' } },
      { menge: 2, einheit: 'el', name: { de: 'Kapern', sr: 'капари', hr: 'kapari', ba: 'kapari', en: 'capers' } },
      { menge: 250, einheit: 'ml', name: { de: 'Sahne', sr: 'слатка павлака', hr: 'slatko vrhnje', ba: 'slatka pavlaka', en: 'cream' } },
      { menge: null, einheit: 'ng', name: { de: 'Ei, Zitrone, Mehl, Salz', sr: 'јаје, лимун, брашно, со', hr: 'jaje, limun, brašno, sol', ba: 'jaje, limun, brašno, so', en: 'egg, lemon, flour, salt' } }
    ],
    schritte: {
      de: ['Hackfleisch mit eingeweichtem Brötchen, Ei und Salz mischen.', 'Klöße formen.', 'In siedendem Salzwasser garen.', 'Aus Mehl, Butter und Brühe eine helle Sauce zubereiten.', 'Kapern, Zitrone und Sahne einrühren und Klöße darin servieren.'],
      sr: ['Млевено месо помешати са натопљеном земичком, јајетом и сољу.', 'Обликовати ћуфте.', 'Скувати у благо кључалој сланој води.', 'Од брашна, путера и супе направити светли сос.', 'Умешати капаре, лимун и павлаку и послужити ћуфте у сосу.'],
      hr: ['Mljeveno meso pomiješati s namočenim pecivom, jajem i soli.', 'Oblikovati okruglice.', 'Skuhati u lagano kipućoj slanoj vodi.', 'Od brašna, maslaca i temeljca napraviti svijetli umak.', 'Umiješati kapare, limun i vrhnje i poslužiti okruglice u umaku.'],
      ba: ['Mljeveno meso pomiješati sa namočenom zemičkom, jajem i soli.', 'Oblikovati ćufte.', 'Skuhati u lagano kipućoj slanoj vodi.', 'Od brašna, maslaca i supe napraviti svijetli sos.', 'Umiješati kapare, limun i pavlaku i poslužiti ćufte u sosu.'],
      en: ['Mix the meat with soaked roll, egg and salt.', 'Form dumplings.', 'Cook in gently simmering salted water.', 'Make a light sauce from flour, butter and broth.', 'Stir in capers, lemon and cream and serve the dumplings in it.']
    }
  },

  {
    id: 'sauerbraten', kueche: 'deutsch', portionen: 6, dauer_min: 180,
    titel: { de: 'Sauerbraten', sr: 'Кисело печење', hr: 'Kiselo pečenje', ba: 'Kiselo pečenje', en: 'Sauerbraten' },
    zutaten: [
      { menge: 1200, einheit: 'g', name: { de: 'Rinderbraten', sr: 'говеђе печење', hr: 'goveđe pečenje', ba: 'goveđe pečenje', en: 'beef roast' } },
      { menge: 250, einheit: 'ml', name: { de: 'Rotweinessig', sr: 'винско сирће', hr: 'vinski ocat', ba: 'vinsko sirće', en: 'red wine vinegar' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 50, einheit: 'g', name: { de: 'Lebkuchen', sr: 'медењак', hr: 'medenjak', ba: 'medenjak', en: 'gingerbread' } },
      { menge: null, einheit: 'ng', name: { de: 'Lorbeer, Nelken, Salz', sr: 'ловор, каранфилић, со', hr: 'lovor, klinčić, sol', ba: 'lovor, karanfilić, so', en: 'bay, cloves, salt' } }
    ],
    schritte: {
      de: ['Fleisch 2 Tage in Essig mit Gewürzen und Gemüse marinieren.', 'Abtropfen und rundum anbraten.', 'Marinade angießen und zugedeckt ca. 2,5 Stunden schmoren.', 'Fleisch herausnehmen, Sauce mit Lebkuchen binden.', 'In Scheiben mit Klößen servieren.'],
      sr: ['Месо 2 дана маринирати у сирћету са зачинима и поврћем.', 'Оцедити и пропржити са свих страна.', 'Долити маринаду и поклопљено динстати око 2,5 сата.', 'Извадити месо, сос згуснути медењаком.', 'Послужити на кришке са кнедлама.'],
      hr: ['Meso 2 dana marinirati u octu sa začinima i povrćem.', 'Ocijediti i popržiti sa svih strana.', 'Uliti marinadu i poklopljeno pirjati oko 2,5 sata.', 'Izvaditi meso, umak zgusnuti medenjakom.', 'Poslužiti na kriške s okruglicama.'],
      ba: ['Meso 2 dana marinirati u sirćetu sa začinima i povrćem.', 'Ocijediti i popržiti sa svih strana.', 'Uliti marinadu i poklopljeno dinstati oko 2,5 sata.', 'Izvaditi meso, sos zgusnuti medenjakom.', 'Poslužiti na kriške sa okruglicama.'],
      en: ['Marinate the meat in vinegar with spices and vegetables for 2 days.', 'Drain and brown all over.', 'Add the marinade and stew covered for about 2.5 hours.', 'Remove the meat, thicken the sauce with gingerbread.', 'Serve sliced with dumplings.']
    }
  },

  {
    id: 'flammkuchen', kueche: 'deutsch', portionen: 4, dauer_min: 30,
    titel: { de: 'Flammkuchen', sr: 'Фламкухен', hr: 'Flammkuchen', ba: 'Flammkuchen', en: 'Tarte flambée' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'dünner Teig', sr: 'танко тесто', hr: 'tanko tijesto', ba: 'tanko tijesto', en: 'thin dough' } },
      { menge: 200, einheit: 'g', name: { de: 'Schmand', sr: 'кисела павлака', hr: 'kiselo vrhnje', ba: 'kisela pavlaka', en: 'crème fraîche' } },
      { menge: 150, einheit: 'g', name: { de: 'Speckwürfel', sr: 'коцкице сланине', hr: 'kockice slanine', ba: 'kockice slanine', en: 'bacon cubes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer', sr: 'со, бибер', hr: 'sol, papar', ba: 'so, biber', en: 'salt, pepper' } }
    ],
    schritte: {
      de: ['Teig sehr dünn ausrollen.', 'Mit Schmand bestreichen.', 'Mit Zwiebelringen und Speck belegen.', 'Mit Salz und Pfeffer würzen.', 'Bei 240 Grad ca. 12 Minuten knusprig backen.'],
      sr: ['Тесто развући веома танко.', 'Премазати киселом павлаком.', 'Обложити колутовима лука и сланином.', 'Зачинити сољу и бибером.', 'Пећи на 240 степени око 12 минута до хрскавости.'],
      hr: ['Tijesto razvući vrlo tanko.', 'Premazati kiselim vrhnjem.', 'Obložiti kolutovima luka i slaninom.', 'Začiniti soli i paprom.', 'Peći na 240 stupnjeva oko 12 minuta do hrskavosti.'],
      ba: ['Tijesto razvući vrlo tanko.', 'Premazati kiselom pavlakom.', 'Obložiti kolutovima luka i slaninom.', 'Začiniti soli i biberom.', 'Peći na 240 stepeni oko 12 minuta do hrskavosti.'],
      en: ['Roll the dough very thin.', 'Spread with crème fraîche.', 'Top with onion rings and bacon.', 'Season with salt and pepper.', 'Bake at 240 degrees for about 12 minutes until crisp.']
    }
  },

  {
    id: 'brezel', kueche: 'deutsch', portionen: 6, dauer_min: 60,
    titel: { de: 'Brezel', sr: 'Переца', hr: 'Perec', ba: 'Perec', en: 'Pretzel' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 7, einheit: 'g', name: { de: 'Trockenhefe', sr: 'суви квасац', hr: 'suhi kvasac', ba: 'suhi kvasac', en: 'dry yeast' } },
      { menge: 250, einheit: 'ml', name: { de: 'lauwarmes Wasser', sr: 'млака вода', hr: 'mlaka voda', ba: 'mlaka voda', en: 'lukewarm water' } },
      { menge: 40, einheit: 'g', name: { de: 'Natron', sr: 'сода бикарбона', hr: 'soda bikarbona', ba: 'soda bikarbona', en: 'baking soda' } },
      { menge: null, einheit: 'ng', name: { de: 'grobes Salz', sr: 'крупна со', hr: 'krupna sol', ba: 'krupna so', en: 'coarse salt' } }
    ],
    schritte: {
      de: ['Aus Mehl, Hefe, Wasser und Salz einen Teig kneten und gehen lassen.', 'Zu Brezeln formen.', 'Kurz in Natronwasser tauchen.', 'Mit grobem Salz bestreuen.', 'Bei 220 Grad ca. 15 Minuten backen.'],
      sr: ['Од брашна, квасца, воде и соли умесити тесто и оставити да нарасте.', 'Обликовати переце.', 'Кратко умочити у воду са содом.', 'Посути крупном сољу.', 'Пећи на 220 степени око 15 минута.'],
      hr: ['Od brašna, kvasca, vode i soli umijesiti tijesto i ostaviti da naraste.', 'Oblikovati perece.', 'Kratko umočiti u vodu sa sodom.', 'Posuti krupnom soli.', 'Peći na 220 stupnjeva oko 15 minuta.'],
      ba: ['Od brašna, kvasca, vode i soli umijesiti tijesto i ostaviti da naraste.', 'Oblikovati perece.', 'Kratko umočiti u vodu sa sodom.', 'Posuti krupnom soli.', 'Peći na 220 stepeni oko 15 minuta.'],
      en: ['Knead a dough from flour, yeast, water and salt and let rise.', 'Shape into pretzels.', 'Briefly dip in soda water.', 'Sprinkle with coarse salt.', 'Bake at 220 degrees for about 15 minutes.']
    }
  },

  {
    id: 'kartoffelknoedel', kueche: 'deutsch', portionen: 4, dauer_min: 45,
    titel: { de: 'Kartoffelknödel', sr: 'Кнедле од кромпира', hr: 'Okruglice od krumpira', ba: 'Okruglice od krompira', en: 'Potato dumplings' },
    zutaten: [
      { menge: 1, einheit: 'kg', name: { de: 'mehlige Kartoffeln', sr: 'брашнави кромпир', hr: 'brašnati krumpir', ba: 'brašnavi krompir', en: 'floury potatoes' } },
      { menge: 150, einheit: 'g', name: { de: 'Kartoffelstärke', sr: 'скроб од кромпира', hr: 'krumpirov škrob', ba: 'krompirov škrob', en: 'potato starch' } },
      { menge: 1, einheit: 'stk', name: { de: 'Ei', sr: 'јаје', hr: 'jaje', ba: 'jaje', en: 'egg' } },
      { menge: 1, einheit: 'prise', name: { de: 'Muskat', sr: 'мушкатни орашчић', hr: 'muškatni oraščić', ba: 'muškatni oraščić', en: 'nutmeg' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz', sr: 'со', hr: 'sol', ba: 'so', en: 'salt' } }
    ],
    schritte: {
      de: ['Kartoffeln kochen, schälen und durchpressen.', 'Mit Stärke, Ei, Salz und Muskat zu einem Teig verkneten.', 'Knödel formen.', 'In siedendem Salzwasser ziehen lassen, bis sie aufsteigen.', 'Zu Braten servieren.'],
      sr: ['Кромпир скувати, огулити и испасирати.', 'Са скробом, јајетом, сољу и мушкатом умесити тесто.', 'Обликовати кнедле.', 'Оставити у благо кључалој сланој води док не испливају.', 'Послужити уз печење.'],
      hr: ['Krumpir skuhati, oguliti i propasirati.', 'Sa škrobom, jajem, soli i muškatom umijesiti tijesto.', 'Oblikovati okruglice.', 'Ostaviti u lagano kipućoj slanoj vodi dok ne isplivaju.', 'Poslužiti uz pečenje.'],
      ba: ['Krompir skuhati, oguliti i propasirati.', 'Sa škrobom, jajem, soli i muškatom umijesiti tijesto.', 'Oblikovati okruglice.', 'Ostaviti u lagano kipućoj slanoj vodi dok ne isplivaju.', 'Poslužiti uz pečenje.'],
      en: ['Boil, peel and press the potatoes.', 'Knead with starch, egg, salt and nutmeg into a dough.', 'Form dumplings.', 'Poach in gently simmering salted water until they rise.', 'Serve with roasts.']
    }
  },

  {
    id: 'rotkohl', kueche: 'deutsch', portionen: 6, dauer_min: 60,
    titel: { de: 'Rotkohl', sr: 'Црвени купус', hr: 'Crveni kupus', ba: 'Crveni kupus', en: 'Braised red cabbage' },
    zutaten: [
      { menge: 1, einheit: 'kopf', name: { de: 'Rotkohl', sr: 'глава црвеног купуса', hr: 'glava crvenog kupusa', ba: 'glava crvenog kupusa', en: 'head of red cabbage' } },
      { menge: 2, einheit: 'stk', name: { de: 'Äpfel', sr: 'јабуке', hr: 'jabuke', ba: 'jabuke', en: 'apples' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 3, einheit: 'el', name: { de: 'Essig', sr: 'сирће', hr: 'ocat', ba: 'sirće', en: 'vinegar' } },
      { menge: null, einheit: 'ng', name: { de: 'Zucker, Nelken, Salz', sr: 'шећер, каранфилић, со', hr: 'šećer, klinčić, sol', ba: 'šećer, karanfilić, so', en: 'sugar, cloves, salt' } }
    ],
    schritte: {
      de: ['Rotkohl fein hobeln.', 'Zwiebel anschwitzen und Kohl zugeben.', 'Geriebene Äpfel, Essig und Gewürze zugeben.', 'Mit etwas Wasser zugedeckt ca. 45 Minuten schmoren.', 'Süß-sauer abschmecken.'],
      sr: ['Црвени купус фино изрендати.', 'Лук продинстати и додати купус.', 'Додати рендане јабуке, сирће и зачине.', 'Са мало воде поклопљено динстати око 45 минута.', 'Зачинити слаткокисело.'],
      hr: ['Crveni kupus fino naribati.', 'Luk popirjati i dodati kupus.', 'Dodati naribane jabuke, ocat i začine.', 'S malo vode poklopljeno pirjati oko 45 minuta.', 'Začiniti slatkokiselo.'],
      ba: ['Crveni kupus fino naribati.', 'Luk podinstati i dodati kupus.', 'Dodati naribane jabuke, sirće i začine.', 'Sa malo vode poklopljeno dinstati oko 45 minuta.', 'Začiniti slatkokiselo.'],
      en: ['Finely shred the red cabbage.', 'Sweat the onion and add the cabbage.', 'Add grated apples, vinegar and spices.', 'Stew covered with a little water for about 45 minutes.', 'Season sweet and sour.']
    }
  },

  {
    id: 'schwarzwaelder_kirsch', kueche: 'deutsch', portionen: 12, dauer_min: 90,
    titel: { de: 'Schwarzwälder Kirschtorte', sr: 'Шварцвалд торта', hr: 'Schwarzwald torta', ba: 'Schwarzwald torta', en: 'Black Forest cake' },
    zutaten: [
      { menge: 6, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 150, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 120, einheit: 'g', name: { de: 'Mehl mit Kakao', sr: 'брашно са какаом', hr: 'brašno s kakaom', ba: 'brašno sa kakaom', en: 'flour with cocoa' } },
      { menge: 500, einheit: 'g', name: { de: 'Sauerkirschen', sr: 'вишње', hr: 'višnje', ba: 'višnje', en: 'sour cherries' } },
      { menge: 500, einheit: 'ml', name: { de: 'Schlagsahne', sr: 'слатка павлака', hr: 'slatko vrhnje', ba: 'slatka pavlaka', en: 'whipped cream' } },
      { menge: null, einheit: 'ng', name: { de: 'Schokoraspel, Kirschwasser', sr: 'рендана чоколада, ракија од вишања', hr: 'naribana čokolada, rakija od višanja', ba: 'naribana čokolada, rakija od višanja', en: 'chocolate shavings, kirsch' } }
    ],
    schritte: {
      de: ['Aus Eiern, Zucker und Kakaomehl einen Biskuit backen.', 'Boden in drei Schichten teilen und tränken.', 'Mit Sahne und Kirschen füllen.', 'Torte mit Sahne einstreichen.', 'Mit Schokoraspeln und Kirschen verzieren.'],
      sr: ['Од јаја, шећера и брашна са какаом испећи бисквит.', 'Кору поделити на три слоја и натопити.', 'Пунити павлаком и вишњама.', 'Торту обложити павлаком.', 'Украсити ренданом чоколадом и вишњама.'],
      hr: ['Od jaja, šećera i brašna s kakaom ispeći biskvit.', 'Koru podijeliti na tri sloja i natopiti.', 'Puniti vrhnjem i višnjama.', 'Tortu obložiti vrhnjem.', 'Ukrasiti naribanom čokoladom i višnjama.'],
      ba: ['Od jaja, šećera i brašna sa kakaom ispeći biskvit.', 'Koru podijeliti na tri sloja i natopiti.', 'Puniti pavlakom i višnjama.', 'Tortu obložiti pavlakom.', 'Ukrasiti naribanom čokoladom i višnjama.'],
      en: ['Bake a sponge from eggs, sugar and cocoa flour.', 'Split into three layers and soak.', 'Fill with cream and cherries.', 'Coat the cake with cream.', 'Decorate with chocolate shavings and cherries.']
    }
  },

  // ---- NACHSCHLAG CHINESISCH -----------------------------------------------
  {
    id: 'kung_pao', kueche: 'chinesisch', portionen: 4, dauer_min: 25,
    titel: { de: 'Kung Pao Hähnchen', sr: 'Кунг пао пилетина', hr: 'Kung Pao piletina', ba: 'Kung Pao piletina', en: 'Kung Pao chicken' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Hähnchenbrust', sr: 'пилеће бело месо', hr: 'pileća prsa', ba: 'pileća prsa', en: 'chicken breast' } },
      { menge: 60, einheit: 'g', name: { de: 'Erdnüsse', sr: 'кикирики', hr: 'kikiriki', ba: 'kikiriki', en: 'peanuts' } },
      { menge: 3, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 3, einheit: 'stk', name: { de: 'getrocknete Chilis', sr: 'суве љуте папричице', hr: 'suhe ljute papričice', ba: 'suhe ljute papričice', en: 'dried chillies' } },
      { menge: 2, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } },
      { menge: null, einheit: 'ng', name: { de: 'Öl, Ingwer, Zucker', sr: 'уље, ђумбир, шећер', hr: 'ulje, đumbir, šećer', ba: 'ulje, đumbir, šećer', en: 'oil, ginger, sugar' } }
    ],
    schritte: {
      de: ['Hähnchen würfeln und marinieren.', 'In heißem Öl scharf anbraten.', 'Chili, Ingwer und Frühlingszwiebeln zugeben.', 'Sojasauce und Zucker zugeben.', 'Erdnüsse unterheben und mit Reis servieren.'],
      sr: ['Пилетину исецкати и маринирати.', 'На врелом уљу јако пропржити.', 'Додати чили, ђумбир и млади лук.', 'Додати соја сос и шећер.', 'Умешати кикирики и послужити са пиринчем.'],
      hr: ['Piletinu narezati i marinirati.', 'Na vrućem ulju jako popržiti.', 'Dodati čili, đumbir i mladi luk.', 'Dodati soja umak i šećer.', 'Umiješati kikiriki i poslužiti s rižom.'],
      ba: ['Piletinu narezati i marinirati.', 'Na vrućem ulju jako popržiti.', 'Dodati čili, đumbir i mladi luk.', 'Dodati soja sos i šećer.', 'Umiješati kikiriki i poslužiti sa rižom.'],
      en: ['Dice and marinate the chicken.', 'Sear in hot oil.', 'Add chilli, ginger and spring onions.', 'Add soy sauce and sugar.', 'Fold in the peanuts and serve with rice.']
    }
  },

  {
    id: 'peking_ente', kueche: 'chinesisch', portionen: 4, dauer_min: 150,
    titel: { de: 'Peking-Ente', sr: 'Пекиншка патка', hr: 'Pekinška patka', ba: 'Pekinška patka', en: 'Peking duck' },
    zutaten: [
      { menge: 1, einheit: 'stk', name: { de: 'Ente', sr: 'патка', hr: 'patka', ba: 'patka', en: 'duck' } },
      { menge: 3, einheit: 'el', name: { de: 'Hoisinsauce', sr: 'хоисин сос', hr: 'hoisin umak', ba: 'hoisin sos', en: 'hoisin sauce' } },
      { menge: 12, einheit: 'stk', name: { de: 'dünne Pfannkuchen', sr: 'танке палачинке', hr: 'tanke palačinke', ba: 'tanke palačinke', en: 'thin pancakes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Salatgurke', sr: 'краставац', hr: 'krastavac', ba: 'krastavac', en: 'cucumber' } },
      { menge: 3, einheit: 'stk', name: { de: 'Frühlingszwiebeln', sr: 'млади лук', hr: 'mladi luk', ba: 'mladi luk', en: 'spring onions' } },
      { menge: null, einheit: 'ng', name: { de: 'Honig, Sojasauce, Salz', sr: 'мед, соја сос, со', hr: 'med, soja umak, sol', ba: 'med, soja sos, so', en: 'honey, soy sauce, salt' } }
    ],
    schritte: {
      de: ['Ente mit Honig und Sojasauce einstreichen.', 'Bei 180 Grad ca. 2 Stunden knusprig braten.', 'Fleisch und Haut in Streifen schneiden.', 'Gurke und Frühlingszwiebeln in Streifen schneiden.', 'Mit Pfannkuchen und Hoisinsauce servieren.'],
      sr: ['Патку премазати медом и соја сосом.', 'Пећи на 180 степени око 2 сата до хрскавости.', 'Месо и кожицу исећи на траке.', 'Краставац и млади лук исећи на траке.', 'Послужити са палачинкама и хоисин сосом.'],
      hr: ['Patku premazati medom i soja umakom.', 'Peći na 180 stupnjeva oko 2 sata do hrskavosti.', 'Meso i kožicu narezati na trake.', 'Krastavac i mladi luk narezati na trake.', 'Poslužiti s palačinkama i hoisin umakom.'],
      ba: ['Patku premazati medom i soja sosom.', 'Peći na 180 stepeni oko 2 sata do hrskavosti.', 'Meso i kožicu narezati na trake.', 'Krastavac i mladi luk narezati na trake.', 'Poslužiti sa palačinkama i hoisin sosom.'],
      en: ['Brush the duck with honey and soy sauce.', 'Roast at 180 degrees for about 2 hours until crisp.', 'Cut meat and skin into strips.', 'Cut cucumber and spring onions into strips.', 'Serve with pancakes and hoisin sauce.']
    }
  },

  {
    id: 'dim_sum', kueche: 'chinesisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Dim Sum (Dumplings)', sr: 'Дим сам', hr: 'Dim sum', ba: 'Dim sum', en: 'Dim sum' },
    zutaten: [
      { menge: 24, einheit: 'stk', name: { de: 'Teigblätter', sr: 'листови теста', hr: 'listovi tijesta', ba: 'listovi tijesta', en: 'dumpling wrappers' } },
      { menge: 300, einheit: 'g', name: { de: 'Garnelen oder Schwein', sr: 'шкампи или свињетина', hr: 'škampi ili svinjetina', ba: 'škampi ili svinjetina', en: 'prawns or pork' } },
      { menge: 100, einheit: 'g', name: { de: 'Chinakohl', sr: 'кинески купус', hr: 'kineski kupus', ba: 'kineski kupus', en: 'chinese cabbage' } },
      { menge: 2, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: null, einheit: 'ng', name: { de: 'Ingwer, Sesamöl', sr: 'ђумбир, сусамово уље', hr: 'đumbir, sezamovo ulje', ba: 'đumbir, susamovo ulje', en: 'ginger, sesame oil' } }
    ],
    schritte: {
      de: ['Füllung aus Fleisch, Kohl, Ingwer und Sojasauce mischen.', 'Teigblätter befüllen.', 'Zu Täschchen falten.', 'Im Dampf ca. 10 Minuten garen.', 'Mit Sojasauce-Dip servieren.'],
      sr: ['Направити фил од меса, купуса, ђумбира и соја соса.', 'Напунити листове теста.', 'Обликовати кесице.', 'Кувати на пари око 10 минута.', 'Послужити са дипом од соја соса.'],
      hr: ['Napraviti nadjev od mesa, kupusa, đumbira i soja umaka.', 'Napuniti listove tijesta.', 'Oblikovati vrećice.', 'Kuhati na pari oko 10 minuta.', 'Poslužiti s umakom od soje.'],
      ba: ['Napraviti nadjev od mesa, kupusa, đumbira i soja sosa.', 'Napuniti listove tijesta.', 'Oblikovati vrećice.', 'Kuhati na pari oko 10 minuta.', 'Poslužiti sa dipom od soja sosa.'],
      en: ['Mix a filling from meat, cabbage, ginger and soy sauce.', 'Fill the wrappers.', 'Fold into parcels.', 'Steam for about 10 minutes.', 'Serve with a soy dip.']
    }
  },

  {
    id: 'garnelen_knoblauch', kueche: 'chinesisch', portionen: 2, dauer_min: 20,
    titel: { de: 'Garnelen nach Wok-Art', sr: 'Пржени шкампи на кинески начин', hr: 'Prženi škampi na kineski način', ba: 'Prženi škampi na kineski način', en: 'Wok-fried prawns' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Garnelen', sr: 'шкампи', hr: 'škampi', ba: 'škampi', en: 'prawns' } },
      { menge: 4, einheit: 'zehe', name: { de: 'Knoblauchzehen', sr: 'чена белог лука', hr: 'češnja češnjaka', ba: 'čehna bijelog luka', en: 'garlic cloves' } },
      { menge: 2, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 1, einheit: 'el', name: { de: 'Sesamöl', sr: 'сусамово уље', hr: 'sezamovo ulje', ba: 'susamovo ulje', en: 'sesame oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Ingwer, Frühlingszwiebeln', sr: 'ђумбир, млади лук', hr: 'đumbir, mladi luk', ba: 'đumbir, mladi luk', en: 'ginger, spring onions' } }
    ],
    schritte: {
      de: ['Knoblauch und Ingwer in heißem Öl anbraten.', 'Garnelen zugeben und kurz braten.', 'Sojasauce und Sesamöl zugeben.', 'Frühlingszwiebeln unterheben.', 'Mit Reis servieren.'],
      sr: ['Бели лук и ђумбир пропржити на врелом уљу.', 'Додати шкампе и кратко пропржити.', 'Додати соја сос и сусамово уље.', 'Умешати млади лук.', 'Послужити са пиринчем.'],
      hr: ['Češnjak i đumbir popržiti na vrućem ulju.', 'Dodati škampe i kratko popržiti.', 'Dodati soja umak i sezamovo ulje.', 'Umiješati mladi luk.', 'Poslužiti s rižom.'],
      ba: ['Bijeli luk i đumbir popržiti na vrućem ulju.', 'Dodati škampe i kratko popržiti.', 'Dodati soja sos i susamovo ulje.', 'Umiješati mladi luk.', 'Poslužiti sa rižom.'],
      en: ['Fry garlic and ginger in hot oil.', 'Add the prawns and fry briefly.', 'Add soy sauce and sesame oil.', 'Fold in spring onions.', 'Serve with rice.']
    }
  },

  {
    id: 'hot_pot', kueche: 'chinesisch', portionen: 4, dauer_min: 45,
    titel: { de: 'Chinesischer Hot Pot', sr: 'Кинески хот пот', hr: 'Kineski hot pot', ba: 'Kineski hot pot', en: 'Chinese hot pot' },
    zutaten: [
      { menge: 1500, einheit: 'ml', name: { de: 'würzige Brühe', sr: 'зачињена супа', hr: 'začinjeni temeljac', ba: 'začinjena supa', en: 'spicy broth' } },
      { menge: 400, einheit: 'g', name: { de: 'dünn geschnittenes Fleisch', sr: 'танко сечено месо', hr: 'tanko narezano meso', ba: 'tanko narezano meso', en: 'thinly sliced meat' } },
      { menge: 200, einheit: 'g', name: { de: 'Tofu', sr: 'тофу', hr: 'tofu', ba: 'tofu', en: 'tofu' } },
      { menge: 200, einheit: 'g', name: { de: 'Pilze', sr: 'печурке', hr: 'gljive', ba: 'gljive', en: 'mushrooms' } },
      { menge: 200, einheit: 'g', name: { de: 'Blattgemüse', sr: 'лиснато поврће', hr: 'lisnato povrće', ba: 'lisnato povrće', en: 'leafy greens' } },
      { menge: null, einheit: 'ng', name: { de: 'Nudeln, Dip-Saucen', sr: 'резанци, сосови за умакање', hr: 'rezanci, umaci za umakanje', ba: 'rezanci, sosovi za umakanje', en: 'noodles, dipping sauces' } }
    ],
    schritte: {
      de: ['Brühe in einem Topf am Tisch erhitzen.', 'Fleisch und Gemüse in Schalen bereitstellen.', 'Zutaten nach und nach in der Brühe garen.', 'Mit Dip-Saucen essen.', 'Zum Schluss Nudeln in der Brühe kochen.'],
      sr: ['Супу загрејати у лонцу на столу.', 'Месо и поврће припремити у чинијама.', 'Састојке постепено кувати у супи.', 'Јести са сосовима за умакање.', 'На крају скувати резанце у супи.'],
      hr: ['Temeljac zagrijati u loncu na stolu.', 'Meso i povrće pripremiti u zdjelama.', 'Sastojke postupno kuhati u temeljcu.', 'Jesti s umacima za umakanje.', 'Na kraju skuhati rezance u temeljcu.'],
      ba: ['Supu zagrijati u loncu na stolu.', 'Meso i povrće pripremiti u zdjelama.', 'Sastojke postupno kuhati u supi.', 'Jesti sa sosovima za umakanje.', 'Na kraju skuhati rezance u supi.'],
      en: ['Heat the broth in a pot at the table.', 'Arrange meat and vegetables in bowls.', 'Cook the ingredients in the broth bit by bit.', 'Eat with dipping sauces.', 'At the end cook noodles in the broth.']
    }
  },

  {
    id: 'dan_dan_nudeln', kueche: 'chinesisch', portionen: 4, dauer_min: 30,
    titel: { de: 'Dan Dan Nudeln', sr: 'Дан дан резанци', hr: 'Dan Dan rezanci', ba: 'Dan Dan rezanci', en: 'Dan Dan noodles' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Weizennudeln', sr: 'пшенични резанци', hr: 'pšenični rezanci', ba: 'pšenični rezanci', en: 'wheat noodles' } },
      { menge: 300, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 3, einheit: 'el', name: { de: 'Sojasauce', sr: 'соја сос', hr: 'soja umak', ba: 'soja sos', en: 'soy sauce' } },
      { menge: 2, einheit: 'el', name: { de: 'Sesampaste', sr: 'сусам паста', hr: 'sezam pasta', ba: 'susam pasta', en: 'sesame paste' } },
      { menge: 1, einheit: 'el', name: { de: 'Chiliöl', sr: 'чили уље', hr: 'čili ulje', ba: 'čili ulje', en: 'chilli oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Frühlingszwiebeln, Erdnüsse', sr: 'млади лук, кикирики', hr: 'mladi luk, kikiriki', ba: 'mladi luk, kikiriki', en: 'spring onions, peanuts' } }
    ],
    schritte: {
      de: ['Hackfleisch mit Sojasauce knusprig braten.', 'Nudeln garen.', 'Sesampaste, Chiliöl und etwas Kochwasser zu einer Sauce rühren.', 'Nudeln mit der Sauce vermengen.', 'Mit Hackfleisch, Frühlingszwiebeln und Erdnüssen servieren.'],
      sr: ['Млевено месо са соја сосом испржити до хрскавости.', 'Резанце скувати.', 'Сусам пасту, чили уље и мало воде од кувања умешати у сос.', 'Резанце сјединити са сосом.', 'Послужити са месом, младим луком и кикирикијем.'],
      hr: ['Mljeveno meso sa soja umakom ispržiti do hrskavosti.', 'Rezance skuhati.', 'Sezam pastu, čili ulje i malo vode od kuhanja umiješati u umak.', 'Rezance sjediniti s umakom.', 'Poslužiti s mesom, mladim lukom i kikirikijem.'],
      ba: ['Mljeveno meso sa soja sosom ispržiti do hrskavosti.', 'Rezance skuhati.', 'Susam pastu, čili ulje i malo vode od kuhanja umiješati u sos.', 'Rezance sjediniti sa sosom.', 'Poslužiti sa mesom, mladim lukom i kikirikijem.'],
      en: ['Fry the minced meat with soy sauce until crisp.', 'Cook the noodles.', 'Stir sesame paste, chilli oil and some cooking water into a sauce.', 'Toss the noodles with the sauce.', 'Serve with meat, spring onions and peanuts.']
    }
  },

  // ---- NACHSCHLAG AMERIKANISCH ---------------------------------------------
  {
    id: 'hot_dog', kueche: 'amerikanisch', portionen: 4, dauer_min: 15,
    titel: { de: 'Hot Dog', sr: 'Хот дог', hr: 'Hot dog', ba: 'Hot dog', en: 'Hot dog' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Würstchen', sr: 'виршле', hr: 'hrenovke', ba: 'viršle', en: 'sausages' } },
      { menge: 4, einheit: 'stk', name: { de: 'Hot-Dog-Brötchen', sr: 'земичке за хот дог', hr: 'peciva za hot dog', ba: 'zemičke za hot dog', en: 'hot dog buns' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Ketchup, Senf, Röstzwiebeln', sr: 'кечап, сенф, пржени лук', hr: 'kečap, senf, prženi luk', ba: 'kečap, senf, prženi luk', en: 'ketchup, mustard, fried onions' } }
    ],
    schritte: {
      de: ['Würstchen in Wasser erhitzen.', 'Brötchen kurz anwärmen und aufschneiden.', 'Würstchen einlegen.', 'Mit Ketchup und Senf garnieren.', 'Mit Zwiebeln und Röstzwiebeln bestreuen.'],
      sr: ['Виршле загрејати у води.', 'Земичке кратко загрејати и расећи.', 'Ставити виршле.', 'Прелити кечапом и сенфом.', 'Посути луком и прженим луком.'],
      hr: ['Hrenovke zagrijati u vodi.', 'Peciva kratko zagrijati i razrezati.', 'Staviti hrenovke.', 'Preliti kečapom i senfom.', 'Posuti lukom i prženim lukom.'],
      ba: ['Viršle zagrijati u vodi.', 'Zemičke kratko zagrijati i razrezati.', 'Staviti viršle.', 'Preliti kečapom i senfom.', 'Posuti lukom i prženim lukom.'],
      en: ['Heat the sausages in water.', 'Warm and cut open the buns.', 'Insert the sausages.', 'Garnish with ketchup and mustard.', 'Sprinkle with onions and fried onions.']
    }
  },

  {
    id: 'buffalo_wings', kueche: 'amerikanisch', portionen: 4, dauer_min: 45,
    titel: { de: 'Buffalo Wings', sr: 'Бафало крилца', hr: 'Buffalo krilca', ba: 'Buffalo krilca', en: 'Buffalo wings' },
    zutaten: [
      { menge: 1, einheit: 'kg', name: { de: 'Hähnchenflügel', sr: 'пилећа крилца', hr: 'pileća krilca', ba: 'pileća krilca', en: 'chicken wings' } },
      { menge: 80, einheit: 'ml', name: { de: 'scharfe Sauce', sr: 'љути сос', hr: 'ljuti umak', ba: 'ljuti sos', en: 'hot sauce' } },
      { menge: 50, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: 1, einheit: 'tl', name: { de: 'Paprikapulver', sr: 'алева паприка', hr: 'mljevena paprika', ba: 'mljevena paprika', en: 'paprika' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Öl', sr: 'со, уље', hr: 'sol, ulje', ba: 'so, ulje', en: 'salt, oil' } }
    ],
    schritte: {
      de: ['Flügel salzen und bei 200 Grad ca. 35 Minuten knusprig backen.', 'Butter schmelzen und mit scharfer Sauce mischen.', 'Paprikapulver zugeben.', 'Flügel in der Sauce wenden.', 'Mit Dip servieren.'],
      sr: ['Крилца посолити и пећи на 200 степени око 35 минута до хрскавости.', 'Путер отопити и помешати са љутим сосом.', 'Додати алеву паприку.', 'Крилца уваљати у сос.', 'Послужити са дипом.'],
      hr: ['Krilca posoliti i peći na 200 stupnjeva oko 35 minuta do hrskavosti.', 'Maslac otopiti i pomiješati s ljutim umakom.', 'Dodati mljevenu papriku.', 'Krilca uvaljati u umak.', 'Poslužiti s umakom.'],
      ba: ['Krilca posoliti i peći na 200 stepeni oko 35 minuta do hrskavosti.', 'Maslac otopiti i pomiješati sa ljutim sosom.', 'Dodati mljevenu papriku.', 'Krilca uvaljati u sos.', 'Poslužiti sa dipom.'],
      en: ['Salt the wings and bake at 200 degrees for about 35 minutes until crisp.', 'Melt the butter and mix with hot sauce.', 'Add paprika.', 'Toss the wings in the sauce.', 'Serve with a dip.']
    }
  },

  {
    id: 'clam_chowder', kueche: 'amerikanisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Clam Chowder', sr: 'Чорба од шкољки', hr: 'Juha od školjki', ba: 'Čorba od školjki', en: 'Clam chowder' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Muscheln', sr: 'шкољке', hr: 'školjke', ba: 'školjke', en: 'clams' } },
      { menge: 4, einheit: 'stk', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 100, einheit: 'g', name: { de: 'Speck', sr: 'сланина', hr: 'slanina', ba: 'slanina', en: 'bacon' } },
      { menge: 300, einheit: 'ml', name: { de: 'Sahne', sr: 'слатка павлака', hr: 'slatko vrhnje', ba: 'slatka pavlaka', en: 'cream' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Pfeffer, Thymian', sr: 'со, бибер, мајчина душица', hr: 'sol, papar, majčina dušica', ba: 'so, biber, majčina dušica', en: 'salt, pepper, thyme' } }
    ],
    schritte: {
      de: ['Speck auslassen, Zwiebel darin anschwitzen.', 'Kartoffelwürfel und etwas Wasser zugeben und garen.', 'Muscheln zugeben.', 'Sahne einrühren und erwärmen.', 'Mit Salz, Pfeffer und Thymian abschmecken.'],
      sr: ['Истопити сланину, у њој продинстати лук.', 'Додати коцкице кромпира и мало воде и скувати.', 'Додати шкољке.', 'Умешати павлаку и загрејати.', 'Зачинити сољу, бибером и мајчином душицом.'],
      hr: ['Istopiti slaninu, u njoj popirjati luk.', 'Dodati kockice krumpira i malo vode i skuhati.', 'Dodati školjke.', 'Umiješati vrhnje i zagrijati.', 'Začiniti soli, paprom i majčinom dušicom.'],
      ba: ['Istopiti slaninu, u njoj podinstati luk.', 'Dodati kockice krompira i malo vode i skuhati.', 'Dodati školjke.', 'Umiješati pavlaku i zagrijati.', 'Začiniti soli, biberom i majčinom dušicom.'],
      en: ['Render the bacon, sweat the onion in it.', 'Add diced potatoes and a little water and cook.', 'Add the clams.', 'Stir in the cream and warm.', 'Season with salt, pepper and thyme.']
    }
  },

  {
    id: 'cornbread', kueche: 'amerikanisch', portionen: 8, dauer_min: 40,
    titel: { de: 'Cornbread', sr: 'Кукурузни хлеб', hr: 'Kukuruzni kruh', ba: 'Kukuruzni hljeb', en: 'Cornbread' },
    zutaten: [
      { menge: 200, einheit: 'g', name: { de: 'Maismehl', sr: 'кукурузно брашно', hr: 'kukuruzno brašno', ba: 'kukuruzno brašno', en: 'cornmeal' } },
      { menge: 150, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 250, einheit: 'ml', name: { de: 'Buttermilch', sr: 'млаћеница', hr: 'mlaćenica', ba: 'mlaćenica', en: 'buttermilk' } },
      { menge: 2, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 2, einheit: 'tl', name: { de: 'Backpulver', sr: 'прашак за пециво', hr: 'prašak za pecivo', ba: 'prašak za pecivo', en: 'baking powder' } },
      { menge: null, einheit: 'ng', name: { de: 'Butter, Salz', sr: 'путер, со', hr: 'maslac, sol', ba: 'maslac, so', en: 'butter, salt' } }
    ],
    schritte: {
      de: ['Trockene Zutaten vermischen.', 'Buttermilch, Eier und geschmolzene Butter zugeben.', 'Zu einem Teig verrühren.', 'In eine gefettete Form füllen.', 'Bei 200 Grad ca. 25 Minuten backen.'],
      sr: ['Помешати суве састојке.', 'Додати млаћеницу, јаја и отопљени путер.', 'Умутити у тесто.', 'Сипати у подмазан калуп.', 'Пећи на 200 степени око 25 минута.'],
      hr: ['Pomiješati suhe sastojke.', 'Dodati mlaćenicu, jaja i otopljeni maslac.', 'Umutiti u tijesto.', 'Uliti u podmazan kalup.', 'Peći na 200 stupnjeva oko 25 minuta.'],
      ba: ['Pomiješati suhe sastojke.', 'Dodati mlaćenicu, jaja i otopljeni maslac.', 'Umutiti u tijesto.', 'Uliti u podmazan kalup.', 'Peći na 200 stepeni oko 25 minuta.'],
      en: ['Mix the dry ingredients.', 'Add buttermilk, eggs and melted butter.', 'Stir into a batter.', 'Pour into a greased tin.', 'Bake at 200 degrees for about 25 minutes.']
    }
  },

  {
    id: 'pulled_pork', kueche: 'amerikanisch', portionen: 6, dauer_min: 300,
    titel: { de: 'Pulled Pork', sr: 'Чупкана свињетина', hr: 'Čupkana svinjetina', ba: 'Čupkana svinjetina', en: 'Pulled pork' },
    zutaten: [
      { menge: 1500, einheit: 'g', name: { de: 'Schweineschulter', sr: 'свињска плећка', hr: 'svinjska plećka', ba: 'svinjska plećka', en: 'pork shoulder' } },
      { menge: 3, einheit: 'el', name: { de: 'BBQ-Gewürzmischung', sr: 'BBQ мешавина зачина', hr: 'BBQ mješavina začina', ba: 'BBQ mješavina začina', en: 'BBQ rub' } },
      { menge: 200, einheit: 'ml', name: { de: 'BBQ-Sauce', sr: 'BBQ сос', hr: 'BBQ umak', ba: 'BBQ sos', en: 'BBQ sauce' } },
      { menge: 6, einheit: 'stk', name: { de: 'Burgerbrötchen', sr: 'земичке за бургер', hr: 'peciva za burger', ba: 'zemičke za burger', en: 'burger buns' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Öl', sr: 'со, уље', hr: 'sol, ulje', ba: 'so, ulje', en: 'salt, oil' } }
    ],
    schritte: {
      de: ['Fleisch mit der Gewürzmischung einreiben.', 'Bei 130 Grad ca. 4 Stunden sehr weich garen.', 'Mit zwei Gabeln zerzupfen.', 'Mit BBQ-Sauce vermengen.', 'In Brötchen mit Krautsalat servieren.'],
      sr: ['Месо утрљати мешавином зачина.', 'Пећи на 130 степени око 4 сата до веома мекане.', 'Ишчупкати са две виљушке.', 'Сјединити са BBQ сосом.', 'Послужити у земичкама са салатом од купуса.'],
      hr: ['Meso utrljati mješavinom začina.', 'Peći na 130 stupnjeva oko 4 sata do vrlo mekanog.', 'Iščupkati s dvije vilice.', 'Sjediniti s BBQ umakom.', 'Poslužiti u pecivima sa salatom od kupusa.'],
      ba: ['Meso utrljati mješavinom začina.', 'Peći na 130 stepeni oko 4 sata do vrlo mekanog.', 'Iščupkati sa dvije viljuške.', 'Sjediniti sa BBQ sosom.', 'Poslužiti u zemičkama sa salatom od kupusa.'],
      en: ['Rub the meat with the spice mix.', 'Cook at 130 degrees for about 4 hours until very tender.', 'Shred with two forks.', 'Toss with BBQ sauce.', 'Serve in buns with coleslaw.']
    }
  },

  {
    id: 'brownies', kueche: 'amerikanisch', portionen: 12, dauer_min: 40,
    titel: { de: 'Brownies', sr: 'Брауни', hr: 'Brownie', ba: 'Brownie', en: 'Brownies' },
    zutaten: [
      { menge: 200, einheit: 'g', name: { de: 'Zartbitterschokolade', sr: 'црна чоколада', hr: 'tamna čokolada', ba: 'tamna čokolada', en: 'dark chocolate' } },
      { menge: 150, einheit: 'g', name: { de: 'Butter', sr: 'путер', hr: 'maslac', ba: 'maslac', en: 'butter' } },
      { menge: 200, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 100, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 80, einheit: 'g', name: { de: 'Walnüsse', sr: 'ораси', hr: 'orasi', ba: 'orasi', en: 'walnuts' } }
    ],
    schritte: {
      de: ['Schokolade mit Butter schmelzen.', 'Zucker und Eier unterrühren.', 'Mehl und Walnüsse zugeben.', 'Teig in eine Form geben.', 'Bei 180 Grad ca. 25 Minuten backen, innen saftig lassen.'],
      sr: ['Чоколаду отопити са путером.', 'Умешати шећер и јаја.', 'Додати брашно и орахе.', 'Тесто сипати у калуп.', 'Пећи на 180 степени око 25 минута, изнутра оставити сочно.'],
      hr: ['Čokoladu otopiti s maslacem.', 'Umiješati šećer i jaja.', 'Dodati brašno i orahe.', 'Tijesto uliti u kalup.', 'Peći na 180 stupnjeva oko 25 minuta, iznutra ostaviti sočno.'],
      ba: ['Čokoladu otopiti sa maslacem.', 'Umiješati šećer i jaja.', 'Dodati brašno i orahe.', 'Tijesto uliti u kalup.', 'Peći na 180 stepeni oko 25 minuta, iznutra ostaviti sočno.'],
      en: ['Melt the chocolate with butter.', 'Stir in sugar and eggs.', 'Add flour and walnuts.', 'Pour the batter into a tin.', 'Bake at 180 degrees for about 25 minutes, keeping it moist inside.']
    }
  },

  // ---- NACHSCHLAG GRIECHISCH -----------------------------------------------
  {
    id: 'moussaka', kueche: 'griechisch', portionen: 6, dauer_min: 90,
    titel: { de: 'Griechische Moussaka', sr: 'Грчка мусака', hr: 'Grčka musaka', ba: 'Grčka musaka', en: 'Greek moussaka' },
    zutaten: [
      { menge: 3, einheit: 'stk', name: { de: 'Auberginen', sr: 'плави патлиџани', hr: 'patlidžani', ba: 'plavi patlidžani', en: 'aubergines' } },
      { menge: 500, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 500, einheit: 'ml', name: { de: 'Béchamelsauce', sr: 'бешамел сос', hr: 'bešamel umak', ba: 'bešamel sos', en: 'béchamel sauce' } },
      { menge: 100, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: null, einheit: 'ng', name: { de: 'Zwiebel, Öl, Zimt', sr: 'лук, уље, цимет', hr: 'luk, ulje, cimet', ba: 'luk, ulje, cimet', en: 'onion, oil, cinnamon' } }
    ],
    schritte: {
      de: ['Auberginenscheiben anbraten.', 'Hackfleisch mit Zwiebel, Tomaten und Zimt zu einer Sauce garen.', 'Auberginen und Fleischsauce abwechselnd schichten.', 'Mit Béchamel bedecken und Käse bestreuen.', 'Bei 180 Grad ca. 45 Minuten goldbraun backen.'],
      sr: ['Кришке патлиџана пропржити.', 'Млевено месо са луком, парадајзом и циметом скувати у сос.', 'Наизменично слагати патлиџане и месни сос.', 'Прекрити бешамелом и посути сиром.', 'Пећи на 180 степени око 45 минута до златне боје.'],
      hr: ['Kriške patlidžana popržiti.', 'Mljeveno meso s lukom, rajčicama i cimetom skuhati u umak.', 'Naizmjenično slagati patlidžane i mesni umak.', 'Prekriti bešamelom i posuti sirom.', 'Peći na 180 stupnjeva oko 45 minuta do zlatne boje.'],
      ba: ['Kriške patlidžana popržiti.', 'Mljeveno meso sa lukom, paradajzom i cimetom skuhati u sos.', 'Naizmjenično slagati patlidžane i mesni sos.', 'Prekriti bešamelom i posuti sirom.', 'Peći na 180 stepeni oko 45 minuta do zlatne boje.'],
      en: ['Fry the aubergine slices.', 'Cook the minced meat with onion, tomatoes and cinnamon into a sauce.', 'Layer aubergines and meat sauce alternately.', 'Cover with béchamel and sprinkle with cheese.', 'Bake at 180 degrees for about 45 minutes until golden.']
    }
  },

  {
    id: 'pastitsio', kueche: 'griechisch', portionen: 6, dauer_min: 80,
    titel: { de: 'Pastitsio', sr: 'Пастицио', hr: 'Pastitsio', ba: 'Pastitsio', en: 'Pastitsio' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'lange Röhrennudeln', sr: 'дугачка макарона', hr: 'duga makarona', ba: 'duga makarona', en: 'long tube pasta' } },
      { menge: 500, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 600, einheit: 'ml', name: { de: 'Béchamelsauce', sr: 'бешамел сос', hr: 'bešamel umak', ba: 'bešamel sos', en: 'béchamel sauce' } },
      { menge: 100, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: null, einheit: 'ng', name: { de: 'Zwiebel, Zimt, Salz', sr: 'лук, цимет, со', hr: 'luk, cimet, sol', ba: 'luk, cimet, so', en: 'onion, cinnamon, salt' } }
    ],
    schritte: {
      de: ['Nudeln kochen und in die Form geben.', 'Hackfleischsauce mit Tomaten und Zimt zubereiten.', 'Sauce über die Nudeln geben.', 'Mit Béchamel bedecken und Käse bestreuen.', 'Bei 180 Grad ca. 40 Minuten backen.'],
      sr: ['Макароне скувати и ставити у калуп.', 'Направити месни сос са парадајзом и циметом.', 'Прелити сосом преко макарона.', 'Прекрити бешамелом и посути сиром.', 'Пећи на 180 степени око 40 минута.'],
      hr: ['Makarone skuhati i staviti u kalup.', 'Napraviti mesni umak s rajčicama i cimetom.', 'Preliti umakom preko makarona.', 'Prekriti bešamelom i posuti sirom.', 'Peći na 180 stupnjeva oko 40 minuta.'],
      ba: ['Makarone skuhati i staviti u kalup.', 'Napraviti mesni sos sa paradajzom i cimetom.', 'Preliti sosom preko makarona.', 'Prekriti bešamelom i posuti sirom.', 'Peći na 180 stepeni oko 40 minuta.'],
      en: ['Cook the pasta and put it in the dish.', 'Prepare a meat sauce with tomatoes and cinnamon.', 'Spoon the sauce over the pasta.', 'Cover with béchamel and sprinkle with cheese.', 'Bake at 180 degrees for about 40 minutes.']
    }
  },

  {
    id: 'keftedes', kueche: 'griechisch', portionen: 4, dauer_min: 40,
    titel: { de: 'Keftedes (griechische Frikadellen)', sr: 'Кефтедес', hr: 'Keftedes', ba: 'Keftedes', en: 'Keftedes' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'stk', name: { de: 'Ei', sr: 'јаје', hr: 'jaje', ba: 'jaje', en: 'egg' } },
      { menge: 1, einheit: 'bund', name: { de: 'Minze', sr: 'нана', hr: 'menta', ba: 'nana', en: 'mint' } },
      { menge: null, einheit: 'ng', name: { de: 'Semmelbrösel, Öl, Salz', sr: 'презле, уље, со', hr: 'krušne mrvice, ulje, sol', ba: 'prezle, ulje, so', en: 'breadcrumbs, oil, salt' } }
    ],
    schritte: {
      de: ['Hackfleisch mit Zwiebel, Ei, Minze und Bröseln mischen.', 'Kurz kalt stellen.', 'Kleine Bällchen formen.', 'In Öl rundum goldbraun braten.', 'Mit Tzatziki servieren.'],
      sr: ['Млевено месо помешати са луком, јајетом, наном и презлама.', 'Кратко ставити у фрижидер.', 'Обликовати мале ћуфтице.', 'Пржити у уљу до златне боје са свих страна.', 'Послужити са тзатзикијем.'],
      hr: ['Mljeveno meso pomiješati s lukom, jajem, mentom i mrvicama.', 'Kratko staviti u hladnjak.', 'Oblikovati male okruglice.', 'Pržiti u ulju do zlatne boje sa svih strana.', 'Poslužiti s tzatzikijem.'],
      ba: ['Mljeveno meso pomiješati sa lukom, jajem, nanom i prezlama.', 'Kratko staviti u frižider.', 'Oblikovati male okruglice.', 'Pržiti u ulju do zlatne boje sa svih strana.', 'Poslužiti sa tzatzikijem.'],
      en: ['Mix the meat with onion, egg, mint and breadcrumbs.', 'Chill briefly.', 'Form small balls.', 'Fry golden all over in oil.', 'Serve with tzatziki.']
    }
  },

  {
    id: 'fasolada', kueche: 'griechisch', portionen: 4, dauer_min: 90,
    titel: { de: 'Fasolada (Bohnensuppe)', sr: 'Фасолада', hr: 'Fasolada', ba: 'Fasolada', en: 'Fasolada (bean soup)' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'weiße Bohnen', sr: 'бели пасуљ', hr: 'bijeli grah', ba: 'bijeli grah', en: 'white beans' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 2, einheit: 'stk', name: { de: 'Sellerie', sr: 'целер', hr: 'celer', ba: 'celer', en: 'celery' } },
      { menge: 400, einheit: 'g', name: { de: 'gehackte Tomaten', sr: 'сецкани парадајз', hr: 'sjeckane rajčice', ba: 'sjeckani paradajz', en: 'chopped tomatoes' } },
      { menge: 100, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Zwiebel, Salz', sr: 'лук, со', hr: 'luk, sol', ba: 'luk, so', en: 'onion, salt' } }
    ],
    schritte: {
      de: ['Bohnen über Nacht einweichen.', 'Zwiebel, Karotte und Sellerie in Olivenöl andünsten.', 'Bohnen und Tomaten zugeben.', 'Mit Wasser bedecken und ca. 70 Minuten weich kochen.', 'Mit Salz und Olivenöl abschmecken.'],
      sr: ['Пасуљ потопити преко ноћи.', 'Лук, шаргарепу и целер продинстати на маслиновом уљу.', 'Додати пасуљ и парадајз.', 'Прелити водом и кувати око 70 минута до мекоће.', 'Зачинити сољу и маслиновим уљем.'],
      hr: ['Grah namočiti preko noći.', 'Luk, mrkvu i celer popirjati na maslinovom ulju.', 'Dodati grah i rajčice.', 'Preliti vodom i kuhati oko 70 minuta do mekoće.', 'Začiniti soli i maslinovim uljem.'],
      ba: ['Grah namočiti preko noći.', 'Luk, mrkvu i celer podinstati na maslinovom ulju.', 'Dodati grah i paradajz.', 'Preliti vodom i kuhati oko 70 minuta do mekoće.', 'Začiniti soli i maslinovim uljem.'],
      en: ['Soak the beans overnight.', 'Sauté onion, carrot and celery in olive oil.', 'Add beans and tomatoes.', 'Cover with water and cook soft for about 70 minutes.', 'Season with salt and olive oil.']
    }
  },

  {
    id: 'galaktoboureko', kueche: 'griechisch', portionen: 8, dauer_min: 70,
    titel: { de: 'Galaktoboureko', sr: 'Галактобуреко', hr: 'Galaktoboureko', ba: 'Galaktoboureko', en: 'Galaktoboureko' },
    zutaten: [
      { menge: 400, einheit: 'g', name: { de: 'Filoteig', sr: 'јуфка коре', hr: 'jufka kore', ba: 'jufka kore', en: 'filo pastry' } },
      { menge: 1000, einheit: 'ml', name: { de: 'Milch', sr: 'млеко', hr: 'mlijeko', ba: 'mlijeko', en: 'milk' } },
      { menge: 150, einheit: 'g', name: { de: 'Grieß', sr: 'гриз', hr: 'griz', ba: 'griz', en: 'semolina' } },
      { menge: 200, einheit: 'g', name: { de: 'Zucker', sr: 'шећер', hr: 'šećer', ba: 'šećer', en: 'sugar' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: null, einheit: 'ng', name: { de: 'Butter, Zitrone', sr: 'путер, лимун', hr: 'maslac, limun', ba: 'maslac, limun', en: 'butter, lemon' } }
    ],
    schritte: {
      de: ['Milch mit Grieß und Zucker zu einer Creme kochen.', 'Eier einrühren und abkühlen lassen.', 'Filoteig mit Butter in eine Form legen.', 'Creme einfüllen und mit Teig bedecken.', 'Bei 180 Grad backen und mit Zuckersirup tränken.'],
      sr: ['Млеко са гризом и шећером укувати у крем.', 'Умешати јаја и охладити.', 'Јуфка коре са путером ставити у калуп.', 'Насути крем и прекрити тестом.', 'Пећи на 180 степени и натопити шећерним сирупом.'],
      hr: ['Mlijeko s grizom i šećerom ukuhati u kremu.', 'Umiješati jaja i ohladiti.', 'Jufka kore s maslacem staviti u kalup.', 'Napuniti kremom i prekriti tijestom.', 'Peći na 180 stupnjeva i natopiti šećernim sirupom.'],
      ba: ['Mlijeko sa grizom i šećerom ukuhati u kremu.', 'Umiješati jaja i ohladiti.', 'Jufka kore sa maslacem staviti u kalup.', 'Napuniti kremom i prekriti tijestom.', 'Peći na 180 stepeni i natopiti šećernim sirupom.'],
      en: ['Cook milk with semolina and sugar into a custard.', 'Stir in the eggs and let cool.', 'Layer filo with butter in a dish.', 'Fill with custard and cover with pastry.', 'Bake at 180 degrees and soak with sugar syrup.']
    }
  },

  // ---- NACHSCHLAG MEXIKANISCH ----------------------------------------------
  {
    id: 'nachos', kueche: 'mexikanisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Nachos', sr: 'Начос', hr: 'Nachos', ba: 'Nachos', en: 'Nachos' },
    zutaten: [
      { menge: 300, einheit: 'g', name: { de: 'Tortillachips', sr: 'тортиља чипс', hr: 'tortilja čips', ba: 'tortilja čips', en: 'tortilla chips' } },
      { menge: 200, einheit: 'g', name: { de: 'geriebener Käse', sr: 'рендани сир', hr: 'naribani sir', ba: 'naribani sir', en: 'grated cheese' } },
      { menge: 150, einheit: 'g', name: { de: 'Kidneybohnen', sr: 'црвени пасуљ', hr: 'crveni grah', ba: 'crveni grah', en: 'kidney beans' } },
      { menge: 1, einheit: 'stk', name: { de: 'Jalapeño', sr: 'халапењо', hr: 'jalapeño', ba: 'jalapeño', en: 'jalapeño' } },
      { menge: null, einheit: 'ng', name: { de: 'Salsa, Guacamole', sr: 'салса, гуакамоле', hr: 'salsa, guacamole', ba: 'salsa, guacamole', en: 'salsa, guacamole' } }
    ],
    schritte: {
      de: ['Chips auf einem Blech verteilen.', 'Mit Bohnen und Käse bestreuen.', 'Jalapeño-Scheiben darüber geben.', 'Bei 200 Grad ca. 8 Minuten überbacken.', 'Mit Salsa und Guacamole servieren.'],
      sr: ['Чипс распоредити на плех.', 'Посути пасуљем и сиром.', 'Одозго ставити кришке халапења.', 'Запећи на 200 степени око 8 минута.', 'Послужити са салсом и гуакамолеом.'],
      hr: ['Čips rasporediti na lim.', 'Posuti grahom i sirom.', 'Odozgo staviti kriške jalapeña.', 'Zapeći na 200 stupnjeva oko 8 minuta.', 'Poslužiti sa salsom i guacamoleom.'],
      ba: ['Čips rasporediti na pleh.', 'Posuti grahom i sirom.', 'Odozgo staviti kriške jalapeña.', 'Zapeći na 200 stepeni oko 8 minuta.', 'Poslužiti sa salsom i guacamoleom.'],
      en: ['Spread the chips on a tray.', 'Sprinkle with beans and cheese.', 'Add jalapeño slices on top.', 'Bake at 200 degrees for about 8 minutes.', 'Serve with salsa and guacamole.']
    }
  },

  {
    id: 'chile_relleno', kueche: 'mexikanisch', portionen: 4, dauer_min: 50,
    titel: { de: 'Chile Relleno', sr: 'Пуњена љута паприка', hr: 'Punjena ljuta paprika', ba: 'Punjena ljuta paprika', en: 'Chile relleno' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'große Paprika', sr: 'велике паприке', hr: 'velike paprike', ba: 'velike paprike', en: 'large peppers' } },
      { menge: 200, einheit: 'g', name: { de: 'Käse', sr: 'сир', hr: 'sir', ba: 'sir', en: 'cheese' } },
      { menge: 3, einheit: 'stk', name: { de: 'Eier', sr: 'јаја', hr: 'jaja', ba: 'jaja', en: 'eggs' } },
      { menge: 300, einheit: 'ml', name: { de: 'Tomatensauce', sr: 'сос од парадајза', hr: 'umak od rajčice', ba: 'sos od paradajza', en: 'tomato sauce' } },
      { menge: null, einheit: 'ng', name: { de: 'Mehl, Öl, Salz', sr: 'брашно, уље, со', hr: 'brašno, ulje, sol', ba: 'brašno, ulje, so', en: 'flour, oil, salt' } }
    ],
    schritte: {
      de: ['Paprika rösten, häuten und entkernen.', 'Mit Käse füllen.', 'Eiweiß steif schlagen und mit Eigelb mischen.', 'Paprika in Mehl und Eimasse wenden und frittieren.', 'Mit Tomatensauce servieren.'],
      sr: ['Паприке испећи, огулити и очистити од семена.', 'Напунити сиром.', 'Беланца улупати и помешати са жуманцима.', 'Паприке уваљати у брашно и смесу од јаја и пржити.', 'Послужити са сосом од парадајза.'],
      hr: ['Paprike ispeći, oguliti i očistiti od sjemenki.', 'Napuniti sirom.', 'Bjelanjke istući i pomiješati sa žumanjcima.', 'Paprike uvaljati u brašno i smjesu od jaja i pržiti.', 'Poslužiti s umakom od rajčice.'],
      ba: ['Paprike ispeći, oguliti i očistiti od sjemenki.', 'Napuniti sirom.', 'Bjelanca istući i pomiješati sa žumancima.', 'Paprike uvaljati u brašno i smjesu od jaja i pržiti.', 'Poslužiti sa sosom od paradajza.'],
      en: ['Roast, peel and deseed the peppers.', 'Fill with cheese.', 'Beat egg whites stiff and mix with yolks.', 'Coat peppers in flour and egg mixture and fry.', 'Serve with tomato sauce.']
    }
  },

  {
    id: 'pozole', kueche: 'mexikanisch', portionen: 6, dauer_min: 120,
    titel: { de: 'Pozole', sr: 'Позоле', hr: 'Pozole', ba: 'Pozole', en: 'Pozole' },
    zutaten: [
      { menge: 600, einheit: 'g', name: { de: 'Schweinefleisch', sr: 'свињетина', hr: 'svinjetina', ba: 'svinjetina', en: 'pork' } },
      { menge: 400, einheit: 'g', name: { de: 'Mais (Hominy)', sr: 'кукуруз', hr: 'kukuruz', ba: 'kukuruz', en: 'hominy corn' } },
      { menge: 3, einheit: 'stk', name: { de: 'getrocknete Chilis', sr: 'суве љуте папричице', hr: 'suhe ljute papričice', ba: 'suhe ljute papričice', en: 'dried chillies' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: null, einheit: 'ng', name: { de: 'Knoblauch, Oregano, Salz', sr: 'бели лук, оригано, со', hr: 'češnjak, origano, sol', ba: 'bijeli luk, origano, so', en: 'garlic, oregano, salt' } }
    ],
    schritte: {
      de: ['Fleisch mit Zwiebel und Knoblauch weich kochen.', 'Chilis einweichen und pürieren.', 'Chilipüree in die Brühe geben.', 'Mais zugeben und weitere 30 Minuten köcheln.', 'Mit Oregano und frischen Beilagen servieren.'],
      sr: ['Месо са луком и белим луком скувати до мекоће.', 'Папричице потопити и изблендати.', 'Пире од папричица додати у супу.', 'Додати кукуруз и кувати још 30 минута.', 'Послужити са ориганом и свежим прилозима.'],
      hr: ['Meso s lukom i češnjakom skuhati do mekoće.', 'Papričice namočiti i izblendati.', 'Pire od papričica dodati u temeljac.', 'Dodati kukuruz i kuhati još 30 minuta.', 'Poslužiti s origanom i svježim prilozima.'],
      ba: ['Meso sa lukom i bijelim lukom skuhati do mekoće.', 'Papričice namočiti i izblendati.', 'Pire od papričica dodati u supu.', 'Dodati kukuruz i kuhati još 30 minuta.', 'Poslužiti sa origanom i svježim prilozima.'],
      en: ['Boil the meat soft with onion and garlic.', 'Soak and purée the chillies.', 'Add the chilli purée to the broth.', 'Add the corn and simmer another 30 minutes.', 'Serve with oregano and fresh toppings.']
    }
  },

  {
    id: 'elote', kueche: 'mexikanisch', portionen: 4, dauer_min: 25,
    titel: { de: 'Elote (Maiskolben)', sr: 'Елоте (кукуруз у клипу)', hr: 'Elote (kukuruz u klipu)', ba: 'Elote (kukuruz u klipu)', en: 'Elote (street corn)' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Maiskolben', sr: 'клипови кукуруза', hr: 'klipovi kukuruza', ba: 'klipovi kukuruza', en: 'corn cobs' } },
      { menge: 4, einheit: 'el', name: { de: 'Mayonnaise', sr: 'мајонез', hr: 'majoneza', ba: 'majoneza', en: 'mayonnaise' } },
      { menge: 60, einheit: 'g', name: { de: 'Käse (Cotija)', sr: 'сир', hr: 'sir', ba: 'sir', en: 'cotija cheese' } },
      { menge: 1, einheit: 'tl', name: { de: 'Chilipulver', sr: 'чили у праху', hr: 'čili u prahu', ba: 'čili u prahu', en: 'chilli powder' } },
      { menge: 1, einheit: 'stk', name: { de: 'Limette', sr: 'лимета', hr: 'limeta', ba: 'limeta', en: 'lime' } }
    ],
    schritte: {
      de: ['Maiskolben kochen oder grillen.', 'Mit Mayonnaise bestreichen.', 'Mit geriebenem Käse bestreuen.', 'Mit Chilipulver würzen.', 'Mit Limettensaft beträufeln und servieren.'],
      sr: ['Клипове кукуруза скувати или испећи на роштиљу.', 'Премазати мајонезом.', 'Посути ренданим сиром.', 'Зачинити чилијем у праху.', 'Прелити соком лимете и послужити.'],
      hr: ['Klipove kukuruza skuhati ili ispeći na roštilju.', 'Premazati majonezom.', 'Posuti naribanim sirom.', 'Začiniti čilijem u prahu.', 'Preliti sokom limete i poslužiti.'],
      ba: ['Klipove kukuruza skuhati ili ispeći na roštilju.', 'Premazati majonezom.', 'Posuti naribanim sirom.', 'Začiniti čilijem u prahu.', 'Preliti sokom limete i poslužiti.'],
      en: ['Boil or grill the corn cobs.', 'Spread with mayonnaise.', 'Sprinkle with grated cheese.', 'Season with chilli powder.', 'Drizzle with lime juice and serve.']
    }
  },

  // ---- NACHSCHLAG ORIENTALISCH ---------------------------------------------
  {
    id: 'manakish', kueche: 'orientalisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Manakish (Za\'atar-Fladen)', sr: 'Манакиш', hr: 'Manakish', ba: 'Manakish', en: 'Manakish' },
    zutaten: [
      { menge: 500, einheit: 'g', name: { de: 'Mehl', sr: 'брашно', hr: 'brašno', ba: 'brašno', en: 'flour' } },
      { menge: 7, einheit: 'g', name: { de: 'Trockenhefe', sr: 'суви квасац', hr: 'suhi kvasac', ba: 'suhi kvasac', en: 'dry yeast' } },
      { menge: 4, einheit: 'el', name: { de: 'Za\'atar-Gewürz', sr: 'затар зачин', hr: 'za\'atar začin', ba: 'za\'atar začin', en: 'za\'atar' } },
      { menge: 80, einheit: 'ml', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Wasser, Salz', sr: 'вода, со', hr: 'voda, sol', ba: 'voda, so', en: 'water, salt' } }
    ],
    schritte: {
      de: ['Aus Mehl, Hefe, Wasser und Salz einen Teig kneten und gehen lassen.', 'Za\'atar mit Olivenöl mischen.', 'Teig zu Fladen ausrollen.', 'Mit der Za\'atar-Paste bestreichen.', 'Bei 220 Grad ca. 12 Minuten backen.'],
      sr: ['Од брашна, квасца, воде и соли умесити тесто и оставити да нарасте.', 'Затар помешати са маслиновим уљем.', 'Тесто развући у лепиње.', 'Премазати затар пастом.', 'Пећи на 220 степени око 12 минута.'],
      hr: ['Od brašna, kvasca, vode i soli umijesiti tijesto i ostaviti da naraste.', 'Za\'atar pomiješati s maslinovim uljem.', 'Tijesto razvući u lepinje.', 'Premazati za\'atar pastom.', 'Peći na 220 stupnjeva oko 12 minuta.'],
      ba: ['Od brašna, kvasca, vode i soli umijesiti tijesto i ostaviti da naraste.', 'Za\'atar pomiješati sa maslinovim uljem.', 'Tijesto razvući u lepinje.', 'Premazati za\'atar pastom.', 'Peći na 220 stepeni oko 12 minuta.'],
      en: ['Knead a dough from flour, yeast, water and salt and let rise.', 'Mix za\'atar with olive oil.', 'Roll the dough into flatbreads.', 'Spread with the za\'atar paste.', 'Bake at 220 degrees for about 12 minutes.']
    }
  },

  {
    id: 'fattoush', kueche: 'orientalisch', portionen: 4, dauer_min: 20,
    titel: { de: 'Fattoush-Salat', sr: 'Фатуш салата', hr: 'Fattoush salata', ba: 'Fattoush salata', en: 'Fattoush salad' },
    zutaten: [
      { menge: 2, einheit: 'stk', name: { de: 'Fladenbrote', sr: 'лепиње', hr: 'lepinje', ba: 'lepinje', en: 'flatbreads' } },
      { menge: 3, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Salatgurke', sr: 'краставац', hr: 'krastavac', ba: 'krastavac', en: 'cucumber' } },
      { menge: 1, einheit: 'kopf', name: { de: 'Kopfsalat', sr: 'глава зелене салате', hr: 'glava zelene salate', ba: 'glava zelene salate', en: 'lettuce' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone', sr: 'лимун', hr: 'limun', ba: 'limun', en: 'lemon' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Sumach, Minze', sr: 'маслиново уље, сумак, нана', hr: 'maslinovo ulje, sumak, menta', ba: 'maslinovo ulje, sumak, nana', en: 'olive oil, sumac, mint' } }
    ],
    schritte: {
      de: ['Fladenbrot rösten und in Stücke brechen.', 'Gemüse grob schneiden.', 'Alles mit Minze mischen.', 'Aus Olivenöl, Zitrone und Sumach ein Dressing rühren.', 'Vor dem Servieren mit dem Brot mischen.'],
      sr: ['Лепиње препећи и изломити на комаде.', 'Поврће крупно исећи.', 'Све помешати са наном.', 'Од маслиновог уља, лимуна и сумака направити прелив.', 'Пре служења помешати са хлебом.'],
      hr: ['Lepinje popeći i izlomiti na komade.', 'Povrće krupno narezati.', 'Sve pomiješati s mentom.', 'Od maslinovog ulja, limuna i sumaka napraviti preljev.', 'Prije posluživanja pomiješati s kruhom.'],
      ba: ['Lepinje popeći i izlomiti na komade.', 'Povrće krupno narezati.', 'Sve pomiješati sa nanom.', 'Od maslinovog ulja, limuna i sumaka napraviti preljev.', 'Prije posluživanja pomiješati sa hljebom.'],
      en: ['Toast the flatbread and break into pieces.', 'Roughly chop the vegetables.', 'Mix everything with mint.', 'Whisk a dressing from olive oil, lemon and sumac.', 'Mix with the bread just before serving.']
    }
  },

  {
    id: 'mujadara', kueche: 'orientalisch', portionen: 4, dauer_min: 45,
    titel: { de: 'Mujadara (Linsen mit Reis)', sr: 'Муџадара', hr: 'Mujadara', ba: 'Mujadara', en: 'Mujadara' },
    zutaten: [
      { menge: 200, einheit: 'g', name: { de: 'braune Linsen', sr: 'смеђе сочиво', hr: 'smeđa leća', ba: 'smeđa leća', en: 'brown lentils' } },
      { menge: 150, einheit: 'g', name: { de: 'Reis', sr: 'пиринач', hr: 'riža', ba: 'riža', en: 'rice' } },
      { menge: 3, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 1, einheit: 'tl', name: { de: 'Kreuzkümmel', sr: 'ким', hr: 'kim', ba: 'kim', en: 'cumin' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Salz', sr: 'маслиново уље, со', hr: 'maslinovo ulje, sol', ba: 'maslinovo ulje, so', en: 'olive oil, salt' } }
    ],
    schritte: {
      de: ['Linsen halbgar kochen.', 'Zwiebeln in Olivenöl goldbraun braten.', 'Reis und Kreuzkümmel zu den Linsen geben.', 'Mit Wasser aufgießen und garen.', 'Mit gerösteten Zwiebeln bestreut servieren.'],
      sr: ['Сочиво полукувати.', 'Лук испржити на маслиновом уљу до златне боје.', 'Додати пиринач и ким сочиву.', 'Залити водом и скувати.', 'Послужити посуто прженим луком.'],
      hr: ['Leću polukuhati.', 'Luk ispržiti na maslinovom ulju do zlatne boje.', 'Dodati rižu i kim leći.', 'Zaliti vodom i skuhati.', 'Poslužiti posuto prženim lukom.'],
      ba: ['Leću polukuhati.', 'Luk ispržiti na maslinovom ulju do zlatne boje.', 'Dodati rižu i kim leći.', 'Zaliti vodom i skuhati.', 'Poslužiti posuto prženim lukom.'],
      en: ['Parboil the lentils.', 'Fry the onions golden in olive oil.', 'Add rice and cumin to the lentils.', 'Pour in water and cook.', 'Serve topped with the fried onions.']
    }
  },

  {
    id: 'kibbeh', kueche: 'orientalisch', portionen: 4, dauer_min: 60,
    titel: { de: 'Kibbeh', sr: 'Кибе', hr: 'Kibbeh', ba: 'Kibbeh', en: 'Kibbeh' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'feiner Bulgur', sr: 'ситни булгур', hr: 'sitni bulgur', ba: 'sitni bulgur', en: 'fine bulgur' } },
      { menge: 500, einheit: 'g', name: { de: 'Hackfleisch', sr: 'млевено месо', hr: 'mljeveno meso', ba: 'mljeveno meso', en: 'minced meat' } },
      { menge: 2, einheit: 'stk', name: { de: 'Zwiebeln', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onions' } },
      { menge: 60, einheit: 'g', name: { de: 'Pinienkerne', sr: 'пињоли', hr: 'pinjoli', ba: 'pinjoli', en: 'pine nuts' } },
      { menge: null, einheit: 'ng', name: { de: 'Gewürze, Öl, Salz', sr: 'зачини, уље, со', hr: 'začini, ulje, sol', ba: 'začini, ulje, so', en: 'spices, oil, salt' } }
    ],
    schritte: {
      de: ['Bulgur einweichen und mit einem Teil Fleisch und Zwiebel zu einem Teig kneten.', 'Restliches Fleisch mit Zwiebel und Pinienkernen als Füllung braten.', 'Aus dem Teig Hüllen formen und füllen.', 'Zu Kroketten formen.', 'In heißem Öl goldbraun frittieren.'],
      sr: ['Булгур потопити и са делом меса и луком умесити тесто.', 'Остатак меса са луком и пињолима испржити као фил.', 'Од теста обликовати љуске и напунити.', 'Обликовати крокете.', 'Пржити у врелом уљу до златне боје.'],
      hr: ['Bulgur namočiti i s dijelom mesa i lukom umijesiti tijesto.', 'Ostatak mesa s lukom i pinjolima ispržiti kao nadjev.', 'Od tijesta oblikovati ljuske i napuniti.', 'Oblikovati krokete.', 'Pržiti u vrućem ulju do zlatne boje.'],
      ba: ['Bulgur namočiti i sa dijelom mesa i lukom umijesiti tijesto.', 'Ostatak mesa sa lukom i pinjolima ispržiti kao nadjev.', 'Od tijesta oblikovati ljuske i napuniti.', 'Oblikovati krokete.', 'Pržiti u vrućem ulju do zlatne boje.'],
      en: ['Soak the bulgur and knead with part of the meat and onion into a dough.', 'Fry the rest of the meat with onion and pine nuts as filling.', 'Form shells from the dough and fill.', 'Shape into croquettes.', 'Deep-fry in hot oil until golden.']
    }
  },

  // ---- NACHSCHLAG INTERNATIONAL --------------------------------------------
  {
    id: 'wrap_haehnchen', kueche: 'international', portionen: 4, dauer_min: 25,
    titel: { de: 'Hähnchen-Wrap', sr: 'Врап са пилетином', hr: 'Wrap s piletinom', ba: 'Wrap sa piletinom', en: 'Chicken wrap' },
    zutaten: [
      { menge: 4, einheit: 'stk', name: { de: 'Tortillafladen', sr: 'тортиља', hr: 'tortilja', ba: 'tortilja', en: 'tortillas' } },
      { menge: 400, einheit: 'g', name: { de: 'Hähnchenbrust', sr: 'пилеће бело месо', hr: 'pileća prsa', ba: 'pileća prsa', en: 'chicken breast' } },
      { menge: 100, einheit: 'g', name: { de: 'Salat', sr: 'зелена салата', hr: 'zelena salata', ba: 'zelena salata', en: 'lettuce' } },
      { menge: 2, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: null, einheit: 'ng', name: { de: 'Joghurtsauce, Öl, Salz', sr: 'сос од јогурта, уље, со', hr: 'umak od jogurta, ulje, sol', ba: 'sos od jogurta, ulje, so', en: 'yoghurt sauce, oil, salt' } }
    ],
    schritte: {
      de: ['Hähnchen in Streifen würzen und anbraten.', 'Tortillafladen kurz erwärmen.', 'Mit Joghurtsauce bestreichen.', 'Salat, Tomaten und Hähnchen einfüllen.', 'Fest einrollen und servieren.'],
      sr: ['Пилетину на траке зачинити и пропржити.', 'Тортиље кратко загрејати.', 'Премазати сосом од јогурта.', 'Ставити салату, парадајз и пилетину.', 'Чврсто уролати и послужити.'],
      hr: ['Piletinu na trake začiniti i popržiti.', 'Tortilje kratko zagrijati.', 'Premazati umakom od jogurta.', 'Staviti salatu, rajčice i piletinu.', 'Čvrsto urolati i poslužiti.'],
      ba: ['Piletinu na trake začiniti i popržiti.', 'Tortilje kratko zagrijati.', 'Premazati sosom od jogurta.', 'Staviti salatu, paradajz i piletinu.', 'Čvrsto urolati i poslužiti.'],
      en: ['Season the chicken strips and fry.', 'Warm the tortillas briefly.', 'Spread with yoghurt sauce.', 'Fill with salad, tomatoes and chicken.', 'Roll up tightly and serve.']
    }
  },

  {
    id: 'ofengemuese', kueche: 'international', portionen: 4, dauer_min: 45,
    titel: { de: 'Ofengemüse', sr: 'Печено поврће из рерне', hr: 'Pečeno povrće iz pećnice', ba: 'Pečeno povrće iz rerne', en: 'Roasted vegetables' },
    zutaten: [
      { menge: 2, einheit: 'stk', name: { de: 'Zucchini', sr: 'тиквице', hr: 'tikvice', ba: 'tikvice', en: 'courgettes' } },
      { menge: 2, einheit: 'stk', name: { de: 'Paprika', sr: 'паприка', hr: 'paprika', ba: 'paprika', en: 'bell peppers' } },
      { menge: 3, einheit: 'stk', name: { de: 'Kartoffeln', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'rote Zwiebel', sr: 'црвени лук', hr: 'crveni luk', ba: 'crveni luk', en: 'red onion' } },
      { menge: 4, einheit: 'el', name: { de: 'Olivenöl', sr: 'маслиново уље', hr: 'maslinovo ulje', ba: 'maslinovo ulje', en: 'olive oil' } },
      { menge: null, einheit: 'ng', name: { de: 'Salz, Kräuter', sr: 'со, зачинско биље', hr: 'sol, začinsko bilje', ba: 'so, začinsko bilje', en: 'salt, herbs' } }
    ],
    schritte: {
      de: ['Gemüse in gleichmäßige Stücke schneiden.', 'Mit Olivenöl, Salz und Kräutern mischen.', 'Auf einem Blech verteilen.', 'Bei 200 Grad ca. 30 Minuten rösten.', 'Zwischendurch einmal wenden.'],
      sr: ['Поврће исећи на једнаке комаде.', 'Помешати са маслиновим уљем, сољу и зачинским биљем.', 'Распоредити на плех.', 'Пећи на 200 степени око 30 минута.', 'У међувремену једном промешати.'],
      hr: ['Povrće narezati na jednake komade.', 'Pomiješati s maslinovim uljem, soli i začinskim biljem.', 'Rasporediti na lim.', 'Peći na 200 stupnjeva oko 30 minuta.', 'U međuvremenu jednom promiješati.'],
      ba: ['Povrće narezati na jednake komade.', 'Pomiješati sa maslinovim uljem, soli i začinskim biljem.', 'Rasporediti na pleh.', 'Peći na 200 stepeni oko 30 minuta.', 'U međuvremenu jednom promiješati.'],
      en: ['Cut the vegetables into even pieces.', 'Toss with olive oil, salt and herbs.', 'Spread on a tray.', 'Roast at 200 degrees for about 30 minutes.', 'Turn once halfway through.']
    }
  },

  {
    id: 'linsensuppe', kueche: 'international', portionen: 4, dauer_min: 40,
    titel: { de: 'Linsensuppe', sr: 'Супа од сочива', hr: 'Juha od leće', ba: 'Supa od leće', en: 'Lentil soup' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'rote Linsen', sr: 'црвено сочиво', hr: 'crvena leća', ba: 'crvena leća', en: 'red lentils' } },
      { menge: 2, einheit: 'stk', name: { de: 'Karotten', sr: 'шаргарепа', hr: 'mrkva', ba: 'mrkva', en: 'carrots' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zwiebel', sr: 'црни лук', hr: 'luk', ba: 'luk', en: 'onion' } },
      { menge: 1, einheit: 'stk', name: { de: 'Kartoffel', sr: 'кромпир', hr: 'krumpir', ba: 'krompir', en: 'potato' } },
      { menge: 1000, einheit: 'ml', name: { de: 'Gemüsebrühe', sr: 'повртна супа', hr: 'povrtni temeljac', ba: 'povrtna supa', en: 'vegetable broth' } },
      { menge: null, einheit: 'ng', name: { de: 'Kreuzkümmel, Salz, Zitrone', sr: 'ким, со, лимун', hr: 'kim, sol, limun', ba: 'kim, so, limun', en: 'cumin, salt, lemon' } }
    ],
    schritte: {
      de: ['Zwiebel und Karotte in Öl anschwitzen.', 'Linsen, Kartoffel und Kreuzkümmel zugeben.', 'Mit Brühe aufgießen.', 'Ca. 25 Minuten weich köcheln und pürieren.', 'Mit Salz und Zitronensaft abschmecken.'],
      sr: ['Лук и шаргарепу продинстати на уљу.', 'Додати сочиво, кромпир и ким.', 'Залити супом.', 'Кувати око 25 минута до мекоће и изблендати.', 'Зачинити сољу и соком лимуна.'],
      hr: ['Luk i mrkvu popirjati na ulju.', 'Dodati leću, krumpir i kim.', 'Zaliti temeljcem.', 'Kuhati oko 25 minuta do mekoće i izblendati.', 'Začiniti soli i sokom limuna.'],
      ba: ['Luk i mrkvu podinstati na ulju.', 'Dodati leću, krompir i kim.', 'Zaliti supom.', 'Kuhati oko 25 minuta do mekoće i izblendati.', 'Začiniti soli i sokom limuna.'],
      en: ['Sweat onion and carrot in oil.', 'Add lentils, potato and cumin.', 'Pour in the broth.', 'Simmer soft for about 25 minutes and purée.', 'Season with salt and lemon juice.']
    }
  },

  {
    id: 'couscous_salat', kueche: 'international', portionen: 4, dauer_min: 25,
    titel: { de: 'Couscous-Salat', sr: 'Салата од кускуса', hr: 'Salata od kuskusa', ba: 'Salata od kuskusa', en: 'Couscous salad' },
    zutaten: [
      { menge: 250, einheit: 'g', name: { de: 'Couscous', sr: 'кускус', hr: 'kuskus', ba: 'kuskus', en: 'couscous' } },
      { menge: 2, einheit: 'stk', name: { de: 'Tomaten', sr: 'парадајз', hr: 'rajčice', ba: 'paradajz', en: 'tomatoes' } },
      { menge: 1, einheit: 'stk', name: { de: 'Salatgurke', sr: 'краставац', hr: 'krastavac', ba: 'krastavac', en: 'cucumber' } },
      { menge: 1, einheit: 'bund', name: { de: 'Petersilie', sr: 'першун', hr: 'peršin', ba: 'peršun', en: 'parsley' } },
      { menge: 1, einheit: 'stk', name: { de: 'Zitrone', sr: 'лимун', hr: 'limun', ba: 'limun', en: 'lemon' } },
      { menge: null, einheit: 'ng', name: { de: 'Olivenöl, Salz', sr: 'маслиново уље, со', hr: 'maslinovo ulje, sol', ba: 'maslinovo ulje, so', en: 'olive oil, salt' } }
    ],
    schritte: {
      de: ['Couscous mit heißem Wasser übergießen und quellen lassen.', 'Mit einer Gabel auflockern.', 'Tomaten, Gurke und Petersilie klein schneiden.', 'Alles vermengen.', 'Mit Olivenöl, Zitrone und Salz abschmecken.'],
      sr: ['Кускус прелити врелом водом и оставити да набубри.', 'Разрахлити виљушком.', 'Парадајз, краставац и першун ситно исећи.', 'Све сјединити.', 'Зачинити маслиновим уљем, лимуном и сољу.'],
      hr: ['Kuskus preliti vrućom vodom i ostaviti da nabubri.', 'Rastresti vilicom.', 'Rajčice, krastavac i peršin sitno narezati.', 'Sve sjediniti.', 'Začiniti maslinovim uljem, limunom i soli.'],
      ba: ['Kuskus preliti vrućom vodom i ostaviti da nabubri.', 'Rastresti viljuškom.', 'Paradajz, krastavac i peršun sitno narezati.', 'Sve sjediniti.', 'Začiniti maslinovim uljem, limunom i soli.'],
      en: ['Pour hot water over the couscous and let it swell.', 'Fluff with a fork.', 'Finely chop tomatoes, cucumber and parsley.', 'Combine everything.', 'Season with olive oil, lemon and salt.']
    }
  }

];

// Global verfügbar machen (wird vor dem Haupt-Script geladen).
if (typeof window !== 'undefined') window.REZEPT_POOL = REZEPT_POOL;
