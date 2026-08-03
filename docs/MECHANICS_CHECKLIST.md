# Полный чек-лист механик

## Правила

Допустимые статусы: `accepted_main`, `candidate_slice4`, `replaced_mp`, `deferred_rewrite`, `excluded_local_mvp`, `not_started`, `blocked`.

Каждая строка содержит: доказательство из оригинала/ТЗ; MP-файл или символ; automated test; runtime correlation; persistence/restart; разрыв и целевой этап. `RT pending` означает, что код/тест есть, но dedicated one-client сценарий ещё не засчитан. `P pending` — restart persistence не подтверждён в текущем QA-профиле.

Сокращения доказательств:

- `Core` — `BunkerCampaign/42.0/media/lua`; `Ark` — `BunkerCampaignArkMP/42.0/media/lua`.
- `Toxic` — `BunkerCampaignToxicMP/42.0/media/lua`; `Int` — `BunkerCampaignIntegration/42.0/media/lua`.
- `A33` — соответствующий suite из 33/33 отчёта `artifacts/test-results.json`.
- `Orig client` — оригинал 42.20: 54 client + 133 shared против двух фактически пустых server-файлов.

## Порядок переноса из `message.txt`

| ID | Механика / статус | Оригинал или ТЗ | MP-реализация / automated | Runtime / persistence | Разрыв → этап |
|---|---|---|---|---|---|
| M0 | фундамент — `replaced_mp` | Orig client | `CampaignState`, schema, commands; A33 state suites | RT pending; P model tested | one-client + restart → Gate 0 |
| M1 | помещения — `replaced_mp` | client build geometry | `Ark/Server/MapRegistration`, `RoomRegistry`; A33 Ark | RT pending; P world | clean-world probes → Gate 0 |
| M2 | питание — `accepted_main` | local generator logic | `PowerSimulation`, `PhysicalPowerGrid`; A33 power | RT pending; P pending | shedding/bridge/restart → Gate 0 |
| M3 | управление/NOAH — `excluded_local_mvp` | 16-screen NOAH | системная панель; NOAH не исполняется | panel RT pending; P n/a | сетевой narrative rewrite → Gate 5 |
| M4 | вентиляция — `accepted_main` | client vent, inert filter | `VentilationSimulation`, rooms/intakes; A33 vent | RT pending; P pending | five modes/breach/restart → Gate 0 |
| M5 | отопление — `candidate_slice4` | local climate/heating | `HeatingSimulation`, physical nodes; A33 heating | RT pending; P pending | controller/repair/breach → Gate 0 |
| M6 | вода — `replaced_mp` | dead WaterOn/Off/manageWater | `WaterService`, Waterpipes adapter; A33 water | RT pending; P pending | pump/tap/restart → Gate 0 |
| M7 | загрязнение — `replaced_mp` | original `radiated`, green inventory patch, 3x3 retro-transfer | Toxic numeric authority, carried/world/container/corpse contact, compatible green UI; A33 toxic | `...-contamination-visual-001`: carried transfer + client parity; P pending | corpse/storage visual confirmation + restart → Gate 0 |
| M8 | дезактивация — `replaced_mp` | client shower/actions | Int cycle + timed wash + idempotency; A33 decon | RT pending; P pending | cancel/atomic/restart → Gate 0 |
| M9 | рабочие модули — `not_started` | mostly geometry | rooms exist, project functions absent | RT/P n/a | lab/workshop/server/radio/greenhouse → Gate 2 |
| M10 | компетенции — `not_started` | absent beyond traits/memory | no engine | RT/P n/a | sections 42–73 → Gate 3 |
| M11 | research/training — `deferred_rewrite` | scalar research driven by NPC | no project engine | RT/P n/a | persistent projects/curriculum → Gates 2–3 |
| M12 | экспедиции — `deferred_rewrite` | story missions/PlaceEvents | no systemic rings/artifacts | RT/P n/a | progression → Gate 4 |
| M13 | транспорт — `not_started` | no required automodule system | no implementation | RT/P n/a | logistics/fuel/modules → Gate 4 |
| M14 | GM/Director/campaign — `deferred_rewrite` | fixed timeline/finals | admin QA only | QA auth RT pending | Director/profiles/acts → Gate 5 |

## ТЗ, разделы 1–41 (`pasted-text.txt`)

