#include <sourcemod>
#include <sdktools>

bool pluginIsActive = false;
StringMap ggAliases;
StringMap lastGgCallTimeBySteamid;

int gameMinuteToEnablePluginAt = 0;
int ggCooldownPerPlayerSeconds = 180;
int secondsToCancel = 15;

int pr;
int steamIdOffset;


public OnPluginStart() {
  ggAliases = CreateTrie();
  fillGgAliases();

  HookUserMessage(GetUserMessageId("ChatWheel"), onChatWheelMessage, true);
}

public OnMapStart() {
    lastGgCallTimeBySteamid = CreateTrie();
    pr = GetPlayerResourceEntity();
    steamIdOffset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
    HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
}

public Action onChatWheelMessage(UserMsg msg_id, 
                                 Protobuf bf, 
                                 const int[] players, 
                                 int playersNum, 
                                 bool reliable, 
                                 bool init) {
    if (!pluginIsActive) {
        return Plugin_Continue;
    }

    if (isGGChatWheelMsg(PbReadInt(bf, "chat_message"))) {
        int playerId = PbReadInt(bf, "player_id");
        int teamId = getTeamByPlayerId(playerId);

        if (isRadiantOrDire(teamId))  {
            char steamId[32]; 
            getSteamidByPlayerId(steamId, playerId);

            if (isInvalidSteamId(steamId)) {
                return Plugin_Continue;
            }
            steamIdSurrender(steamId, teamId);
        }                              
    }

	return Plugin_Continue;
}

public Action:OnGameStateChange(Handle:event, String:name[], bool:dontBroadcast) {
  int gamestate = GameRules_GetProp("m_nGameState", 4, 0);
  if (gamestate == 5 && !is1v1OrBotMatch()) {
    // Enable surrendering after draft
    CreateTimer(float(gameMinuteToEnablePluginAt * 60), enablePlugin);
  } else if (gamestate == 6) {
    // Disable when game ends
    pluginIsActive = false;
  }

  return Plugin_Continue;
}

public Action enablePlugin(Handle timer) {
    PrintToServer("[debug] surrender plugin enabled")
    pluginIsActive = true;
}

public OnClientSayCommand_Post(client, const String:command[], const String:sArgs[]) {
  if (pluginIsActive && client && StrEqual(command, "say")) {
    int teamId = GetClientTeam(client);

    if (isRadiantOrDire(teamId)) {
      if (isGGChatMessage(sArgs[0])) {
        clientSurrender(client);
      }
    }
  }
}

clientSurrender(int clientSurrendered) {
  if (!pluginIsActive) {
    return;
  }

  int teamId = GetClientTeam(clientSurrendered);

  char steamidSurrendered[32];
  getSteamIdStr(clientSurrendered, steamidSurrendered);
  if (isInvalidSteamId(steamidSurrendered)) {
    return;
  }

  steamIdSurrender(steamidSurrendered, teamId);
}

void steamIdSurrender(char steamId[32], int teamId) {
  // If a different team is already surrendering, don't count ggs as a surrender vote
  if (wasGgCalled() || !isRadiantOrDire(teamId) || isGGOnCooldown(steamId)) {
      return;
  }

  // Set the player's surrender status
  SetTrieValue(lastGgCallTimeBySteamid, steamId, getGameTime());

  callGG(teamId);
}


callGG(int team) {
    GameRules_SetProp("m_nGGTeam", team, 4, 0, true);
	GameRules_SetPropFloat("m_flGGEndsAtTime", getGameTime() + secondsToCancel);
}

bool wasGgCalled() {
    return GameRules_GetProp("m_nGGTeam", 4, 0) != 0;
}

bool isRadiantOrDire(int teamId) {
    return teamId == 2 || teamId == 3;
}

bool isGGChatWheelMsg(int chatWheelMsgId) {
    return chatWheelMsgId == 75 || chatWheelMsgId == 76;
}

bool isGGChatMessage(const char[] msg) {
    bool buffer;
    return ggAliases.GetValue(msg, buffer);
}

int getTeamByPlayerId(int playerId) {
    if (playerId < 0) {
        return -1;
    }
    else if (playerId < 5) {
        return 2;
    }
    else if (playerId < 10){
        return 3;
    }
    return 1;
}

void getSteamidByPlayerId(char steamIdStr[32], int playerId) {

    int res = GetEntData(pr, playerId * 8 + steamIdOffset, 4);
    IntToString(res, steamIdStr, sizeof(steamIdStr));
}

void getSteamIdStr(int client, char steamIdBuffer[32]) {
    IntToString(GetSteamAccountID(client, true), steamIdBuffer, sizeof(steamIdBuffer));
}

bool isInvalidSteamId(char steamId[32]) {
    return StrEqual(steamId, "0");
}

float getGameTime() {
    return GameRules_GetPropFloat("m_fGameTime", 0);
}

bool isGGOnCooldown(char steamId[32]) {
    float lastGgTime;
    bool isValuePresent = lastGgCallTimeBySteamid.GetValue(steamId, lastGgTime)

    return isValuePresent
        ? (getGameTime() - lastGgTime) < ggCooldownPerPlayerSeconds 
        : false;
}

fillGgAliases() {
    ggAliases.SetValue("GG", true);
    ggAliases.SetValue("GG WP", true);
    ggAliases.SetValue("GGWP", true);
    ggAliases.SetValue("gg", true);
    ggAliases.SetValue("gg wp", true);
    ggAliases.SetValue("ggwp", true);
    ggAliases.SetValue("good game", true);
}

bool is1v1OrBotMatch() {
    return FindCommandLineParam("-bots_enabled") 
           || GameRules_GetProp("m_iGameMode", 4, 0) == 21;
}
