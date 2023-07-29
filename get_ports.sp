#include <sdktools>
#include <ripext>

char httpServer[256]
char logfile[256];
int playerPort = 0;
int spectatorPort = 0;
int matchId; 

public OnPluginStart() { 
    getCommandLineParamStr("-http_server", httpServer, sizeof(httpServer), "http://localhost:8080" )
    getCommandLineParamStr("+con_logfile", logfile, sizeof(logfile), "logs/" )
    if (StrContains(logfile, ".log") == -1) {
        StrCat(logfile, sizeof(logfile), ".log")
    }
    if (FindCommandLineParam("-http_server")) {
        CreateTimer(6.0,  scanLogs, _, TIMER_REPEAT);
    }
    matchId = GetCommandLineParamInt("-match_id", -1); 
}


public Action scanLogs(Handle timer) {
    //PrintToServer("Scanning the log")
    if (findPorts()) {
        sendPortsHttpRequest()
        return Plugin_Stop;
    }
    else if (isDraftStage()) {
        PrintToServer("Stop scanning the log")
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public bool isDraftStage() {
    return GameRules_GetProp("m_nGameState", 4, 0) > 1;
}

public bool findPorts() {
    char filePath[PLATFORM_MAX_PATH];
    char filePathRelative[256] = "../../";
    StrCat(filePathRelative, sizeof(filePathRelative), logfile)
    BuildPath(Path_SM, filePath, sizeof(filePath), filePathRelative); 

    new Handle:fileHandle = OpenFile( filePath, "r" ); 
    char fileLine[512];

    bool isBugged = false;
    bool searchForLeaverStatus = false;

    while (!IsEndOfFile(fileHandle) && ReadFileLine(fileHandle, fileLine, sizeof(fileLine))) {
        if (StrContains(fileLine, "Opened server(") != -1) {
            int startIdx = StrContains(fileLine, "Opened server(") + strlen("Opened server(")
            int endIdx =   FindCharInString(fileLine, ')', false) + 1
            char playerPortStr[32];
            subSTR(fileLine, playerPortStr, startIdx, endIdx)
            //PrintToServer("---------------%d %d %s", startIdx, endIdx, playerPortStr)
            playerPort = StringToInt(playerPortStr)
        } else if (StrContains(fileLine, "Opened hltv(") != -1) {
            int startIdx = StrContains(fileLine, "Opened hltv(") + strlen("Opened hltv(")
            int endIdx =   FindCharInString(fileLine, ')', false) + 1
            char spectatorPortStr[32];
            subSTR(fileLine, spectatorPortStr, startIdx, endIdx)
            //PrintToServer("---------------%d %d %s", startIdx, endIdx, playerPortStr)
            spectatorPort = StringToInt(spectatorPortStr)
        }
    
        if (playerPort > 20000 && spectatorPort > 20000) {
            PrintToServer("Found ports: %d %d", playerPort, spectatorPort)
            break;
        }

    }
    CloseHandle(fileHandle); 
    return playerPort > 20000 && spectatorPort > 20000;
}


public sendPortsHttpRequest() {
    HTTPClient httpClient; 
    httpClient = new HTTPClient(httpServer);

    JSONObject data = new JSONObject();
    data.SetInt("matchId", matchId);
    data.SetInt("playerPort", playerPort);
    data.SetInt("spectatorPort", spectatorPort);
    //send data
    httpClient.Post("server_ready", data, HttpResponseCallback);

    // JSON objects and arrays must be deleted when you are done with them
    delete data; 
}
void HttpResponseCallback(HTTPResponse response, any value) {}

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

subSTR(char[] str, char[] result, inc, fin)
{
   // new String:result[16];
    new i = inc;
    while (i < fin)
    {
        StrCat(result, fin - inc, str[i]);
        i++;
    }
    //return result;
}