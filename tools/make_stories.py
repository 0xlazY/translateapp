import json, sys

P = True  # starts a paragraph

S = []

def story(id, level, order, title, titleFr, emoji, theme, summary, lines, keywords, questions):
    S.append({
        "id": id, "level": level, "order": order, "title": title, "titleFr": titleFr, "emoji": emoji,
        "theme": theme, "summary": summary,
        "lines": [dict(ru=l[0], fr=l[1], **({"paragraph": True} if len(l) > 2 else {})) for l in lines],
        "keywords": [{"ru": k, "fr": v} for k, v in keywords],
        "questions": [{"ru": q, "fr": f, "options": o, "answer": a} for q, f, o, a in questions],
    })

story("privet-kazan", "A1", 1, "Привет, Казань!", "Bonjour, Kazan !", "🏙️", "blue",
      "Camille, une étudiante de Lyon, arrive à Kazan et rencontre Nika.", [
    ("Меня зовут Камилла.", "Je m'appelle Camille."),
    ("Я из Франции, из Лиона.", "Je viens de France, de Lyon."),
    ("Сейчас я живу в Казани.", "Maintenant, je vis à Kazan."),
    ("Казань — большой и красивый город.", "Kazan est une grande et belle ville."),
    ("Здесь я учусь в университете.", "Ici, j'étudie à l'université."),
    ("Я изучаю русский язык.", "J'apprends le russe.", P),
    ("Русский язык трудный, но интересный.", "Le russe est difficile, mais intéressant."),
    ("У меня есть подруга. Её зовут Ника.", "J'ai une amie. Elle s'appelle Nika."),
    ("Ника — студентка. Она тоже учится в университете.", "Nika est étudiante. Elle aussi étudie à l'université."),
    ("Ника говорит по-французски, но очень медленно.", "Nika parle français, mais très lentement.", P),
    ("А я говорю по-русски, но тоже медленно!", "Et moi, je parle russe, mais lentement aussi !"),
    ("Мы говорим и смеёмся.", "Nous parlons et nous rions."),
    ("Сегодня у нас первый урок.", "Aujourd'hui, nous avons notre premier cours."),
    ("«Привет, Казань!» — говорю я.", "« Bonjour, Kazan ! » dis-je."),
], [("город", "ville"), ("учиться", "étudier"), ("подруга", "amie"), ("язык", "langue"), ("медленно", "lentement")], [
    ("Откуда Камилла?", "D'où vient Camille ?", ["Из Москвы", "Из Лиона", "Из Казани"], 1),
    ("Как зовут подругу Камиллы?", "Comment s'appelle l'amie de Camille ?", ["Маша", "Ника", "Лиза"], 1),
    ("Как Ника говорит по-французски?", "Comment Nika parle-t-elle français ?", ["Очень быстро", "Очень медленно", "Громко"], 1),
])

story("kvartira", "A1", 2, "Наша квартира", "Notre appartement", "🏠", "amber",
      "Camille fait visiter l'appartement qu'elle partage avec Nika.", [
    ("Мы с Никой живём в квартире.", "Nika et moi vivons dans un appartement."),
    ("Квартира небольшая, но уютная.", "L'appartement est petit, mais confortable."),
    ("Она на пятом этаже.", "Il est au cinquième étage."),
    ("В квартире две комнаты, кухня и ванная.", "Dans l'appartement, il y a deux chambres, une cuisine et une salle de bains."),
    ("Моя комната маленькая.", "Ma chambre est petite.", P),
    ("Там есть кровать, стол и шкаф.", "Il y a un lit, une table et une armoire."),
    ("На столе лежат мои книги.", "Sur la table, il y a mes livres."),
    ("Окно большое, и из окна видно реку.", "La fenêtre est grande, et de la fenêtre on voit la rivière."),
    ("Кухня — моё любимое место.", "La cuisine est mon endroit préféré.", P),
    ("Там мы пьём чай и разговариваем.", "Là, nous buvons du thé et nous discutons."),
    ("Вечером на кухне тепло и светло.", "Le soir, il fait chaud et clair dans la cuisine."),
    ("Лифт в доме старый и часто не работает.", "L'ascenseur de l'immeuble est vieux et souvent en panne.", P),
    ("Поэтому мы ходим пешком.", "C'est pourquoi nous montons à pied."),
    ("Пять этажей — это хороший спорт!", "Cinq étages, c'est un bon sport !"),
], [("квартира", "appartement"), ("комната", "chambre, pièce"), ("кухня", "cuisine"), ("окно", "fenêtre"), ("этаж", "étage")], [
    ("На каком этаже квартира?", "À quel étage est l'appartement ?", ["На втором", "На пятом", "На десятом"], 1),
    ("Что лежит на столе?", "Qu'y a-t-il sur la table ?", ["Книги", "Кошка", "Хлеб"], 0),
    ("Почему девушки ходят пешком?", "Pourquoi les filles montent-elles à pied ?", ["Лифт часто не работает", "Они не любят лифт", "В доме нет лифта"], 0),
])

