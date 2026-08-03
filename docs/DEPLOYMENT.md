# Локальный deployment Build 42.20

## Пути этой машины

```text
Repository: C:\Users\Grishin\Desktop\ark_mp\Zomboid_ARK_MP
Client:     C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid
Server:     C:\Program Files (x86)\Steam\steamapps\common\Project Zomboid Dedicated Server
Cache:      C:\Users\Grishin\Zomboid
Mods:       C:\Users\Grishin\Zomboid\mods
```

Оригинальный The ARK остаётся только в Workshop и не активируется.

## 1. Проверка baseline

```powershell
Set-Location 'C:\Users\Grishin\Desktop\ark_mp\Zomboid_ARK_MP'
.\tools\run-tests.ps1
```

Отчёт: `artifacts/test-results.json`. Он содержит branch, commit SHA, хеш игрового JAR, каждый syntax check и каждый из 33 suite. ThermalJava отмечается как `deferred/incompatible`.

## 2. Установка локальных модов

QA по умолчанию — четыре реальные зеркальные копии:

```powershell
.\tools\deploy-mods.ps1 -Mode Qa
```

Dev — junction только для Core и Integration; ArkMP и ToxicMP копируются из-за FBX/ассетов:

```powershell
.\tools\deploy-mods.ps1 -Mode Dev
```

`-Clean` обрабатывает только четыре заранее перечисленных target-каталога после проверки resolved path. Неизвестные моды не затрагиваются. Перед заменой существующий известный target переносится в `.bunker-campaign-backup`; manifest сохраняется в `.deploy-manifests` и содержит commit, dirty-state, источники, назначения и SHA-256 каждого файла.

Не deploy-ятся: `TheArk`, `ToxicZonesSTALKERB42`, фиктивный ZombieBuddy и `BunkerCampaignThermalJava`.

## 3. Отдельный серверный профиль

```powershell
.\tools\configure-server-profile.ps1
```

Скрипт создаёт `arkmp_qa.ini`, `arkmp_qa_SandboxVars.lua` и spawn-файлы на базе `servertest`, но не меняет исходный профиль/мир. Существующий `arkmp_qa` world защищён; `-ResetWorld` переносит только его в backup.

Каноническая конфигурация:

```ini
WorkshopItems=3619862853;3268487204;3546314080
Mods=ZombieBuddy;Bandits2;Waterpipes;BunkerCampaign;BunkerCampaignArkMP;BunkerCampaignToxicMP;BunkerCampaignIntegration
Map=Muldraugh, KY
```

Явно исключены: `BanditsWeekOneTheArk`, `TheArk`, `BanditsDayOne`, `BanditsWeekOne`, `ToxicZonesSTALKERB42`, `BunkerCampaignThermalJava`.

QA sandbox:

```text
FalloutStarted=4; FalloutEnds=3; FalloutCurve=4; TemperatureDrop=3
ArkGeneratorFuelConsumption=3; ShelterOccurance=4; HostileGroupSize=3
ResidueScrap=4; SkeletonReanimation=false; AngelProximity=true
MemoryRegain=true; RetroRadiation=false
```

Story-only значения сохраняются ради воспроизводимости, но не означают активный сюжетный runtime.

## 4. ZombieBuddy и запуск

```powershell
.\tools\build-zombiebuddy-windows-hotfix.ps1
.\tools\configure-zombiebuddy.ps1
```

Первый скрипт принимает только официальный ZombieBuddy 2.3.3 с известным SHA-256 и создаёт локальный Windows/JDK 25 hotfix для experimental HTTP. Второй сохраняет timestamped backups, устанавливает этот JAR и Workshop DLL на обе стороны, заменяет только аргумент `-agentlib:zbNative` и создаёт отдельный `StartServer64_zb_arkmp_qa.bat`. Штатный launcher не изменяется. Причина и rollback описаны в `ZOMBIEBUDDY_RUNTIME.md`.

Если клиент уже запущен и держит JSON открытым, сначала примените серверную часть через `-SkipClient`, затем после штатного закрытия игры повторите с `-SkipServer`. Не завершайте клиент принудительно ради конфигурации.

Порядок:

1. Запустить `StartServer64_zb_arkmp_qa.bat`.
2. Дождаться `http://127.0.0.1:4444/status`.
3. В клиенте включить точный набор модов из конфигурации и исключить запрещённые.
4. Запустить клиент, подключиться к `arkmp_qa`, дождаться игрока.
5. Проверить `http://127.0.0.1:4445/status`, роли и snapshots.

## Rollback

- Остановить клиент и сервер.
- Вернуть клиентский JSON из timestamped `.bak` рядом с ним.
- Удалить только четыре каталога активных локальных модов или восстановить их из `.bunker-campaign-backup`.
- Удалить `arkmp_qa*` только если QA-мир больше не нужен; `servertest*` не трогать.
- Штатные server/client executables и исходный `StartServer64.bat` скрипты не меняют.
