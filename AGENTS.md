# AGENTS.md

## Project

This repository contains a Project Zomboid Build 42 Lua mod.

```text
Mod suite: Bunker Campaign
Main Lua global: BunkerCampaign
Module globals: BunkerCampaignArkMP, BunkerCampaignIntegration,
                BunkerCampaignToxicMP
```

A running Project Zomboid client and dedicated server can be inspected and controlled through ZombieBuddy HTTP APIs.

Use direct HTTP requests. No custom CLI or MCP server is required.

---

## 1. Runtime architecture

The dedicated server and client are separate processes.

Each process has its own:

* Lua environment;
* loaded files;
* globals;
* events;
* Java objects;
* log;
* ZombieBuddy HTTP API.

```text
Dedicated server: http://127.0.0.1:4444
Game client:      http://127.0.0.1:4445
```

A Lua request sent to the server runs only on the server.

A Lua request sent to the client runs only on the client.

Shared Lua files must be reloaded separately in both processes.

---

## 2. ZombieBuddy setup

Install and enable ZombieBuddy for both:

* the dedicated server;
* the game client.

The target mod must also be enabled on both sides where required.

### Dedicated server JVM arguments

Add before the normal server game arguments:

```text
-agentlib:zbNative=experimental,lua_server_host=127.0.0.1,lua_server_port=4444,lua_task_timeout=5000,verbosity=1 --
```

### Client launch arguments

```text
-agentlib:zbNative=experimental,lua_server_host=127.0.0.1,lua_server_port=4445,lua_task_timeout=5000,verbosity=1 -- -debug
```

Use different ports when server and client run on the same machine.

Start in this order:

1. Start the dedicated server.
2. Wait until its ZombieBuddy API responds.
3. Start the client.
4. Connect the client to the server.
5. Wait until the client player exists.
6. Begin runtime development.

If using `lua_server_port=random`, server and client must use different cache directories. ZombieBuddy writes the selected port to:

```text
<cache directory>\zbLuaAPI.txt
```

For initial testing, fixed ports `4444` and `4445` are simpler.

---

## 3. PowerShell environment

Use `curl.exe`, not the PowerShell `curl` alias.

```powershell
$ServerApi = "http://127.0.0.1:4444"
$ClientApi = "http://127.0.0.1:4445"
```

Available endpoints:

```text
GET  /status
GET  /version
GET  /log?lines=N
POST /lua
```

---

## 4. Check both processes

### Server

```powershell
curl.exe -sS --fail-with-body "$ServerApi/status"
curl.exe -sS --fail-with-body "$ServerApi/version"
```

### Client

```powershell
curl.exe -sS --fail-with-body "$ClientApi/status"
curl.exe -sS --fail-with-body "$ClientApi/version"
```

Expected `/status` response:

```text
ok
```

### Verify server role

```powershell
@'
return {
    target = "server",
    isServer = isServer(),
    isClient = isClient(),
    loadedLuaFiles = getLoadedLuaCount()
}
'@ | curl.exe `
    -sS `
    --fail-with-body `
    -X POST `
    "$ServerApi/lua?depth=3&sandbox=true&chunkname=server_role.lua" `
    -H "Content-Type: text/plain; charset=utf-8" `
    --data-binary "@-"
```

Expected:

```text
isServer = true
```

### Verify client role

```powershell
@'
return {
    target = "client",
    isServer = isServer(),
    isClient = isClient(),
    playerAvailable = getPlayer() ~= nil,
    loadedLuaFiles = getLoadedLuaCount()
}
'@ | curl.exe `
    -sS `
    --fail-with-body `
    -X POST `
    "$ClientApi/lua?depth=3&sandbox=true&chunkname=client_role.lua" `
    -H "Content-Type: text/plain; charset=utf-8" `
    --data-binary "@-"
```

Expected:

```text
isClient = true
playerAvailable = true
```

---

## 5. Executing Lua

Use this request format:

```powershell
@'
return {
    ok = true,
    target = isServer() and "server"
        or isClient() and "client"
        or "unknown"
}
'@ | curl.exe `
    -sS `
    --fail-with-body `
    -X POST `
    "$ClientApi/lua?depth=3&sandbox=true&chunkname=agent_probe.lua" `
    -H "Content-Type: text/plain; charset=utf-8" `
    --data-binary "@-"
```