story("kot-pirozhok", "A1", 3, "Кот Пирожок", "Le chat Pirojok", "🐈", "red",
      "Le voisin, le vieux Fiodor, a un chat roux très paresseux… et très gourmand.", [
    ("Рядом с нами живёт дедушка Фёдор.", "À côté de chez nous vit le vieux Fiodor."),
    ("Ему восемьдесят лет.", "Il a quatre-vingts ans."),
    ("У него есть кот. Кота зовут Пирожок.", "Il a un chat. Le chat s'appelle Pirojok."),
    ("Пирожок большой, рыжий и очень ленивый.", "Pirojok est gros, roux et très paresseux."),
    ("Он весь день спит на диване.", "Il dort toute la journée sur le canapé."),
    ("Но вечером Пирожок не спит.", "Mais le soir, Pirojok ne dort pas.", P),
    ("Вечером он гуляет по дому.", "Le soir, il se promène dans l'immeuble."),
    ("Он знает, где живём мы.", "Il sait où nous habitons."),
    ("Он сидит у нашей двери и ждёт.", "Il s'assoit devant notre porte et attend."),
    ("Почему? Потому что Ника даёт ему рыбу!", "Pourquoi ? Parce que Nika lui donne du poisson !"),
    ("«Ника, это не твой кот», — говорю я.", "« Nika, ce n'est pas ton chat », dis-je.", P),
    ("«Я знаю, — отвечает Ника. — Но он такой милый!»", "« Je sais, répond Nika. Mais il est si mignon ! »"),
    ("Дедушка Фёдор не сердится.", "Le vieux Fiodor ne se fâche pas."),
    ("Он смеётся: «Пирожок любит всех!»", "Il rit : « Pirojok aime tout le monde ! »"),
], [("кот", "chat"), ("ленивый", "paresseux"), ("спать", "dormir"), ("дверь", "porte"), ("рыба", "poisson")], [
    ("Сколько лет дедушке Фёдору?", "Quel âge a le vieux Fiodor ?", ["Восемьдесят", "Сорок", "Шестьдесят"], 0),
    ("Где спит Пирожок днём?", "Où dort Pirojok pendant la journée ?", ["На кровати", "На диване", "На окне"], 1),
    ("Что Ника даёт коту?", "Que donne Nika au chat ?", ["Молоко", "Мясо", "Рыбу"], 2),
])

story("zavtrak", "A1", 4, "Завтрак", "Le petit déjeuner", "🥞", "amber",
      "Kacha, blinis et thé au citron : le petit déjeuner à la russe.", [
    ("Утром я всегда очень хочу есть.", "Le matin, j'ai toujours très faim."),
    ("Во Франции я ем на завтрак круассан и пью кофе.", "En France, au petit déjeuner, je mange un croissant et je bois un café."),
    ("В России завтрак другой.", "En Russie, le petit déjeuner est différent."),
    ("Ника готовит кашу.", "Nika prépare de la kacha.", P),
    ("Каша горячая и вкусная.", "La kacha est chaude et délicieuse."),
    ("Ещё на столе есть хлеб, сыр и масло.", "Sur la table, il y a aussi du pain, du fromage et du beurre."),
    ("Иногда Ника делает блины.", "Parfois, Nika fait des blinis.", P),
    ("Блины тонкие, как французские блинчики.", "Les blinis sont fins, comme les crêpes françaises."),
    ("Мы едим блины со сметаной или с вареньем.", "Nous mangeons les blinis avec de la crème fraîche ou de la confiture."),
    ("Я пью чай с лимоном, а Ника пьёт кофе.", "Je bois du thé au citron, et Nika boit du café.", P),
    ("«Кто пьёт кофе утром — француженка или русская?» — смеётся Ника.", "« Qui boit du café le matin, la Française ou la Russe ? » rit Nika."),
    ("Сегодня суббота, и мы завтракаем долго.", "Aujourd'hui, c'est samedi, et nous prenons notre petit déjeuner sans nous presser."),
], [("завтрак", "petit déjeuner"), ("каша", "kacha, bouillie"), ("хлеб", "pain"), ("блины", "blinis, crêpes"), ("варенье", "confiture")], [
    ("Что готовит Ника утром?", "Que prépare Nika le matin ?", ["Кашу", "Суп", "Пиццу"], 0),
    ("С чем девушки едят блины?", "Avec quoi les filles mangent-elles les blinis ?", ["С мясом", "Со сметаной или с вареньем", "С рыбой"], 1),
    ("Что пьёт Камилла?", "Que boit Camille ?", ["Кофе", "Молоко", "Чай с лимоном"], 2),
])

