# Аудит API Build 42.19

Проверка выполнена по текущим локальным файлам установки, не по старому `console.txt`. Steam-манифест указывает beta-ветку 42.19 и build ID 23504596; текущий `projectzomboid.jar` обновлён 27 июля 2026 года.

## Подтверждённые API

| API | Локальное подтверждение | Использование |
| --- | --- | --- |
| `ModData.getOrCreate(key)` | `media/lua/server/Foraging/forageServer.lua`, The Ark `BWOAGMD.lua` | серверное сохраняемое состояние |
| `Events.OnInitGlobalModData` | `media/lua/server/Vehicles/ProfessionVehicles.lua` | загрузка и миграция состояния |
| `Events.EveryOneMinute` | `media/lua/server/Camping/SCampfireSystem.lua` | дискретная симуляция |
| `sendClientCommand(player,module,command,args)` | многочисленные B42 client/shared timed actions | запрос клиента серверу |
| `Events.OnClientCommand(module,command,player,args)` | `media/lua/server/Foraging/forageServer.lua` и `Waterpipes` | серверный диспетчер команд |
| `sendServerCommand(player,module,command,args)` | `media/lua/shared/Util/LuaNet.lua` | ответ одному клиенту |
| `sendServerCommand(module,command,args)` | `media/lua/shared/Util/LuaNet.lua` | широковещательный снимок |
| `Events.OnServerCommand(module,command,args)` | `media/lua/client/ServerCommands.lua` | получение снимка клиентом |
| `IsoPlayer:isAccessLevel(String)` | сигнатура текущего `zombie.characters.IsoPlayer` через `javap` | серверная проверка администратора |
| `getGameTime():getWorldAgeHours()` | сигнатура текущего `zombie.GameTime` через `javap` | игровые метки времени |
| `getGametimeTimestamp()` | сигнатура текущего `LuaManager.GlobalObject` через `javap` | ограничение частоты запросов |
| `ISCollapsableWindow`, `ISButton` | текущие `media/lua/client/ISUI` | окно состояния |

## Принятые ограничения

- Global ModData используется только сервером; для клиентов отправляются отдельные снимки.
- Автоматическое сохранение Global ModData является штатным поведением движка и повторяет использование в базовой системе уникального транспорта.
- Проверка роли делается сервером через `player:isAccessLevel("admin")`; скрытие кнопки на клиенте — только удобство, не защита.
- Не использованы неподтверждённые методы записи отдельных файлов сохранения.

## Пока не проверено

- совместное включение The Ark 42.18 и прототипа на 42.19;
- публичный API Toxic Zones для получения интенсивности в произвольной координате;
- горячая перезагрузка Lua на запущенном dedicated server;
- поведение UI в split-screen.