Change `$ClientApi` to `$ServerApi` when the code must run on the server.

Query parameters:

```text
depth=3
sandbox=true
chunkname=meaningful_name.lua
```

Use `depth` from 2 to 5 for normal inspection.

Return small values:

* strings;
* numbers;
* booleans;
* small Lua tables;
* selected object properties.

Do not return complete world, player, inventory or UI object graphs.

`sandbox=true` should be used normally.

Use `sandbox=false` only when persistent global definitions are required.

---

## 6. Read logs

### Server log

```powershell
curl.exe -sS --fail-with-body "$ServerApi/log?lines=300"
```

### Client log

```powershell
curl.exe -sS --fail-with-body "$ClientApi/log?lines=300"
```

Always distinguish server and client logs.

Before a test, write the same correlation marker to both processes:

```text
agent-test-001
```

Server:

```powershell
@'
local id = "agent-test-001"
print("[AGENT][SERVER] correlation=" .. id)
return id
'@ | curl.exe `
    -sS `
    --fail-with-body `
    -X POST `
    "$ServerApi/lua?depth=1&sandbox=true&chunkname=server_marker.lua" `
    -H "Content-Type: text/plain; charset=utf-8" `
    --data-binary "@-"
```

Client:

```powershell
@'
local id = "agent-test-001"
print("[AGENT][CLIENT] correlation=" .. id)
return id
'@ | curl.exe `
    -sS `
    --fail-with-body `
    -X POST `
    "$ClientApi/lua?depth=1&sandbox=true&chunkname=client_marker.lua" `
    -H "Content-Type: text/plain; charset=utf-8" `
    --data-binary "@-"
```

---

## 7. Runtime snapshots

### Server snapshot

A dedicated server normally has no local `getPlayer()`.

Use `getOnlinePlayers()`.

```powershell
@'
local result = {
    target = "server",
    isServer = isServer(),
    modLoaded = BunkerCampaign ~= nil,
    loadedLuaFiles = getLoadedLuaCount(),
    players = {}
}

local players = getOnlinePlayers()

if players then
    for i = 0, players:size() - 1 do
        local player = players:get(i)

        result.players[#result.players + 1] = {
            username = player:getUsername(),
            onlineID = player:getOnlineID(),
            x = player:getX(),
            y = player:getY(),
            z = player:getZ()
        }
    end
end

if BunkerCampaign
    and BunkerCampaign.Debug
    and BunkerCampaign.Debug.getServerState
then
    result.modState = BunkerCampaign.Debug.getServerState()
end

return result
'@ | curl.exe `
    -sS `
    --fail-with-body `
    -X POST `
    "$ServerApi/lua?depth=5&sandbox=true&chunkname=server_snapshot.lua" `
    -H "Content-Type: text/plain; charset=utf-8" `
    --data-binary "@-"
```

### Client snapshot

```powershell
@'
local player = getPlayer()

local result = {
    target = "client",
    isClient = isClient(),
    modLoaded = BunkerCampaign ~= nil,
    playerAvailable = player ~= nil,
    loadedLuaFiles = getLoadedLuaCount()
}

if player then
    result.player = {
        username = player:getUsername(),
        onlineID = player:getOnlineID(),
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
        health =
            player:getBodyDamage():getOverallBodyHealth(),
        inventoryCount =
            player:getInventory():getItems():size()
    }
end

if BunkerCampaign
    and BunkerCampaign.Debug
    and BunkerCampaign.Debug.getClientState
then
    result.modState = BunkerCampaign.Debug.getClientState()
end

return result
'@ | curl.exe `
    -sS `
    --fail-with-body `
    -X POST `
    "$ClientApi/lua?depth=5&sandbox=true&chunkname=client_snapshot.lua" `
    -H "Content-Type: text/plain; charset=utf-8" `
    --data-binary "@-"
```

---

## 8. Available ZombieBuddy inspection tools

ZombieBuddy provides Lua functions for inspecting Java and Lua runtime state.

### Inspect an object

```lua
return zbinspect(getPlayer(), false)
```

Include private fields:

```lua
return zbinspect(getPlayer(), true)
```

### List methods

```lua
return zbmethods(getPlayer(), false)
```

Filter results:

```lua
return zbgrep(zbmethods(getPlayer(), true), "Inventory")
```

### List fields

```lua
return zbfields(getPlayer(), false)
```

Filter fields:

