# Сравнение с оригинальным The ARK

## Структурный вывод

Оригинальный Workshop-мод `3707475814` официально рассчитан на single player. Проверенная версия 42.20 содержит 189 Lua-файлов (37 645 строк): 54 client-файла, 133 shared-файла и только два server-файла — 16-строчный farming patch и пустой items-файл. Симуляция, сюжет и строительство фактически исполняются локальным клиентом.

Статические признаки: 85 обращений к `getSpecificPlayer(0)`, 23 `sendClientCommand`, ни одного `sendServerCommand`, одно объявление `TransmitBWOAModData`, для которого нет вызывающего кода. Поэтому MP-форк переносит ассеты и правила, но переписывает authority, persistence и replication.

## Сопоставление систем

| Оригинал | MP-реализация | Статус |
|---|---|---|
| client-side строительство мира | server-side construction с фазами, probes и latched error | `replaced_mp` |
| локальные генераторы/освещение | каноническая энергетика + физические IsoGenerator bridges + light manifests | `replaced_mp` |
| локальная вентиляция | server model, room volumes, CO2, intakes, breach, replication | `replaced_mp` |
| `WaterOn/Off` пусты; `manageWater` не подписан и содержит undefined global | Waterpipes adapter, storages, pump, repair, idempotent transactions | `replaced_mp` |
| поле `ventilation.filter` не расходуется | server-authoritative фильтр как жёсткий барьер | `replaced_mp` |
| радиация/медицина исполняются клиентом | поверхностное загрязнение и дезактивация перенесены; полноценная доза/симптомы/лекарства отложены | `candidate_slice4` / `deferred_rewrite` |
| одиночное отопление/климат | server simulation, physical nodes, repairs и persistence | `candidate_slice4` |
| research — единственный scalar 0–100, двигаемый NPC | новый project engine ещё не начат | `not_started` |

### Радиация предметов и визуальная обратная связь

Оригинал использует булево `item:getModData().radiated`. Клиентский
`ISUI/ISInventoryPanePatch.lua` закрашивает строку такого предмета полупрозрачным
зелёным. `BWOAPlayer.applyRadiationToItems` раз в игровую минуту заражает содержимое
инвентаря игрока и предметы в квадрате 3x3, включая содержимое трупов; достаточно
заражённого предмета рядом, потому что `RetroRadiation` фактически всегда включён
ошибочным выражением `SandboxVars.BWOA.RetroRadiation or true`. При смерти
`BWOAZombie.onDeadBodySpawn` копирует флаг трупа на его вещи. NBC-обработка просто
сбрасывает флаг у игрока, напольных предметов, вложенных контейнеров и трупов.

В MP-форке это заменено численным server-authoritative значением
`BunkerCampaignSurfaceContamination` от 0 до 100. Сервер постепенно переносит его
между предметами одного незапечатанного inventory tree, игроками, предметами на полу,
стационарными хранилищами и трупами в ограниченном радиусе загруженного мира. Булево
`radiated` поддерживается как производный compatibility/UI-флаг, но не является
источником authority. Сервер раз в status snapshot присылает ID и значения переносимых
предметов владельцу; клиент рисует зелёные строки и снимает их после подтверждённой
очистки. В отличие от первоначального QA-прототипа постоянный world-space текст над
персонажем не используется: в оригинале были только краткие красные/зелёные HaloText
при изменении дозы и звук счётчика Гейгера при наличии прибора. Верхний числовой
`TOXIC EXPOSURE / SURFACE / GEAR` остаётся диагностическим интерфейсом MP-форка, а не
воспроизведением оригинала. Полная доза, симптомы и лекарства оригинала
по-прежнему относятся к `deferred_rewrite`: текущий `exposure` нельзя выдавать за
готовую медицинскую модель лучевой болезни.

В оригинале встречаются дефекты, которые нельзя переносить как требования: выражение `RetroRadiation or true`, ошибочная формула shower и ссылка на undefined `onRead`.

## Сюжетный слой

Проверено: 30 миссий, 206 узлов диалогов, 26 PlaceEvents, 10 кошмаров, 27 ZombieActions и 9 ZombiePrograms. NOAH включает 16 экранов, Emma и AI-надстройка завязаны на клиентскую временную шкалу. Этот слой не входит в локальный системный MP-MVP:

- NOAH, Emma/NPC, миссии, диалоги, кошмары, авторская timeline и финалы — `excluded_local_mvp`;
- возможный сетевой сюжет и NPC — `deferred_rewrite`, отдельное продуктовое решение;
- story/mission metadata в декоративных записках не считается активным gameplay-контрактом.

## Дельта оригинала 42.18 → 42.20

Изменены девять файлов:

1. `media/lua/client/Actions/TAAddCorpse.lua`
2. `media/lua/client/BWOAMenu.lua`
3. `media/lua/client/BWOASquareLoader.lua`
4. `media/lua/shared/BWOABaseAPI.lua`
5. `media/lua/shared/BWOABuildTools.lua`
6. `media/lua/shared/BWOAPlaceEvents.lua`
7. `media/lua/shared/BWOAPrepareTools.lua`
8. `media/lua/shared/Scenes/SFallasChurch.lua`
9. `mod.info`

Существенные изменения — удаление ряда ручных `transmitCompleteItemToServer/ToClients` и изменение удаления light switch через `transmitRemoveItemFromSquare`. В MP-форке Build 42.20 также нужен startup guard: `GlobalModData` может инициализироваться раньше `GameServer.udpEngine`.

## Что не связано с оригиналом

Cryogenic Winter не обнаружен ни в коде, ни в зависимостях оригинала. Компетенции, специализации, наследование знаний, пять колец опасности, автомодули, полноценный GM Director, мастерская, гараж, радиоцентр и серверная как рабочие комнаты — новые требования и должны проектироваться с нуля.
