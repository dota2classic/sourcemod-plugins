#include <sdktools>

public OnMapStart() {
    CreateTimer(5.0, HookGameRulesStateChange);
}

public Action:HookGameRulesStateChange(Handle:timer) {
    HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
}

public Action:OnGameStateChange(Handle:event, String:name[], bool:dontBroadcast) {
  
    if (isDraftStageOver()) {
        if (FindCommandLineParam("-bots_enabled")) {
            ServerCommand("dota_bot_populate")
        }
        UnhookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
    }
    return Plugin_Continue;
}

public bool:isDraftStageOver() {
    return GameRules_GetProp("m_nGameState", 4, 0) > 3;
}