| § | Механика / статус | Оригинал или ТЗ | MP-реализация / automated | Runtime / persistence | Разрыв → этап |
|---|---|---|---|---|---|
| 1 | общая задача — `candidate_slice4` | bunker survival MP | четыре активных мода; A33 | RT pending; P pending | полный Gate 0 |
| 2 | ключевые особенности — `candidate_slice4` | systemic bunker | core life support готов | RT pending | research/expeditions absent → 2–4 |
| 3 | основной loop — `candidate_slice4` | maintain/expand/expedition | maintain реализован | RT pending | expand/expedition → 2–4 |
| 4 | отличие от The ARK — `replaced_mp` | Orig client | server authority + snapshots; A33 | RT pending | 2-client gate |
| 5 | design principles — `candidate_slice4` | systems/team/consequences | authoritative simulations | RT/P pending | team roles → 3 |
| 6 | внешние угрозы — `candidate_slice4` | fallout/toxic/breach | climate, toxic, breach; A33 | RT pending | hostile director → 5 |
| 7 | медицина — `deferred_rewrite` | original client dose/medicine | surface contamination only | RT partial; P pending | dose/symptoms/drugs → 1 |
| 8 | системы бункера — `candidate_slice4` | power/water/air/heat | Core/Int; A33 | RT/P pending | Gate 0 acceptance |
| 9 | состояния систем — `candidate_slice4` | wear/fault/repair | power/intake/heating faults | RT/P pending | unified diagnostics UX → 0/2 |
| 10 | исследования — `not_started` | project engine required | only legacy scalar evidence | n/a | Gate 2 |
| 11 | примеры исследований — `not_started` | upgrades/projects | absent | n/a | Gate 2 |
| 12 | уникальные предметы — `candidate_slice4` | detectors/materials/artifacts | detector/mag and repair items | RT pending | artifacts/project items → 2/4 |
| 13 | размещение — `replaced_mp` | original client rooms | server 22-room build; A33 | RT pending; P world | clean-world → 0 |
| 14 | зональная прогрессия — `not_started` | five rings | Toxic geometry only | RT toxic pending | five-ring engine → 4 |
| 15 | транспорт — `not_started` | vehicles/logistics | absent | n/a | Gate 4 |
| 16 | топливо как milestone — `not_started` | logistics milestone | generator fuel exists, transport loop absent | RT power pending | Gate 4 |
| 17 | базы — `not_started` | outposts/bases | bunker only | n/a | Gate 4 |
| 18 | роль GM — `deferred_rewrite` | live GM | admin QA only | auth RT pending | Gate 5 |
| 19 | GM-события — `deferred_rewrite` | dynamic events | original PlaceEvents excluded | n/a | server Director → 5 |
| 20 | GM-панель — `not_started` | control panel | QA menu is not GM panel | RT QA pending | Gate 5 |
| 21 | без GM — `not_started` | automatic Director | absent | n/a | Gate 5 |
| 22 | MP-архитектура — `candidate_slice4` | server authority | commands/state/snapshots/debug; A33 | RT pending | 2-client gate |
| 23 | глобальное состояние — `candidate_slice4` | persistent campaign | `CampaignState` schema v8; A33 | RT restart pending | Gate 0 |
| 24 | состояние модулей — `candidate_slice4` | per-module faults | power/vent/water/heat models | RT/P pending | work modules → 2 |
| 25 | фильтры — `replaced_mp` | original filter inert | vent + mask filter consumption; A33 | RT/P pending | Gate 0 |
| 26 | защитный костюм — `candidate_slice4` | protection layers | masks/clothing surfaces partial | RT pending | full suit/dose → 1 |
| 27 | загрязнение предметов — `replaced_mp` | original local | Toxic world/inventory/corpse transfer; A33 | RT/P pending | Gate 0 |
| 28 | автомодули — `not_started` | vehicle upgrades | absent | n/a | Gate 4 |
| 29 | UI — `candidate_slice4` | system/research/skill UI | scrollable system panel + newest log | RT resolutions pending | research/skills UI → 2/3 |
| 30 | server config — `candidate_slice4` | profiles/options | `arkmp_qa`, fixed sandbox scripts | RT profile pending | profiles Story/etc → 5 |
| 31 | кампания — `deferred_rewrite` | acts/endings | original story excluded | n/a | Gate 5 |
| 32 | баланс — `candidate_slice4` | configurable rates | constants + BWOA sandbox | RT/P pending | measured multiplayer tuning → all |
| 33 | feedback — `candidate_slice4` | clear state/errors | snapshots, panel, debug telemetry | RT pending | user testing → 0 |
| 34 | NFR — `candidate_slice4` | stability/performance | fixed ticks, bounded telemetry, tests | RT soak pending | profiling/two clients → 0 |
| 35 | project structure — `accepted_main` | modular contexts | four mods, client/server/shared split | static verified | keep ownership boundaries |
| 36 | stages — `candidate_slice4` | phased delivery | roadmap gates documented | n/a | execute 0–5 |
| 37 | MVP — `candidate_slice4` | systemic bunker MVP | life support complete in code | RT/P pending | Gate 0 |
| 38 | acceptance — `blocked` | runtime/restart/MP gates | automated 33/33 only | one-client pending; 2-client blocked | runtime session |
| 39 | first Codex task — `candidate_slice4` | audit/baseline | scripts + docs + fixes | runtime pending | finish Gate 0 |
| 40 | response requirements — `candidate_slice4` | evidence/status/plan | this checklist + QA report | update after runtime | Gate 0 |
| 41 | final formulation — `candidate_slice4` | long-term bunker platform | architecture ready, features partial | provisional only | Gates 0–5 |