story("na-rynke", "A1", 5, "На рынке", "Au marché", "🍎", "green",
      "Acheter des pommes, demander un prix… et recevoir un cadeau.", [
    ("В воскресенье мы идём на рынок.", "Dimanche, nous allons au marché."),
    ("Рынок недалеко от дома.", "Le marché n'est pas loin de la maison."),
    ("Там много людей и много продуктов.", "Il y a beaucoup de monde et beaucoup de produits."),
    ("Я хочу купить яблоки.", "Je veux acheter des pommes.", P),
    ("«Сколько стоят яблоки?» — спрашиваю я.", "« Combien coûtent les pommes ? » je demande."),
    ("«Сто рублей килограмм», — отвечает продавщица.", "« Cent roubles le kilo », répond la vendeuse."),
    ("«Дайте, пожалуйста, два килограмма».", "« Donnez-m'en deux kilos, s'il vous plaît. »"),
    ("Ника покупает картошку, морковь и лук.", "Nika achète des pommes de terre, des carottes et des oignons.", P),
    ("Ещё мы покупаем мёд.", "Nous achetons aussi du miel."),
    ("Мёд здесь очень хороший.", "Ici, le miel est très bon."),
    ("Продавщица говорит: «Вы не русская? Откуда вы?»", "La vendeuse dit : « Vous n'êtes pas russe ? D'où venez-vous ? »", P),
    ("«Я из Франции», — отвечаю я.", "« Je viens de France », je réponds."),
    ("«Ой, Франция! Париж! Возьмите яблоко в подарок!»", "« Oh, la France ! Paris ! Prenez une pomme en cadeau ! »"),
    ("Я говорю: «Спасибо большое!»", "Je dis : « Merci beaucoup ! »"),
], [("рынок", "marché"), ("купить", "acheter"), ("сколько стоит", "combien ça coûte"), ("яблоко", "pomme"), ("подарок", "cadeau")], [
    ("Когда девушки идут на рынок?", "Quand les filles vont-elles au marché ?", ["В субботу", "В воскресенье", "В понедельник"], 1),
    ("Сколько стоит килограмм яблок?", "Combien coûte un kilo de pommes ?", ["Сто рублей", "Двести рублей", "Десять рублей"], 0),
    ("Что продавщица даёт Камилле в подарок?", "Que donne la vendeuse à Camille en cadeau ?", ["Мёд", "Яблоко", "Морковь"], 1),
])

story("moy-den", "A1", 6, "Мой день", "Ma journée", "⏰", "violet",
      "Du réveil au coucher : une journée d'étudiante à Kazan.", [
    ("Я встаю в семь часов.", "Je me lève à sept heures."),
    ("Я умываюсь, одеваюсь и завтракаю.", "Je me lave, je m'habille et je prends mon petit déjeuner."),
    ("В восемь часов я еду в университет на автобусе.", "À huit heures, je vais à l'université en bus."),
    ("Занятия начинаются в девять.", "Les cours commencent à neuf heures.", P),
    ("Утром у нас грамматика, а потом разговорная практика.", "Le matin, nous avons de la grammaire, puis de la pratique orale."),
    ("В час дня мы обедаем в столовой.", "À une heure, nous déjeunons à la cantine."),
    ("Я обычно беру суп и салат.", "Je prends d'habitude une soupe et une salade."),
    ("После обеда я иду в библиотеку.", "Après le déjeuner, je vais à la bibliothèque.", P),
    ("Там я читаю и делаю домашнее задание.", "Là, je lis et je fais mes devoirs."),
    ("Вечером я гуляю с Никой или смотрю фильмы.", "Le soir, je me promène avec Nika ou je regarde des films."),
    ("В одиннадцать часов я ложусь спать.", "À onze heures, je me couche.", P),
    ("Мой день длинный, но я счастлива.", "Ma journée est longue, mais je suis heureuse."),
], [("вставать", "se lever"), ("ехать", "aller (en véhicule)"), ("обедать", "déjeuner"), ("библиотека", "bibliothèque"), ("ложиться спать", "se coucher")], [
    ("Когда Камилла встаёт?", "À quelle heure Camille se lève-t-elle ?", ["В шесть", "В семь", "В девять"], 1),
    ("Где она обедает?", "Où déjeune-t-elle ?", ["Дома", "В ресторане", "В столовой"], 2),
    ("Что она делает в библиотеке?", "Que fait-elle à la bibliothèque ?", ["Спит", "Читает и делает домашнее задание", "Пьёт кофе"], 1),
])

