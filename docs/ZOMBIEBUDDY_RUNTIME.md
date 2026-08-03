# ZombieBuddy runtime

## Процессы и endpoints

Dedicated server и клиент — две независимые JVM/Lua VM:

```text
Server: http://127.0.0.1:4444
Client: http://127.0.0.1:4445
GET /status  GET /version  GET /log?lines=N  POST /lua
```

Порты привязаны только к `127.0.0.1`. Shared Lua нужно reload-ить в обоих процессах.

Server agent:

```text
-agentlib:zbNative=experimental,lua_server_host=127.0.0.1,lua_server_port=4444,lua_task_timeout=5000,verbosity=1,policy=deny-new,frontend=console
```

Client agent:

```text
-agentlib:zbNative=experimental,lua_server_host=127.0.0.1,lua_server_port=4445,lua_task_timeout=5000,verbosity=1,policy=prompt
```

В server batch между JVM/agent и игровыми аргументами сохраняется `--`. В JSON клиента отдельный `--` не добавляется.

## PowerShell helpers

```powershell
$ServerApi = 'http://127.0.0.1:4444'
$ClientApi = 'http://127.0.0.1:4445'
curl.exe -sS --fail-with-body "$ServerApi/status"
curl.exe -sS --fail-with-body "$ClientApi/version"
curl.exe -sS --fail-with-body "$ServerApi/log?lines=300"
```

В текущей Windows-конфигурации сервер и клиент используют общий cache-каталог. Runtime-прогон 2 августа 2026 показал, что `/log` на 4444 и 4445 возвращает одинаковый клиентский tail. Не использовать эти два ответа как доказательство разделения процессов; читать `C:\Users\Grishin\Zomboid\server-console.txt` для dedicated server и `C:\Users\Grishin\Zomboid\console.txt` для клиента. `/lua`, `/status` и `/version` при этом остаются раздельными.

Lua helper:

```powershell
@'
return { isServer=isServer(), isClient=isClient(), player=getPlayer() ~= nil }
'@ | curl.exe -sS --fail-with-body -X POST `
  "$ClientApi/lua?depth=3&sandbox=true&chunkname=role_probe.lua" `
  -H 'Content-Type: text/plain; charset=utf-8' --data-binary '@-'
```

На сервере используйте `getOnlinePlayers()`, а не `getPlayer()`. Не возвращайте целые object graphs.

## Начальный аудит

1. `/status` и `/version` обоих процессов.
2. `isServer()==true` на 4444; `isClient()==true` и `getPlayer()~=nil` на 4445.
3. Connected players и client local-player snapshot.
4. `getLoadedLuaCount/getLoadedLua` с фильтрами каждого модуля на обеих сторонах.
5. Пересечение shared-файлов.
6. `ZombieBuddy.Events.getByFile` минимум для server и client файла.
7. Отдельные логи с общей correlation marker.

## Correlation marker

```lua
local id = "arkmp-qa-001"
print((isServer() and "[AGENT][SERVER] " or "[AGENT][CLIENT] ") .. "correlation=" .. id)
return id
```

Отправить один и тот же marker отдельно на 4444 и 4445. Для client → server → client запускать настоящий клиентский путь и опрашивать debug state; не вызывать конечные handlers вручную.

## Debug contract

`BunkerCampaign.Debug` предоставляет небольшие read-only snapshots:

```text
getServerState() / getClientState()
getLastServerCommand() / getLastClientCommand()
getLastServerError() / getLastClientError()
runServerScenario(name,args) / runClientScenario(name,args)
resetServerState() / resetClientState()  # только тестовая телеметрия
```

Scenario `state_snapshot` на сервере и `state_round_trip` на клиенте не должны менять gameplay state.

## Hot reload и events

Найдите точный loaded path и вызовите `reloadLuaFile(path)`, затем `triggerEvent('OnSourceWindowFileReload')`. `client/` reload только на клиенте, `server/` только на сервере, `shared/` — отдельно в обеих VM. После reload прочитать лог и проверить `ZombieBuddy.Events.getByName/getByFile`, чтобы callback не продублировался.

ToxicMP хранит ссылки на callbacks и удаляет предыдущие перед `Events.*.Add`; тот же шаблон обязателен для новых runtime callbacks.

## Inspection и watches

```lua
return zbinspect(getPlayer(), false)
return zbgrep(zbmethods(getPlayer(), true), "Inventory")
return zbfields(getPlayer(), false)
return ZombieBuddy.Watches.Add("fully.qualified.ClassName", "methodName", 3)
```

После Java watch: воспроизвести действие, прочитать лог именно этой JVM и удалить watch через `Remove` либо `Clear`. Reflection использовать только если обычного PZ Lua API недостаточно.

## Совместимость Java

Workshop-мод содержит API 2.3.2, а корневой runtime основан на официальном 2.3.3. `BunkerCampaignThermalJava` написан под 3.0.0-alpha (`annotations.Patch`) и намеренно выключен. В рамках этой стабилизации нельзя обновлять ZombieBuddy до master ради ThermalJava; базовый климат и отопление реализованы на Lua и должны работать без Java bridge.

Если agent отвергает HTTP-параметр, имена проверяются по локальным `Agent/Config` классам установленного JAR. Fallback — отдельные server/client логи и игровая Lua-консоль, но этот fallback не засчитывает HTTP-критерии приёмки.

### Windows/JDK 25 compatibility hotfix

HTTP API существует в стабильных 2.3.2/2.3.3, а не только в 3.0.0-alpha. Локальные исходники и байткод официального JAR подтверждают `HttpServer`, handlers и параметры `lua_server_host`, `lua_server_port`, `lua_task_timeout`. Однако `patches.experimental.PreMain` сначала вызывает `JavaStateDumper.init()`, который без guard регистрирует Unix-сигнал `INFO`. Windows/JDK 25 выбрасывает `IllegalArgumentException: Unknown signal: INFO`; внешний loader показывает её как `InvocationTargetException`, и выполнение не доходит до `HttpServer.start()`.

Официальный 2.3.3 уже исправляет отдельный startup crash `AngelCodeFont.isEmpty()`, но не Windows signal path. `tools/build-zombiebuddy-windows-hotfix.ps1` проверяет SHA-256 официального 2.3.3, компилирует единственную замену `JavaStateDumper`, удаляет ставшие недействительными JAR-signature entries и создаёт локальный артефакт. Замена только перехватывает отсутствие `INFO`; Ctrl+T и HTTP остаются без изменений.

Проверенный 2 августа 2026 артефакт имеет SHA-256 `4882D0B3FCE6F714AD5F198D77F80D252F1FAAA3C4E8E3AD1B001AA13257FA64`. Изолированный JVM probe и реальный клиент подтвердили `/status=ok`, `/version=ZombieBuddy v2.3.3`, `/log` и успешный `POST /lua`. Нетронутый официальный JAR сохраняется рядом как `ZombieBuddy.jar.official-v2.3.3`; повторная сборка начинается только от официального SHA-256 `C000C1AB79873314DB73F53B971AE004272AA145C03A0A42F1A61279C54837FE`.
