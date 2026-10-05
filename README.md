# 🎃 JACK'S HOUSE — хэллоуин-хоррор для Roblox

Игра для 2-8 игроков: проклятый дом, двери, монстр, предатель среди своих и конфеты.

Этот документ — пошаговая сборка в Roblox Studio. Код уже готов, тебе нужно только
собрать место (карту) и вставить скрипты в правильные места.

---

## Что уже сделано (кодом)

- Раунды: лобби → отсчёт → дом → итоги, всё автоматом
- 12 комнат строятся ИЗ ОДНОГО ШАБЛОНА — строишь одну комнату, код клонирует её в коридор
- Двери открываются касанием, прогресс сохраняется
- Монстр: просыпается после 2-й двери, гонится за ближайшим, убивает касанием
- Отключение света каждые ~40 сек — в темноте монстр быстрее
- ПРЕДАТЕЛЬ: при 3+ игроках один случайный получает кнопку «СТУК» —
  монстр 10 секунд гонится за случайной жертвой. Кто предатель — никто не знает
- Конфеты: за двери (+5), за побег (+25), предателю за жертву (+15)
- Конфеты сохраняются между заходами (DataStore)
- HUD: двери, конфеты, фонарик (кнопка 🔦 или клавиша F)

---

## Шаг 1. Создай место

1. Открой Roblox Studio → New → Baseplate
2. Сразу удали SpawnLocation, если он мешает (потом поставим свой)

## Шаг 2. Построй лобби

1. Поставь SpawnLocation где-нибудь в стороне, например X = 200
2. Рядом сделай площадку-лобби (пол, стены, надпись TextLabel на доске — по желанию)
3. Добавь НЕВИДИМУЮ часть в лобби (любой Part):
   - Name = `LobbySpawn`
   - Anchored = ON, CanCollide = OFF, Transparency = 1
   - Положи её на пол лобби — туда игроки возвращаются после раунда

Лобби должно быть ДАЛЕКО от коридора дома (минимум 200 стадов),
иначе монстр будет видеть игроков в лобби. Лучше всего в стороне по оси X.

## Шаг 3. Папка ассетов

1. В Explorer найди **ServerStorage**
2. ПКМ → Insert Object → **Folder**, назови `GameAssets`
3. Внутри GameAssets создай **Model** с именем `RoomTemplate`

## Шаг 4. Шаблон комнаты RoomTemplate (самое важное!)

Строй RoomTemplate прямо на базовой плите, там начнётся дом.

Размеры примера: ширина 36, длина 72, высота стен 24 (можешь свои).

Внутри RoomTemplate должно быть:

1. **Пол и стены** — обычные Parts, всё Anchored = ON
2. **Decorations** — расставь хэллоуин-декор из Toolbox (паутина, тыквы, свечи,
   скелеты). НЕ ставь части, перекрывающие путь от входа к двери
3. Часть с именем **`Door`** — дверь на ДАЛЬНЕЙ стене комнаты:
   - Anchored = ON, CanCollide = ON
   - Размер примерно 12 × 24 (проём в стене)
4. Часть с именем **`SpawnPad`** — у ВХОДА комнаты (противоположный от двери конец):
   - Anchored = ON, CanCollide = OFF, Transparency = 1, CanTouch = ON
   - Размер примерно как пол комнаты, высотой 1, лежит на полу
   - Она нужна коду: точка входа + детектор прогресса

⚠️ ПРАВИЛА:
- Комната должна стоять так, чтобы её ДЛИННАЯ сторона была по оси Z (глубина),
  а дверь — в дальнем конце по Z
- Вход комнаты — та сторона, где SpawnPad. Дверь — противоположная
- Если после запуска дом построился «не туда» — открой `GameConfig` и поменяй
  `CORRIDOR_DIRECTION = 1` (или `CORRIDOR_AXIS = "X"`)

## Шаг 5. Монстр