## Компетенции, разделы 42–73 (`pasted-text (1).txt`)

| § | Механика / статус | Оригинал или ТЗ | MP-реализация / automated | Runtime / persistence | Разрыв → этап |
|---|---|---|---|---|---|
| 42 | ценность навыков — `not_started` | new design; original traits only | no competency engine | n/a | Gate 3 |
| 43 | три уровня — `not_started` | required model | absent | n/a | schema + migration → 3 |
| 44 | soft gates — `not_started` | required rule | absent | n/a | Gate 3 |
| 45 | типы требований — `not_started` | skill/tool/team | current repairs have local skill checks only | RT repair pending | generalize → 3 |
| 46 | research-skill examples — `not_started` | curriculum examples | absent | n/a | Gates 2–3 |
| 47 | квалификация влияет на результат — `not_started` | quality/risk | heating repair has pass/fail only | RT pending | generalized quality → 3 |
| 48 | развитие без grind — `not_started` | milestone learning | absent | n/a | Gate 3 |
| 49 | специализации — `not_started` | specialization model | absent | n/a | Gate 3 |
| 50 | лимиты специализаций — `not_started` | role scarcity | absent | n/a | Gate 3 |
| 51 | командные роли — `not_started` | multiplayer roles | no persistent roles | 2-client blocked | Gate 3 |
| 52 | совместное исследование — `not_started` | multiple contributors | absent | n/a | Gates 2–3 |
| 53 | альтернатива без специалиста — `not_started` | cost/risk alternative | absent | n/a | Gate 3 |
| 54 | защита прогресса после смерти — `not_started` | inheritance | `MemoryRegain` story option inactive | n/a | Gate 3 |
| 55 | milestones навыка — `not_started` | milestone rewards | absent | n/a | Gate 3 |
| 56 | expedition rewards — `not_started` | knowledge rewards | absent | n/a | Gates 3–4 |
| 57 | anti-grind — `not_started` | diminishing/relevance | absent | n/a | Gate 3 |
| 58 | риск вместо запрета — `not_started` | soft failure | repairs partial precedent | RT repairs pending | generalized engine → 3 |
| 59 | качество craft/repair — `not_started` | outcome quality | repair restores fixed state | RT pending | Gate 3 |
| 60 | навыки и диагностика — `candidate_slice4` | diagnostic requirements | heating diagnosis checks skills/tools | RT/P pending | generalize → 3 |
| 61 | навыки и expedition info — `not_started` | scouting intelligence | absent | n/a | Gates 3–4 |
| 62 | навыки и центральный компьютер — `excluded_local_mvp` | new central UI; NOAH not reusable | system panel only | RT pending | new project UI → 2–3 |
| 63 | competency UI — `not_started` | display levels/progress | absent | n/a | Gate 3 |
| 64 | technical structure — `not_started` | server authority/schema | campaign architecture reusable | n/a | add competency schema → 3 |
| 65 | specialization data — `not_started` | persistent definitions | absent | n/a | Gate 3 |
| 66 | curriculum data — `not_started` | course definitions | absent | n/a | Gate 3 |
| 67 | project competence check — `not_started` | project gate | no project engine | n/a | Gates 2–3 |
| 68 | server-authoritative rewards — `not_started` | server grant | command pattern exists; rewards absent | 2-client blocked | Gate 3 |
| 69 | изменённый main loop — `not_started` | learn/research/expedition | maintenance only | n/a | Gates 2–4 |
| 70 | три типа progression — `not_started` | character/team/world | campaign state only | n/a | Gates 2–4 |
| 71 | дополнение MVP — `not_started` | minimal competencies | absent | n/a | Gate 3 |
| 72 | дополнение acceptance — `blocked` | death/team/two-client cases | no implementation | runtime unavailable | Gate 3 + 2 clients |
| 73 | итоговое ощущение — `not_started` | specialist team fantasy | systemic bunker partial | n/a | Gates 2–5 |

## Gate 0 runtime matrix

До смены `candidate_slice4` на принятый статус обязательны correlation IDs для: clean construction; reconnect/revision; generator shedding and battery; light manifests; tainted-water pump/repair and duplicate transaction; five ventilation modes, four intakes/doors; mask/filter, ambient deposition, contact transfer, items/corpses; external and bunker timed wash, automatic/emergency cycle and failed preflight; six heating nodes, controller range, diagnosis/repair, `power_shed`, breach losses; forged remote/admin/stale snapshot requests. После этого — restart и отдельная двухклиентская сессия.