story("pogoda", "A1", 7, "Какая погода?", "Quel temps fait-il ?", "🌧️", "teal",
      "Octobre à Kazan : il est temps d'acheter un bonnet.", [
    ("Сейчас октябрь.", "Nous sommes en octobre."),
    ("В Казани уже холодно.", "À Kazan, il fait déjà froid."),
    ("Утром температура — плюс два градуса.", "Le matin, il fait plus deux degrés."),
    ("Часто идёт дождь, и дует сильный ветер.", "Il pleut souvent, et un vent fort souffle."),
    ("В Лионе в октябре ещё тепло.", "À Lyon, en octobre, il fait encore doux.", P),
    ("Мама пишет мне: «У нас пятнадцать градусов и солнце!»", "Maman m'écrit : « Chez nous, il fait quinze degrés et il y a du soleil ! »"),
    ("Ника говорит, что это ещё не холод.", "Nika dit que ce n'est pas encore le froid.", P),
    ("«Настоящий холод будет в январе. Минус двадцать!»", "« Le vrai froid, ce sera en janvier. Moins vingt ! »"),
    ("Мне страшно.", "J'ai peur."),
    ("Сегодня мы идём в магазин и покупаем тёплую куртку, шапку и перчатки.", "Aujourd'hui, nous allons au magasin et nous achetons une veste chaude, un bonnet et des gants.", P),
    ("Шапка красная, а куртка синяя.", "Le bonnet est rouge, et la veste est bleue."),
    ("Теперь я готова к зиме!", "Maintenant, je suis prête pour l'hiver !"),
], [("погода", "temps (météo)"), ("холодно", "il fait froid"), ("дождь", "pluie"), ("ветер", "vent"), ("шапка", "bonnet")], [
    ("Какая температура в Казани утром?", "Quelle température fait-il à Kazan le matin ?", ["Плюс два градуса", "Плюс пятнадцать", "Минус двадцать"], 0),
    ("Где сейчас тепло?", "Où fait-il doux en ce moment ?", ["В Казани", "В Лионе", "В Москве"], 1),
    ("Какого цвета шапка?", "De quelle couleur est le bonnet ?", ["Синяя", "Белая", "Красная"], 2),
])

story("semya-niki", "A1", 8, "Семья Ники", "La famille de Nika", "👨‍👩‍👧‍👦", "green",
      "Un week-end au village, chez les parents de Nika… et chez sa grand-mère.", [
    ("В пятницу мы едем к родителям Ники.", "Vendredi, nous allons chez les parents de Nika."),
    ("Они живут в деревне недалеко от Казани.", "Ils vivent dans un village près de Kazan."),
    ("У Ники большая семья.", "Nika a une grande famille.", P),
    ("Её папа — инженер, а мама — учительница.", "Son père est ingénieur, et sa mère est institutrice."),
    ("У неё есть брат Артём и сестра Даша.", "Elle a un frère, Artiom, et une sœur, Dacha."),
    ("Артём старше Ники. Он повар и живёт в Москве.", "Artiom est plus âgé que Nika. Il est cuisinier et vit à Moscou."),
    ("Даша младше. Ей двенадцать лет, она школьница.", "Dacha est plus jeune. Elle a douze ans, elle va à l'école."),
    ("Ещё с ними живёт бабушка.", "Leur grand-mère vit aussi avec eux.", P),
    ("Бабушка очень добрая и всё время нас кормит.", "La grand-mère est très gentille et nous nourrit sans arrêt."),
    ("«Ешь, Камилла, ешь! Ты такая худая!» — говорит она.", "« Mange, Camille, mange ! Tu es si mince ! » dit-elle."),
    ("Даша задаёт мне много вопросов о Франции.", "Dacha me pose beaucoup de questions sur la France.", P),
    ("Вечером мы все вместе пьём чай и поём песни.", "Le soir, nous buvons tous ensemble du thé et nous chantons des chansons."),
    ("Мне здесь очень хорошо.", "Je me sens très bien ici."),
], [("семья", "famille"), ("родители", "parents"), ("брат", "frère"), ("сестра", "sœur"), ("бабушка", "grand-mère")], [
    ("Где живут родители Ники?", "Où vivent les parents de Nika ?", ["В Москве", "В деревне", "В Лионе"], 1),
    ("Кто Артём по профессии?", "Quel est le métier d'Artiom ?", ["Повар", "Инженер", "Учитель"], 0),
    ("Сколько лет Даше?", "Quel âge a Dacha ?", ["Восемь", "Двенадцать", "Двадцать"], 1),
])

story("gde-klyuch", "A2", 1, "Где ключ?", "Où est la clé ?", "🔑", "violet",
      "Tard le soir, Camille ne trouve plus sa clé. Heureusement, il y a un voisin.", [
    ("Вчера был трудный день.", "Hier a été une journée difficile."),
    ("Я вернулась из университета поздно, в девять часов вечера.", "Je suis rentrée de l'université tard, à neuf heures du soir."),
    ("Я очень устала и хотела спать.", "J'étais très fatiguée et j'avais envie de dormir."),
    ("Я подошла к двери и открыла сумку.", "Je me suis approchée de la porte et j'ai ouvert mon sac."),
    ("Ключа не было!", "La clé n'y était pas !"),
    ("Я искала везде: в сумке, в карманах, в книгах.", "J'ai cherché partout : dans le sac, dans les poches, dans les livres.", P),
    ("Ничего.", "Rien."),
    ("Ника в тот вечер была у родителей.", "Ce soir-là, Nika était chez ses parents."),
    ("Я позвонила ей, но она не ответила.", "Je l'ai appelée, mais elle n'a pas répondu."),
    ("Вдруг дверь соседа открылась.", "Soudain, la porte du voisin s'est ouverte.", P),
    ("Это был дедушка Фёдор, а за ним — Пирожок.", "C'était le vieux Fiodor, et derrière lui, Pirojok."),
    ("«Камилла, что случилось?» — спросил он.", "« Camille, que s'est-il passé ? » demanda-t-il."),
    ("Я всё объяснила.", "Je lui ai tout expliqué."),
    ("Дедушка улыбнулся: «Подожди минутку».", "Le vieil homme a souri : « Attends une petite minute. »"),
    ("Через минуту он вернулся с ключом в руке.", "Une minute plus tard, il est revenu avec une clé à la main.", P),
    ("«Ника дала мне запасной ключ. На всякий случай».", "« Nika m'a donné un double de la clé. Au cas où. »"),
    ("Я была так рада! Я пригласила его на чай.", "J'étais si contente ! Je l'ai invité à prendre le thé."),
    ("А Пирожок, конечно, тоже пришёл.", "Et Pirojok, bien sûr, est venu aussi."),
], [("ключ", "clé"), ("искать", "chercher"), ("устать", "être fatigué"), ("сосед", "voisin"), ("запасной", "de rechange, double")], [
    ("Когда Камилла вернулась домой?", "Quand Camille est-elle rentrée ?", ["В девять часов вечера", "В полдень", "В семь утра"], 0),
    ("Где была Ника?", "Où était Nika ?", ["В университете", "У родителей", "В магазине"], 1),
    ("Откуда у дедушки ключ?", "D'où le vieux Fiodor a-t-il la clé ?", ["Он нашёл его на улице", "Ника дала ему запасной ключ", "Это его ключ"], 1),
])