1. Найди в Toolbox любую жуткую модель монстра (например, из раздела Monsters/Horror)
2. Перетащи её модель в `ServerStorage/GameAssets`
3. Назови модель ровно `Monster`
4. ВАЖНО: открой модель и поставь **у ВСЕХ частей Anchored = ON**
   (движение делает код, физика не нужна)
5. Поставь модель так, чтобы она стояла НА ПОЛУ шаблона комнаты — высота запомнится

## Шаг 6. Освещение (атмосфера)

В свойствах Lighting поставь (не обязательно, но лучше):
- ClockTime = 0 (полночь)
- Brightness = 1.5
- FogEnd = 100000

## Шаг 7. Скрипты

Скопируй файлы из этой папки:

| Файл | Куда в Studio | Тип |
|---|---|---|
| `ServerScriptService/Halloween/Main.server.lua` | ServerScriptService → папка **Halloween** → объект **Script** с именем `Main` | Script |
| `.../Modules/GameConfig.lua` | ServerScriptService → Halloween → **Modules** → ModuleScript `GameConfig` | ModuleScript |
| `.../Modules/CandyManager.lua` | туда же → ModuleScript `CandyManager` | ModuleScript |
| `.../Modules/MapGen.lua` | туда же → ModuleScript `MapGen` | ModuleScript |
| `.../Modules/MonsterAI.lua` | туда же → ModuleScript `MonsterAI` | ModuleScript |
| `.../Modules/RoundManager.lua` | туда же → ModuleScript `RoundManager` | ModuleScript |
| `StarterPlayerScripts/GameClient.client.lua` | StarterPlayer → StarterPlayerScripts → LocalScript `GameClient` | LocalScript |

Структура в Explorer должна быть такая:

```
ServerScriptService
└─ Halloween (Folder)
   ├─ Main (Script)
   └─ Modules (Folder)
      ├─ GameConfig (ModuleScript)
      ├─ CandyManager (ModuleScript)
      ├─ MapGen (ModuleScript)
      ├─ MonsterAI (ModuleScript)
      └─ RoundManager (ModuleScript)
StarterPlayer
└─ StarterPlayerScripts
   └─ GameClient (LocalScript)
ServerStorage
└─ GameAssets (Folder)
   ├─ RoomTemplate (Model)
   └─ Monster (Model)
Workspace
├─ LobbySpawn (Part)
├─ SpawnLocation (лобби)
└─ (пусто — дом построит код сам)
```

⚠️ В каждый ModuleScript/Script/Localscript вставь ТОЛЬКО содержимое файла,
без строки пути. Имена должны совпадать буква в букву.

## Шаг 8. Включи сохранения (DataStore)

1. Home → Game Settings → Security
2. Включи **Enable Studio Access to API Services** → Save
3. Опубликуй игру: File → Publish to Roblox (нужно для работы DataStore)

## Шаг 9. Тест

1. Открой `GameConfig` и поставь `MIN_PLAYERS = 1` (для одиночного теста)
2. Нажми Play: дом построится сам, отсчёт пойдёт сразу
3. Для теста на троих: вкладка Test → Clients and Servers → 3 Players → Start

## Шаг 10. После теста

- Верни `MIN_PLAYERS = 2` (или сколько хочешь минимум)
- Крути настройки в GameConfig: скорость монстра, частота блэкаута, длина дома
- Для запуска: Publish → в настройках игры на сайте включи Public

---

## Баланс (подкрути в GameConfig)

- Монстр медленнее игрока (13 против 16) — убежать МОЖНО, но в темноте (20) — почти нет
- Фонарик в блэкауте спасает, но свет виден монстру... (соц. механика: включать или прятаться)
- Предателю выгодно, чтобы гибли другие (+15 за жертву), но сам он тоже бегает от монстра

## Дальнейшие апгрейды (говори, сделаю)

- Звуки: скрип дверей, стук, сердцебиение, скример при смерти
- Магазин скинов за конфеты (тыквы, маски, костюмы)
- Разные типы монстров на разных дверях (спрятался в шкаф от одного, замри от другого)
- Лидерборд по конфетам
- Геймпассы (VIP, x2 конфеты)
