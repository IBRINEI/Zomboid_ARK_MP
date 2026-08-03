# Дорожная карта

## Gate 0 — стабилизация Build 42.20

Принять отопление и 42.20-совместимость после 33/33 automated suites, чистого dedicated-server мира, one-client runtime, reconnect и restart persistence. Итог — только `multiplayer provisional`; затем обязательная двухклиентская репликация.

## Gate 1 — радиация и медицина

Server-authoritative accumulated dose, защита, симптоматика, радиопротекторы/лекарства и миграция состояния. Не копировать клиентские ошибки оригинала. Gate: unit/integration, one-client runtime, restart и два клиента.

## Gate 2 — research/project engine

Проекты с требованиями, этапами, ресурсами, временем, качеством результата и persistent progress. Подключить лабораторию, мастерскую, серверную, радиоцентр и теплицу как реальные рабочие модули.

## Gate 3 — компетенции

Три уровня владения, специализации, командное исследование, обучение, деградация и наследование знаний по разделам 42–73 ТЗ. Soft gates и риск/качество вместо абсолютных запретов.

## Gate 4 — экспедиции и логистика

Пять колец опасности, артефакты, progression, транспорт, топливо и автомодули. Сервер валидирует награды и сохраняет транспортное состояние.

## Gate 5 — GM и кампания

GM/Director, sandbox-профили Story/Standard/Hardcore/GM/Sandbox, акты и стратегические финалы. NPC и сюжет The ARK — отдельное решение, не критический путь системного MP-MVP.

## Обязательный gate для каждого этапа

1. Schema migration и rollback plan.
2. Unit/integration tests и машиночитаемый отчёт.
3. One-client dedicated runtime с correlation IDs.
4. Restart persistence.
5. Два одновременно подключённых клиента.
6. Только после этого статус `accepted_mp`.