story("poezd", "A2", 2, "Ночной поезд", "Le train de nuit", "🚆", "blue",
      "Une nuit en train jusqu'à Moscou, avec du thé, des pirojki et une rencontre.", [
    ("В ноябре мы с Никой решили поехать в Москву.", "En novembre, Nika et moi avons décidé d'aller à Moscou."),
    ("Мы хотели увидеть Артёма и посмотреть город.", "Nous voulions voir Artiom et visiter la ville."),
    ("Мы купили билеты на ночной поезд.", "Nous avons acheté des billets pour le train de nuit."),
    ("Поезд отправился в десять часов вечера.", "Le train est parti à dix heures du soir.", P),
    ("В нашем купе было четыре места.", "Dans notre compartiment, il y avait quatre places."),
    ("С нами ехала пожилая женщина с собакой.", "Une dame âgée voyageait avec nous, avec son chien."),
    ("Женщину звали Галина Петровна.", "La dame s'appelait Galina Petrovna."),
    ("Она угостила нас пирожками с капустой.", "Elle nous a offert des pirojki au chou."),
    ("Проводница принесла нам чай в красивых стаканах.", "La contrôleuse nous a apporté du thé dans de jolis verres.", P),
    ("Мы долго разговаривали, а потом легли спать.", "Nous avons longuement discuté, puis nous nous sommes couchées."),
    ("Утром я проснулась и посмотрела в окно.", "Le matin, je me suis réveillée et j'ai regardé par la fenêtre.", P),
    ("Там были леса, поля и маленькие деревни.", "Il y avait des forêts, des champs et de petits villages."),
    ("В восемь утра поезд приехал в Москву.", "À huit heures du matin, le train est arrivé à Moscou."),
    ("На вокзале нас ждал Артём с цветами.", "À la gare, Artiom nous attendait avec des fleurs."),
    ("«Добро пожаловать в Москву!» — сказал он.", "« Bienvenue à Moscou ! » a-t-il dit."),
], [("поезд", "train"), ("билет", "billet"), ("купе", "compartiment"), ("проводница", "contrôleuse (de train)"), ("вокзал", "gare")], [
    ("Когда отправился поезд?", "Quand le train est-il parti ?", ["В десять часов вечера", "В восемь утра", "В полночь"], 0),
    ("Чем Галина Петровна угостила девушек?", "Qu'a offert Galina Petrovna aux filles ?", ["Блинами", "Пирожками с капустой", "Конфетами"], 1),
    ("Кто ждал их на вокзале?", "Qui les attendait à la gare ?", ["Дедушка Фёдор", "Даша", "Артём"], 2),
])