```lua
return zbgrep(zbfields(getPlayer(), true), "health")
```

### Read a field

```lua
return zbget(object, "fieldName", nil)
```

### Write a field

```lua
return zbset(object, "fieldName", value)
```

### Invoke a Java method

```lua
return zbcall(object, "methodName", arg1, arg2)
```

Prefer normal Project Zomboid Lua methods. Use reflection helpers when the normal API is insufficient.

---

## 9. Inspect Lua events

### Events registered by a loaded file

```lua
local path = "exact loaded Lua path"
local events = ZombieBuddy.Events.getByFile(path)
local result = {}

for eventName, callbacks in pairs(events) do
    result[eventName] = {}

    for i = 1, #callbacks do
        result[eventName][i] =
            ZombieBuddy.getClosureInfo(callbacks[i])
    end
end

return result
```

### Callbacks registered for an event

```lua
local callbacks = ZombieBuddy.Events.getByName("OnTick")
local result = {}

for i = 1, #callbacks do
    result[i] = ZombieBuddy.getClosureInfo(callbacks[i])
end

return result
```

Run the request against the process being inspected.

Server events and client events are independent.

Use event inspection after hot reload to detect duplicate callbacks.

---

## 10. Java method watches

A watch affects only the JVM where it was created.

### Add a watch

```lua
return ZombieBuddy.Watches.Add(
    "fully.qualified.ClassName",
    "methodName",
    3
)
```

Watch modes:

```text
1 = before
2 = after
3 = before and after
```

### Include Java stack traces

```lua
ZombieBuddy.Watches.setStackDepth(8)
return true
```

### Remove a watch

```lua
return ZombieBuddy.Watches.Remove(
    "fully.qualified.ClassName",
    "methodName"
)
```

### Remove all watches

```lua
ZombieBuddy.Watches.Clear()
return true
```

After adding a watch:

1. reproduce the action;
2. read the corresponding process log;
3. remove the watch.

A server watch does not watch the client, and a client watch does not watch the server.

---

## 11. Find loaded mod files

Run separately on the server and client:

```lua
local needle = "BunkerCampaign"
local result = {}

for i = 0, getLoadedLuaCount() - 1 do
    local path = getLoadedLua(i)

    if string.find(
        string.lower(path),
        string.lower(needle),
        1,
        true
    ) then
        result[#result + 1] = path
    end
end

return result
```

Use the exact returned path for reload and event inspection.

---

## 12. Hot reload

`reloadLuaFile()` reloads only the selected process.

### Reload function

```lua
local suffix = "media/lua/shared/path/to/File.lua"
local matches = {}

for i = 0, getLoadedLuaCount() - 1 do
    local path = getLoadedLua(i)

    if path == suffix or path:sub(-#suffix) == suffix then
        matches[#matches + 1] = path
    end
end

if #matches == 0 then
    error("Loaded Lua file not found: " .. suffix)
end

if #matches > 1 then
    error("Ambiguous Lua file: " .. table.concat(matches, ", "))
end

reloadLuaFile(matches[1])
triggerEvent("OnSourceWindowFileReload")

return {
    reloaded = true,
    path = matches[1],
    target = isServer() and "server"
        or isClient() and "client"
        or "unknown"
}
```

Send this code to the correct endpoint.

File locations determine where to reload:

```text
media/lua/client  → client only
media/lua/server  → server only
media/lua/shared  → server and client separately
```

After reload:

1. read the process log;
2. inspect relevant events;
3. run the affected scenario;
4. inspect the resulting state.

Hot reload does not recreate the complete process.

Existing globals, objects, timed actions and old event callbacks may remain.

Event registration should therefore be replaceable:

```lua
BunkerCampaign = BunkerCampaign or {}
BunkerCampaign.Runtime = BunkerCampaign.Runtime or {}

if BunkerCampaign.Runtime.onTick then
    Events.OnTick.Remove(BunkerCampaign.Runtime.onTick)
end

BunkerCampaign.Runtime.onTick = function()
    -- current implementation
end

Events.OnTick.Add(BunkerCampaign.Runtime.onTick)
```

---

## 13. Recommended mod debug interface

When useful, expose:

```lua
BunkerCampaign.Debug
```

Recommended functions:

```lua
BunkerCampaign.Debug.getServerState()
BunkerCampaign.Debug.getClientState()

BunkerCampaign.Debug.getLastServerCommand()
BunkerCampaign.Debug.getLastClientCommand()

BunkerCampaign.Debug.getLastServerError()
BunkerCampaign.Debug.getLastClientError()

BunkerCampaign.Debug.runServerScenario(name, args)
BunkerCampaign.Debug.runClientScenario(name, args)

BunkerCampaign.Debug.resetServerState()
BunkerCampaign.Debug.resetClientState()
```

Debug functions should return small plain Lua tables.

Example server state:

```lua
{
    context = "server",
    lastReceivedCommand = {
        module = "...",
        command = "...",
        username = "...",
        correlationId = "agent-test-001",
        args = {}
    },
    lastValidation = {
        success = true,
        reason = nil
    },
    lastMutation = {},
    lastResponse = {},
    lastError = nil
}
```

Example client state:

```lua
{
    context = "client",
    lastSentCommand = {},
    lastReceivedResponse = {},
    lastUIUpdate = {},
    lastCorrelationId = "agent-test-001",
    lastError = nil
}
```

Prefer structured debug state over parsing text logs.

---

## 14. Client/server testing workflow

For every multiplayer behavior:

1. Check server `/status`.
2. Check client `/status`.
3. Verify `isServer()` on the server.
4. Verify `isClient()` and `getPlayer()` on the client.
5. Capture server pre-state.
6. Capture client pre-state.
7. Write the same correlation marker to both logs.
8. Trigger the action from its real initiating side.
9. Wait briefly for multiplayer propagation.
10. Inspect the receiving side.
11. Capture server post-state.
12. Capture client post-state.
13. Read both logs.
14. Compare expected and actual results.

For client-to-server behavior, verify:

```text
client initiated
server received
server validated
server changed authoritative state
server responded or replicated
client received the result
client updated local state or UI
```

Do not manually invoke both final handlers. Trigger the real client/server path.

Examples:

```text
UI action:
client → server → client

Server timer:
server → client

Server validation:
client → server

Client UI-only change:
client only
```

Multiplayer updates are asynchronous. The initiating HTTP request may complete before the other process receives the network message.

Poll the relevant debug state for a few seconds when required.

---

## 15. Code placement

Respect Project Zomboid contexts:

```text
media/lua/client
```

Client UI, input and local-player behavior.

```text
media/lua/server
```

Authoritative server logic, validation and persistence.

```text
media/lua/shared
```

Code loaded in both contexts.

Do not assume `getPlayer()` exists on the dedicated server.

Use `getOnlinePlayers()` for connected server players.

Do not verify authoritative world changes only from client state.

Do not verify client UI behavior only from server state.

---

## 16. Agent development loop

For each task:

1. Read the relevant files and call paths.
2. Determine whether the code runs on the server, client or both.
3. Inspect the current runtime state.
4. Make the smallest relevant change.
5. Reload the changed files in every affected process.
6. Read server and client errors.
7. Trigger the real scenario.
8. Inspect server and client state.
9. Compare expected and observed behavior.
10. Fix and repeat when necessary.

Prefer this debugging order:

1. Mod debug state.
2. Focused Lua snapshots.
3. Logs.
4. Event inspection.
5. Object inspection.
6. Java watches.

Breakpoints are not part of this direct HTTP workflow.

---

## 17. First runtime task

Before modifying code:

1. Check server and client `/status`.
2. Check both `/version` endpoints.
3. Verify server and client roles.
4. Verify that the client player exists.
5. Get the server's connected-player list.
6. Get the client's local-player snapshot.
7. Find mod Lua files loaded on the server.
8. Find mod Lua files loaded on the client.
9. Identify shared files loaded in both.
10. Inspect events for one server file.
11. Inspect events for one client file.
12. Read both logs.
13. Report server and client results separately.

After that succeeds:

1. Add or modify one read-only debug function.
2. Reload its file in every affected process.
3. Call the function on the server and client.
4. Check both logs.
5. Verify that events were not duplicated.

Then test one harmless client-to-server-to-client round trip using a correlation ID.

---

## 18. Completion report

For runtime changes report:

```text
Files changed:

Server runtime available:
Client runtime available:
Client player available:

Server files reloaded:
Client files reloaded:

Initiating side:
Correlation ID:

Action executed:
Server result:
Client result:

Server errors:
Client errors:

Restart required:
Remaining limitations:
```
