#include <sourcemod>
#include <system2>
#include <json>

#pragma semicolon 1
#pragma newdecls required

ConVar g_cServerIP;
ConVar g_cCommunityID;
ConVar g_cCommunityKey;

char g_sServerIP[64];
char g_sCommunityID[64];
char g_sCommunityKey[64];

bool g_bIsPWPlayer[MAXPLAYERS + 1] = false;

char g_sClientAuth[MAXPLAYERS + 1][66];

public Plugin myinfo =
{
	name = "Steam China Extended API",
	author = "AsukaXVB",
	description = "rewrite of official code and provides API to check player's stat, also auto generate config file",
	version = "0.1",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] sError, int err_max)
{
	CreateNative("CNST_CheckPlayer", 	Native_IsCNPlayer);

	RegPluginLibrary("CNST");

	return APLRes_Success;
}

public int Native_IsCNPlayer(Handle hPlugin, int iClient)
{
	return g_bIsPWPlayer[(iClient = GetNativeCell(1))];
}

public void OnPluginStart() 
{	
	g_cServerIP = CreateConVar("pw_serverIP", "Dummy_IP:27015", "Specify server address by IP or URL. e.g: AAA.BBB.CCC.DDD:27015", 0, false, 0.0, false, 0.0);
	g_cCommunityID = CreateConVar("pw_communityID", "Dummy_ID", "Specify community name. e.g: EXAMPLE Server", 0, false, 0.0, false, 0.0);
	g_cCommunityKey = CreateConVar("pw_communityKey", "Dummy_Key", "Specify community key provided.", 0, false, 0.0, false, 0.0);
	
	g_cServerIP.AddChangeHook(OnServerIPChanged);
	g_cCommunityID.AddChangeHook(OnCommunityIDChanged);
	g_cCommunityKey.AddChangeHook(OnCommunityKeyChanged);
	
	AutoExecConfig(true, "steam_china");
}

public void OnConfigsExecuted()
{
	g_cServerIP.GetString(g_sServerIP, sizeof(g_sServerIP));
	g_cCommunityID.GetString(g_sCommunityID, sizeof(g_sCommunityID));
	g_cCommunityKey.GetString(g_sCommunityKey, sizeof(g_sCommunityKey));
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsValiedClient(client, true))
		return;
		
	char url[256];
	GetClientAuthId(client, AuthId_SteamID64, g_sClientAuth[client], 128);
		
	Format(url, sizeof(url), "https://csgo.wanmei.com/api-user/isOnline?steamIds=%s", g_sClientAuth[client]);
	
	System2HTTPRequest httpRequest = new System2HTTPRequest(CNSTCallback, url);
	httpRequest.Timeout = 15;
	httpRequest.Any = client;
	httpRequest.SetHeader("Content-Type", "application/json;charset=utf-8");

	httpRequest.GET();
	delete httpRequest;
}

void CNSTCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) 
{
	char url[256];
	request.GetURL(url, sizeof(url));
	if (!success) {
		PrintToServer("ERROR: Couldn't retrieve URL %s. Error: %s", url, error);
		PrintToServer("");
		PrintToServer("INFO: Finished");
		PrintToServer("");
		
		return;
	}
	
	int client = request.Any;
	
	char content[128];
	for (int found = 0; found < response.ContentLength;) 
	{
		found += response.GetContent(content, sizeof(content), found);
		JSON_Object obj = json_decode(content);
		
		char stats[32];
		obj.GetString("status", stats, sizeof(stats));
		if(StrContains(stats, "fail", false) != -1)
		{
			char apiError[64];
			obj.GetString("error", apiError, sizeof(apiError));
			LogMessage("Error on requesting API: %s", apiError);
		}
		else if(StrContains(stats, "success", false) != -1)
		{
			char isOnline[16];
			JSON_Object result = obj.GetObject("result");
			result.GetString(g_sClientAuth[client], isOnline, sizeof(isOnline));
			if(StrEqual(isOnline, "online", true))
				g_bIsPWPlayer[client] = true;
			else
				g_bIsPWPlayer[client] = false;
				
			CallOnConnected(client);
				
			delete result;
		}
		
		delete obj;
	}
}