story("den-rozhdeniya", "A2", 3, "День рождения", "L'anniversaire", "🎂", "red",
      "Une surprise pour le vieux Fiodor, qui a des histoires de marin à raconter.", [
    ("В декабре у дедушки Фёдора был день рождения.", "En décembre, c'était l'anniversaire du vieux Fiodor."),
    ("Ему исполнился восемьдесят один год.", "Il a eu quatre-vingt-un ans."),
    ("Мы с Никой решили сделать ему сюрприз.", "Nika et moi avons décidé de lui faire une surprise."),
    ("Ника испекла торт, а я нарисовала открытку.", "Nika a fait un gâteau, et moi, j'ai dessiné une carte."),
    ("На открытке был Пирожок в шапке.", "Sur la carte, il y avait Pirojok avec un bonnet."),
    ("Вечером мы позвонили в его дверь.", "Le soir, nous avons sonné à sa porte.", P),
    ("Дедушка открыл и очень удивился.", "Le vieil homme a ouvert et a été très surpris."),
    ("«С днём рождения!» — закричали мы.", "« Joyeux anniversaire ! » avons-nous crié."),
    ("Он засмеялся и пригласил нас войти.", "Il a éclaté de rire et nous a invitées à entrer."),
    ("Мы пили чай, ели торт и слушали его истории.", "Nous avons bu du thé, mangé du gâteau et écouté ses histoires.", P),
    ("Когда-то дедушка Фёдор был моряком.", "Autrefois, le vieux Fiodor était marin."),
    ("Он видел много стран, даже Францию!", "Il a vu beaucoup de pays, même la France !"),
    ("«Марсель — красивый город», — сказал он.", "« Marseille est une belle ville », a-t-il dit."),
    ("Потом он взял гитару и спел старую песню.", "Puis il a pris une guitare et a chanté une vieille chanson.", P),
    ("Пирожок спал у меня на коленях.", "Pirojok dormait sur mes genoux."),
    ("Это был прекрасный вечер.", "C'était une soirée merveilleuse."),
], [("день рождения", "anniversaire"), ("сюрприз", "surprise"), ("торт", "gâteau"), ("открытка", "carte"), ("моряк", "marin")], [
    ("Сколько лет исполнилось дедушке?", "Quel âge le vieux Fiodor a-t-il eu ?", ["Восемьдесят один", "Семьдесят", "Девяносто"], 0),
    ("Что нарисовала Камилла?", "Qu'a dessiné Camille ?", ["Торт", "Открытку с Пирожком", "Корабль"], 1),
    ("Кем был дедушка Фёдор раньше?", "Que faisait le vieux Fiodor autrefois ?", ["Поваром", "Учителем", "Моряком"], 2),
])

story("u-vracha", "A2", 4, "У врача", "Chez le médecin", "🩺", "teal",
      "Mal de gorge et fièvre : le médecin passe, et le voisin apporte le meilleur remède.", [
    ("В понедельник я проснулась и почувствовала себя плохо.", "Lundi, je me suis réveillée et je me suis sentie mal."),
    ("У меня болели голова и горло.", "J'avais mal à la tête et à la gorge."),
    ("Ника потрогала мой лоб: «У тебя температура!»", "Nika a touché mon front : « Tu as de la fièvre ! »"),
    ("Она сразу вызвала врача.", "Elle a tout de suite appelé le médecin."),
    ("Через час пришёл врач, молодой мужчина в очках.", "Une heure plus tard, le médecin est arrivé, un jeune homme à lunettes.", P),
    ("«Что вас беспокоит?» — спросил он.", "« Qu'est-ce qui ne va pas ? » a-t-il demandé."),
    ("Я рассказала ему всё.", "Je lui ai tout raconté."),
    ("Он послушал меня и посмотрел горло.", "Il m'a auscultée et a regardé ma gorge."),
    ("«Ничего страшного, это простуда», — сказал он.", "« Rien de grave, c'est un rhume », a-t-il dit."),
    ("«Вам нужно три дня лежать дома и пить много чая с мёдом».", "« Vous devez rester couchée trois jours et boire beaucoup de thé au miel. »"),
    ("Он написал рецепт и ушёл.", "Il a écrit une ordonnance et il est parti.", P),
    ("Ника пошла в аптеку и купила лекарство.", "Nika est allée à la pharmacie et a acheté le médicament."),
    ("Дедушка Фёдор принёс мне малиновое варенье.", "Le vieux Fiodor m'a apporté de la confiture de framboises."),
    ("«Это лучшее лекарство», — сказал он.", "« C'est le meilleur des remèdes », a-t-il dit."),
    ("Через три дня я снова была здорова.", "Trois jours plus tard, j'étais de nouveau en bonne santé.", P),
], [("врач", "médecin"), ("болеть", "faire mal"), ("простуда", "rhume"), ("аптека", "pharmacie"), ("лекарство", "médicament")], [
    ("Что болело у Камиллы?", "Où Camille avait-elle mal ?", ["Нога и рука", "Голова и горло", "Живот"], 1),
    ("Что сказал врач?", "Qu'a dit le médecin ?", ["Это простуда", "Нужно ехать в больницу", "Можно идти на занятия"], 0),
    ("Что принёс дедушка Фёдор?", "Qu'a apporté le vieux Fiodor ?", ["Цветы", "Малиновое варенье", "Лекарство из аптеки"], 1),
])

