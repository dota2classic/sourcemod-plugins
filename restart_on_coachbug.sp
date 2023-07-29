#include <sdktools>

bool pluginIsActive = true;
char logfile[256];

public OnPluginStart() { 
    getCommandLineParamStr("+con_logfile", logfile, sizeof(logfile), "logs/" )
    if (StrContains(logfile, ".log") == -1) {
        StrCat(logfile, sizeof(logfile), ".log")
    }
}

public OnMapStart() {
    // if (FindCommandLineParam("-players")) {
    //     pluginIsActive = false;
    // }
    // else {
    //     pluginIsActive = true;
    // }

    // if (GameRules_GetProp("m_iGameMode", 4, 0) == 2) { // disable plugin for cm
    //     pluginIsActive = false;
    // }

    if (pluginIsActive) {
        CreateTimer(10.0,  restartOnCoachbug, _, TIMER_REPEAT);
    }
}


public Action restartOnCoachbug(Handle timer) {
    if (findCoachBug()) {
        PrintToChatAll("[SM] restarting in 5 seconds")        
        PrintToServer("[SM] restarting in 5 seconds")

        CreateTimer(5.0, restartMap);
        return Plugin_Stop;
    }
    else if (isDraftStage()) {
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public Action restartMap(Handle:timer) {
    char command[256]
    Format(command, sizeof(command), "changelevel dota; dota_force_gamemode %d", GameRules_GetProp("m_iGameMode", 4, 0));
    ServerCommand(command);
}

public bool isDraftStage() {
    return GameRules_GetProp("m_nGameState", 4, 0) > 1;
}

public bool findCoachBug() {
    new pr = GetPlayerResourceEntity();
    
    int i = 10;
    while (i < 31) {
        int teamInt = GetEntProp(pr, PropType:0, "m_iPlayerTeams", 4, i);
        if (isRadiantOrDire(teamInt)) {
            return true;
        }
        i++;
    }
    return false;
}

bool isRadiantOrDire(int teamInt) {
    return teamInt == 2 || teamInt == 3;
}

void getCommandLineParamStr(const char[] param, char[] value, int maxlen,
                              const char[] defValue) {
    if (!FindCommandLineParam(param)) {
        Format(value, maxlen, "%s", defValue);
        return;
    }                              
    char commandLine[4000];                              
    bool isValidCommandLine = GetCommandLine(commandLine, sizeof(commandLine))
    if (isValidCommandLine) { 
        int i = StrContains(commandLine, param) + strlen(param)
        int j = 0;
        int started = false;
        char endSymbol = ' ';

        while (i < strlen(commandLine)) {  
             if (!started) {
                if (commandLine[i] != ' ') {
                    started = true;
                    if (commandLine[i] == '"') {
                        endSymbol = commandLine[i];
                        i++;
                    }
                }
            } 
            if (started) {
                if (commandLine[i] == endSymbol || commandLine[i] == '\0') {
                    break;
                }
                value[j] = commandLine[i];
                j++;
            }
            i++;
        }
    } else {
        Format(value, maxlen, "%s", defValue);
    }
}
