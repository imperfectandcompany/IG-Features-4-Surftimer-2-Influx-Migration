#include <colorvariables>

public Plugin myinfo =
{
		author = "Hymns For Disco",
		url = "imperfectgamers.org",
		name = "Imperfect Gamers Features",
		description = "VIP commands and titles, reports",
		version = "1.0"
};

ConVar g_hChatPrefix = null;
char g_szChatPrefix[256];

char g_sServerName[256];
ConVar g_hHostName = null;

#include "imperfectgamers/ig_vip.sp"
#include "imperfectgamers/ig_reports.sp"
#include "imperfectgamers/ig_records.sp"
#include "imperfectgamers/ig_pointcheck.sp"

#include "influx/simpleranks.inc"
#include "influx/core.inc"

public OnPluginStart()
{
	g_hHostName = FindConVar("hostname");
	HookConVarChange(g_hHostName, OnSettingChanged);
	GetConVarString(g_hHostName, g_sServerName, sizeof(g_sServerName));
	
	g_hChatPrefix = CreateConVar("ig_chat_prefix", "{lime}IG {default}|", "Determines the prefix used for chat messages", FCVAR_NOTIFY);
	HookConVarChange(g_hChatPrefix, OnSettingChanged);
	
	VIP_OnPluginStart();
	Reports_OnPluginStart();
	Records_OnPluginStart();
	PointCheck_OnPluginStart();
}

public OnMapStart()
{
	LoadTranslations("imperfectgamers.phrases");
	CreateTimer(1.0, TitleTimer, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	Reports_OnMapStart();
}

public OnClientPutInServer(client)
{
	VIP_OnClientPutInServer(client);
	Reports_OnClientPutInServer(client);
}

public void OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_hHostName)
	{
		GetConVarString(g_hHostName, g_sServerName, sizeof(g_sServerName));
	}
	else if (convar == g_hChatPrefix)
	{
		GetConVarString(g_hChatPrefix, g_szChatPrefix, sizeof(g_szChatPrefix));
	}
}

public Action OnClientSayCommand( int client, const char[] szCommand, const char[] szMsg )
{
	if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	char sText[1024];
	strcopy(sText, sizeof(sText), szMsg);

	StripQuotes(sText);
	TrimString(sText);

	// Functions that require the client to input something via the chat box
	if (g_iWaitingForResponse[client] > -1)
	{
			// Check if client is cancelling
			if (StrEqual(sText, "cancel"))
			{
					PrintToChat(client, "[ImperfectGamers] Report canceled");
					g_iWaitingForResponse[client] = -1;
					return Plugin_Handled;
			}

			// Check which function we're waiting for
			switch (g_iWaitingForResponse[client])
			{
					case 1:
					{
							// BugMsg
							SendBugReport(client, sText);
					}
					case 2:
					{
							// Calladmin
							CallAdmin(client, sText);
					}
			}

			g_iWaitingForResponse[client] = -1;
			return Plugin_Stop;
	}

	char szName[64];
	GetClientName(client, szName, 64);
	CRemoveColors(szName, 64);
	
	if (IsPlayerVip(client, true, false)) {
		SetTextColor(szName, g_iCustomColours[client][0], sizeof(szName));
		SetTextColor(sText, g_iCustomColours[client][1], sizeof(sText));
	}

	if (g_bDbCustomTitleInUse[client])
		CPrintToChatAll("{default}%s {gray}| {default}%s{gray}: {default}%s", g_szTitle[client], szName, sText);
	else
		CPrintToChatAll("{default}%s{gray}: {default}%s", szName, sText);
		
	return Plugin_Handled;
}

public Action TitleTimer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && !IsFakeClient(i))
			SetClanTag(i);
	}
	return Plugin_Continue;
}