story("pirozhok-propal", "A2", 5, "Пирожок пропал", "Pirojok a disparu", "🔎", "amber",
      "Le chat du voisin est introuvable. Tout l'immeuble le cherche.", [
    ("Однажды утром дедушка Фёдор постучал в нашу дверь.", "Un matin, le vieux Fiodor a frappé à notre porte."),
    ("Он был очень грустный.", "Il était très triste."),
    ("«Пирожок пропал! Я не видел его со вчерашнего вечера».", "« Pirojok a disparu ! Je ne l'ai pas vu depuis hier soir. »"),
    ("Мы сразу начали искать кота.", "Nous avons tout de suite commencé à chercher le chat.", P),
    ("Мы проверили все этажи, подвал и двор.", "Nous avons vérifié tous les étages, la cave et la cour."),
    ("Ника спросила соседей, но никто не видел Пирожка.", "Nika a demandé aux voisins, mais personne n'avait vu Pirojok."),
    ("Я написала объявление: «Пропал рыжий кот. Очень ленивый, любит рыбу».", "J'ai écrit une annonce : « Chat roux perdu. Très paresseux, aime le poisson. »"),
    ("Мы повесили объявления у каждого подъезда.", "Nous avons accroché des annonces à chaque entrée d'immeuble."),
    ("Весь день мы ждали. Никто не позвонил.", "Nous avons attendu toute la journée. Personne n'a appelé.", P),
    ("Вечером я пошла в магазин за рыбой.", "Le soir, je suis allée au magasin acheter du poisson."),
    ("Когда я вернулась, я услышала знакомое «мяу».", "Quand je suis revenue, j'ai entendu un « miaou » familier."),
    ("Звук шёл из нашей кухни!", "Le bruit venait de notre cuisine !"),
    ("Пирожок сидел в шкафу, где мы храним рыбные консервы.", "Pirojok était assis dans le placard où nous rangeons les conserves de poisson.", P),
    ("Наверное, он вошёл, когда мы утром открыли дверь.", "Il était sans doute entré quand nous avions ouvert la porte le matin."),
    ("Оказалось, он спал там весь день.", "En fait, il avait dormi là toute la journée."),
    ("Дедушка Фёдор смеялся до слёз.", "Le vieux Fiodor a ri aux larmes."),
], [("пропасть", "disparaître"), ("искать", "chercher"), ("объявление", "annonce"), ("никто", "personne"), ("шкаф", "placard, armoire")], [
    ("Кто постучал в дверь?", "Qui a frappé à la porte ?", ["Ника", "Дедушка Фёдор", "Артём"], 1),
    ("Что написала Камилла?", "Qu'a écrit Camille ?", ["Письмо маме", "Объявление", "Рецепт"], 1),
    ("Где был Пирожок?", "Où était Pirojok ?", ["В подвале", "На улице", "В шкафу на кухне"], 2),
])

story("pervyy-sneg", "A2", 6, "Первый снег", "La première neige", "⛸️", "blue",
      "La ville est toute blanche : Camille chausse des patins pour la première fois.", [
    ("В начале ноября я проснулась, и всё было белое.", "Début novembre, je me suis réveillée, et tout était blanc."),
    ("Ночью выпал первый снег.", "Pendant la nuit, la première neige était tombée."),
    ("Я никогда не видела так много снега!", "Je n'avais jamais vu autant de neige !"),
    ("В Лионе снег бывает редко, и он быстро тает.", "À Lyon, il neige rarement, et la neige fond vite."),
    ("Ника сказала: «Одевайся! Идём на каток!»", "Nika a dit : « Habille-toi ! On va à la patinoire ! »", P),
    ("Я надела куртку, шапку и тёплые сапоги.", "J'ai mis ma veste, mon bonnet et des bottes chaudes."),
    ("Каток был в парке, недалеко от реки.", "La patinoire était dans le parc, près de la rivière."),
    ("Там было много людей: дети, студенты, даже бабушки!", "Il y avait beaucoup de monde : des enfants, des étudiants, même des grands-mères !"),
    ("Я каталась на коньках первый раз в жизни.", "Je patinais pour la première fois de ma vie.", P),
    ("Сначала я всё время падала.", "Au début, je tombais tout le temps."),
    ("Маленький мальчик подъехал ко мне и сказал: «Не бойтесь! Смотрите на меня!»", "Un petit garçon a glissé jusqu'à moi et a dit : « N'ayez pas peur ! Regardez-moi ! »"),
    ("Через час я уже могла кататься одна.", "Une heure plus tard, je pouvais déjà patiner seule."),
    ("Потом мы пили горячий шоколад и смотрели на снег.", "Ensuite, nous avons bu un chocolat chaud en regardant la neige.", P),
    ("Теперь я понимаю, почему русские любят зиму.", "Maintenant, je comprends pourquoi les Russes aiment l'hiver."),
], [("снег", "neige"), ("каток", "patinoire"), ("кататься на коньках", "patiner"), ("падать", "tomber"), ("бояться", "avoir peur")], [
    ("Куда пошли девушки?", "Où sont allées les filles ?", ["В кино", "На каток", "В библиотеку"], 1),
    ("Что делала Камилла сначала?", "Que faisait Camille au début ?", ["Падала", "Пела", "Каталась очень быстро"], 0),
    ("Кто помог Камилле?", "Qui a aidé Camille ?", ["Ника", "Маленький мальчик", "Бабушка"], 1),
])

