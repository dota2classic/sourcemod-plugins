#include <sourcemod>
#include <sdktools>

bool pluginIsActive = true;
ArrayList playerSteamIds;
int pauseState = 0;
new maxPlayersByGamemode;
int maxPlayers = 0;

public OnPluginStart() {
  playerSteamIds = CreateArray(32);
  maxPlayersByGamemode = CreateTrie();
  fillMaxPlayers();
}

public OnMapStart()
{
  CreateTimer(5.0, PauseAtStart);
  CreateTimer(5.0, HookGameRulesStateChange);
  HookEvent("player_team", OnJoinTeam, EventHookMode:1);

  int gamemode = GameRules_GetProp("m_iGameMode", 4, 0);
  char gamemodeString[32];
  IntToString(gamemode, gamemodeString, 32);

  if (!GetTrieValue(maxPlayersByGamemode, gamemodeString, maxPlayers)) {
    pluginIsActive = false;
  }
}

public Action:PauseAtStart(Handle:timer) {
  Pause();
  return Plugin_Continue;
}

public Action:HookGameRulesStateChange(Handle:timer) {
    HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
}

public Action:OnGameStateChange(Handle:event, String:name[], bool:dontBroadcast) {
    UnhookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);

    pluginIsActive = false;

    return Plugin_Continue;
}

public OnGameFrame() {
  if (pluginIsActive && GameRules_GetProp("m_bGamePaused") != pauseState) {
    GameRules_SetProp("m_bGamePaused", pauseState);
  }
}

public Action:OnJoinTeam(Handle:event, String:name[], bool:dontBroadcast) {
    new clientIndex = GetClientOfUserId(GetEventInt(event, "userid"));
    char steamid[32];
    // Quickly reconnecting can cause a steam authentication error, creating a blank steam id
    if (!GetClientAuthId(clientIndex, AuthIdType:2, steamid, 32, true)) {
      return Plugin_Continue;
    }
    new teamId = GetEventInt(event, "team");

    if (teamId == 2 || teamId == 3) {
      if (playerSteamIds.FindString(steamid) == -1) {
        playerSteamIds.PushString(steamid);
      }

      if (playerSteamIds.Length >= maxPlayers) {
        Unpause();
      }
    }

    return Plugin_Continue;
}

Pause() {
  pauseState = 1;
}

Unpause() {
  pauseState = 0;
}

fillMaxPlayers() {
  // Captain's mode
  SetTrieValue(maxPlayersByGamemode, "2", 10);
  // 1v1 mid
  SetTrieValue(maxPlayersByGamemode, "11", 2);
  // Ranked all pick
  SetTrieValue(maxPlayersByGamemode, "22", 10);
}