void SetClanTag(int client)
{
	if (StrEqual(g_szTitlePlain[client], "")) {
		// If no custom tag, default to the influx rank title
		char szTag[128];
		Influx_GetClientSimpleRank(client, szTag, sizeof(szTag));
		Influx_RemoveChatColors(szTag, sizeof(szTag));
		CS_SetClientClanTag(client, szTag);
	}
	else {
		CS_SetClientClanTag(client, g_szTitlePlain[client]);
	}
}

bool IsValidClient(int client)
{
	if (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client))
		return true;
	return false;
}


public void RemoveColorsFromString(char[] ParseString, int size)
{
	ReplaceString(ParseString, size, "{default}", "", false);
	ReplaceString(ParseString, size, "{white}", "", false);
	ReplaceString(ParseString, size, "{darkred}", "", false);
	ReplaceString(ParseString, size, "{green}", "", false);
	ReplaceString(ParseString, size, "{lime}", "", false);
	ReplaceString(ParseString, size, "{blue}", "", false);
	ReplaceString(ParseString, size, "{lightgreen}", "", false);
	ReplaceString(ParseString, size, "{red}", "", false);
	ReplaceString(ParseString, size, "{grey}", "", false);
	ReplaceString(ParseString, size, "{gray}", "", false);
	ReplaceString(ParseString, size, "{yellow}", "", false);
	ReplaceString(ParseString, size, "{lightblue}", "", false);
	ReplaceString(ParseString, size, "{darkblue}", "", false);
	ReplaceString(ParseString, size, "{pink}", "", false);
	ReplaceString(ParseString, size, "{lightred}", "", false);
	ReplaceString(ParseString, size, "{purple}", "", false);
	ReplaceString(ParseString, size, "{darkgrey}", "", false);
	ReplaceString(ParseString, size, "{darkgray}", "", false);
	ReplaceString(ParseString, size, "{limegreen}", "", false);
	ReplaceString(ParseString, size, "{orange}", "", false);
	ReplaceString(ParseString, size, "{olive}", "", false);
}


#define WHITE 0x01
#define DARKRED 0x02
#define PURPLE 0x03
#define GREEN 0x04
#define LIGHTGREEN 0x05
#define LIMEGREEN 0x06
#define RED 0x07
#define GRAY 0x08
#define YELLOW 0x09
#define ORANGE 0x10
#define DARKGREY 0x0A
#define BLUE 0x0B
#define DARKBLUE 0x0C
#define LIGHTBLUE 0x0D
#define PINK 0x0E
#define LIGHTRED 0x0F
public void SetTextColor(char[] sText, int index, int size)
{
	switch (index)
	{
		case 0: // 1st Rank
			Format(sText, size, "%c%s", WHITE, sText);
		case 1:
			Format(sText, size, "%c%s", DARKRED, sText);
		case 2:
			Format(sText, size, "%c%s", GREEN, sText);
		case 3:
			Format(sText, size, "%c%s", LIMEGREEN, sText);
		case 4:
			Format(sText, size, "%c%s", BLUE, sText);
		case 5:
			Format(sText, size, "%c%s", LIGHTGREEN, sText);
		case 6:
			Format(sText, size, "%c%s", RED, sText);
		case 7:
			Format(sText, size, "%c%s", GRAY, sText);
		case 8:
			Format(sText, size, "%c%s", YELLOW, sText);
		case 9:
			Format(sText, size, "%c%s", LIGHTBLUE, sText);
		case 10:
			Format(sText, size, "%c%s", DARKBLUE, sText);
		case 11:
			Format(sText, size, "%c%s", PINK, sText);
		case 12:
			Format(sText, size, "%c%s", LIGHTRED, sText);
		case 13:
			Format(sText, size, "%c%s", PURPLE, sText);
		case 14:
			Format(sText, size, "%c%s", DARKGREY, sText);
		case 15:
			Format(sText, size, "%c%s", ORANGE, sText);
	}
}

public void Influx_OnClientIdRetrieved( int client, int uid, bool bNew )
{
    PointCheck_InitClient( client );
}