story("borshch", "A2", 7, "Борщ Артёма", "Le bortsch d'Artiom", "🍲", "red",
      "Artiom vient à Kazan et apprend aux filles à faire un vrai bortsch.", [
    ("Артём приехал в Казань на выходные.", "Artiom est venu à Kazan pour le week-end."),
    ("Он сказал: «Сегодня я научу вас готовить настоящий борщ».", "Il a dit : « Aujourd'hui, je vais vous apprendre à faire un vrai bortsch. »"),
    ("Сначала мы пошли на рынок за продуктами.", "D'abord, nous sommes allés au marché faire les courses."),
    ("Мы купили свёклу, капусту, картошку, морковь, лук и мясо.", "Nous avons acheté de la betterave, du chou, des pommes de terre, des carottes, des oignons et de la viande."),
    ("Дома Артём поставил большую кастрюлю на плиту.", "À la maison, Artiom a mis une grande casserole sur la cuisinière.", P),
    ("Сначала он долго варил мясо.", "D'abord, il a fait cuire la viande longtemps."),
    ("Я резала овощи, а Ника тёрла свёклу.", "Je coupais les légumes, et Nika râpait la betterave."),
    ("Её руки стали совсем красными!", "Ses mains sont devenues toutes rouges !"),
    ("Потом Артём положил всё в кастрюлю.", "Ensuite, Artiom a tout mis dans la casserole.", P),
    ("«Главное — не спешить», — сказал он.", "« L'essentiel, c'est de ne pas se presser », a-t-il dit."),
    ("Через два часа борщ был готов.", "Deux heures plus tard, le bortsch était prêt."),
    ("Мы ели его со сметаной и чёрным хлебом.", "Nous l'avons mangé avec de la crème fraîche et du pain noir.", P),
    ("Это было очень вкусно!", "C'était délicieux !"),
    ("Я записала рецепт, чтобы приготовить борщ для родителей во Франции.", "J'ai noté la recette pour préparer un bortsch à mes parents, en France."),
], [("готовить", "cuisiner, préparer"), ("кастрюля", "casserole"), ("свёкла", "betterave"), ("овощи", "légumes"), ("рецепт", "recette")], [
    ("Что они готовили?", "Qu'ont-ils préparé ?", ["Блины", "Борщ", "Пельмени"], 1),
    ("Почему руки Ники стали красными?", "Pourquoi les mains de Nika sont-elles devenues rouges ?", ["Она тёрла свёклу", "Ей было холодно", "Она рисовала"], 0),
    ("Сколько времени варился борщ?", "Combien de temps le bortsch a-t-il cuit ?", ["Два часа", "Десять минут", "Весь день"], 0),
])

story("pismo-domoy", "A2", 8, "Письмо домой", "Lettre à la maison", "✉️", "violet",
      "Trois mois après son arrivée, Camille écrit à ses parents à Lyon.", [
    ("Дорогие мама и папа!", "Chers maman et papa,"),
    ("Я живу в Казани уже три месяца.", "Je vis à Kazan depuis déjà trois mois.", P),
    ("Время прошло очень быстро.", "Le temps est passé très vite."),
    ("Сначала мне было трудно: я плохо понимала людей и часто терялась в городе.", "Au début, c'était difficile : je comprenais mal les gens et je me perdais souvent en ville."),
    ("Теперь я понимаю почти всё, если люди говорят медленно.", "Maintenant, je comprends presque tout si les gens parlent lentement."),
    ("У меня появилось много друзей.", "Je me suis fait beaucoup d'amis.", P),
    ("Ника стала мне как сестра.", "Nika est devenue comme une sœur pour moi."),
    ("Наш сосед, дедушка Фёдор, рассказывает мне истории о море.", "Notre voisin, le vieux Fiodor, me raconte des histoires de mer."),
    ("А его кот Пирожок спит у нас почти каждый вечер.", "Et son chat Pirojok dort chez nous presque tous les soirs."),
    ("Я научилась кататься на коньках и готовить борщ.", "J'ai appris à patiner et à faire le bortsch.", P),
    ("Зимой здесь очень холодно, но у меня есть тёплая шапка и малиновое варенье.", "En hiver, il fait très froid ici, mais j'ai un bonnet chaud et de la confiture de framboises."),
    ("Я очень скучаю по вам и по Лиону.", "Vous me manquez beaucoup, et Lyon aussi.", P),
    ("Но я рада, что приехала сюда.", "Mais je suis contente d'être venue ici."),
    ("Летом я приеду домой и приготовлю вам настоящий русский ужин.", "Cet été, je rentrerai à la maison et je vous préparerai un vrai dîner russe."),
    ("Целую, ваша Камилла.", "Je vous embrasse. Votre Camille.", P),
], [("дорогой", "cher"), ("скучать", "s'ennuyer de, manquer"), ("научиться", "apprendre (à faire)"), ("понимать", "comprendre"), ("сюда", "ici (direction)")], [
    ("Сколько времени Камилла живёт в Казани?", "Depuis combien de temps Camille vit-elle à Kazan ?", ["Три месяца", "Один год", "Две недели"], 0),
    ("Чему она научилась?", "Qu'a-t-elle appris ?", ["Играть на гитаре", "Кататься на коньках и готовить борщ", "Водить машину"], 1),
    ("Что она сделает летом?", "Que fera-t-elle cet été ?", ["Поедет в Москву", "Приедет домой и приготовит ужин", "Будет работать в ресторане"], 1),
])

json.dump({"stories": S}, open(sys.argv[1], "w"), ensure_ascii=False, indent=1)
print(len(S), "stories")
