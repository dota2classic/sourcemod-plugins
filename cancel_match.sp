#include <sdktools>

public void OnPluginStart() {
    RegServerCmd("cancel_match", Cancel_Match);
}
 
public Action Cancel_Match(int args) {
    setGameState(7);
    kickEveryone();
    return Plugin_Continue;
}

void setGameState(int value) {
    GameRules_SetProp("m_nGameState", value, 4, 0, true);  
    Event event = CreateEvent("game_rules_state_change");
    event.Fire(); 
}

void kickEveryone() {
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i)) {
            KickClient(i, "%s", "123");
        }
    }
}