void CallOnConnected(int client)
{
	if(!IsValiedClient(client, true))
		return;
		
	char guofu[12];
	if(g_bIsPWPlayer[client])
		strcopy(guofu, 9, "true");
	else
		strcopy(guofu, 9, "false");
		
	int timestamp = GetTime();
	char buffer[256], output[256], steamid2[64];
	//API requests for STEAM 2 ID here
	GetClientAuthId(client, AuthId_Steam2, steamid2, sizeof(steamid2), true);
	
	Format(buffer, sizeof(buffer), "{\"timestamp\":\"%i\", \"communityId\":\"%s\",  \"serverip\":\"%s\", \"type\":\"logingame\",  \"steamId\":\"%s\", \"guofu\":\"%s\"}", timestamp, g_sCommunityID, g_sServerIP, steamid2, guofu);
	LogMessage("Player connected data sent: %s", buffer);
	//Building request data
	JSON_Array arr = new JSON_Array();
	JSON_Object obj_topic = new JSON_Object();
	JSON_Object obj_client = new JSON_Object();
	
	obj_topic.SetString("topic", "log_csgo_3rdparty");
	obj_client.SetObject("headers", obj_topic);
	obj_client.SetString("body", buffer);
	
	arr.PushObject(obj_client);
	arr.Encode(output, sizeof(output));
	//Send it
	System2HTTPRequest httpRequest = new System2HTTPRequest(CNSTLogCallback, "https://log.pwesports.cn/csgo?key=%s", g_sCommunityKey);
	httpRequest.Timeout = 10;
	httpRequest.SetHeader("Content-Type", "application/json;charset=utf-8");
	httpRequest.SetData(output);
	httpRequest.POST();
	//Cleaning
	delete arr;
	delete obj_topic;
	delete obj_client;
	delete httpRequest;
}

public void OnClientDisconnect(int client)
{
	if(!IsValiedClient(client, true))
		return;
		
	char guofu[12];
	if(g_bIsPWPlayer[client])
		strcopy(guofu, 9, "true");
	else
		strcopy(guofu, 9, "false");
		
	int timestamp = GetTime();
	char buffer[256], output[256], steamid2[64];
	//API requests for STEAM 2 ID here
	GetClientAuthId(client, AuthId_Steam2, steamid2, sizeof(steamid2), true);
	
	Format(buffer, sizeof(buffer), "{\"timestamp\":\"%i\", \"communityId\":\"%s\",  \"serverip\":\"%s\", \"type\":\"logout\",  \"steamId\":\"%s\", \"guofu\":\"%s\"}", timestamp, g_sCommunityID, g_sServerIP, steamid2, guofu);
	LogMessage("Player disconnected data sent: %s", buffer);
	//Building request data
	JSON_Array arr = new JSON_Array();
	JSON_Object obj_topic = new JSON_Object();
	JSON_Object obj_client = new JSON_Object();
	
	obj_topic.SetString("topic", "log_csgo_3rdparty");
	obj_client.SetObject("headers", obj_topic);
	obj_client.SetString("body", buffer);
	
	arr.PushObject(obj_client);
	arr.Encode(output, sizeof(output));
	//Send it
	System2HTTPRequest httpRequest = new System2HTTPRequest(CNSTLogCallback, "https://log.pwesports.cn/csgo?key=%s", g_sCommunityKey);
	httpRequest.Timeout = 10;
	httpRequest.SetHeader("Content-Type", "application/json;charset=utf-8");
	httpRequest.SetData(output);
	httpRequest.POST();
	//Cleaning
	delete arr;
	delete obj_topic;
	delete obj_client;
	delete httpRequest;
}

void CNSTLogCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) 
{
	char url[256];
	request.GetURL(url, sizeof(url));
	if (!success) {
		PrintToServer("ERROR: Couldn't retrieve URL %s. Error: %s", url, error);
		PrintToServer("");
		PrintToServer("INFO: Finished");
		PrintToServer("");
		
		return;
	}
}

void OnServerIPChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sServerIP, sizeof(g_sServerIP));
	return;
}

void OnCommunityIDChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sCommunityID, sizeof(g_sCommunityID));
	return;
}

void OnCommunityKeyChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sCommunityKey, sizeof(g_sCommunityKey));
	return;
}

bool IsValiedClient(int client, bool nobot)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobot && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}
