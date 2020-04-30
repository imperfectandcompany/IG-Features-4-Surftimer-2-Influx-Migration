#include <influx/core>
#include <discord>

ConVar g_hRecordAnnounceDiscord = null;

void Records_OnPluginStart() {
	g_hRecordAnnounceDiscord = CreateConVar("ig_records_webhook_announce", "", "Web hook link to announce records in discord, keep empty to disable");
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
	// code taken from influx_recchat
	
		bool isbest = ( flags & RES_TIME_ISBEST ) ? true : false;
		
		if (!isbest)
		{
			// Only send a webhook message for new best times
			return;
		}
		
		// Format our second formatting string.
		decl String:szFormSec[10];
		Inf_DecimalFormat( 2, szFormSec, sizeof( szFormSec ) );
		
		
		decl String:szName[MAX_NAME_LENGTH];
		decl String:szForm[10];
		decl String:szRun[MAX_RUN_NAME];
		decl String:szMode[64];
		decl String:szStyle[64];
		decl String:szRec[64];
		
		if ( prev_best != INVALID_RUN_TIME )
		{
				int c;
				
				Inf_FormatSeconds( Inf_GetTimeDif( time, prev_best, c ), szForm, sizeof( szForm ), szFormSec );
				
				FormatEx( szRec, sizeof( szRec ), " {CHATCLR}({%s}%c%s{CHATCLR})",
						isbest ? "GREEN" : "LIGHTRED", // Is new best?
						c,
						szForm );
		}
		else
		{
				szRec[0] = '\0';
		}
		
		if ( time < prev_pb )
		{
				// Display more decimals if time is smaller than our formatting.
				decl String:sec[12];
				
				float dif = prev_pb - time;
				
				
				FormatEx( sec, sizeof( sec ), ( dif < 0.1 ) ? "%.3f" : "%.1f", dif );
		}
		
		Inf_FormatSeconds( time, szForm, sizeof( szForm ), szFormSec );
		
		if ( Influx_ShouldModeDisplay( mode ) )
		{
				Influx_GetModeShortName( mode, szMode, sizeof( szMode ) );
		}
		else
		{
				szMode[0] = '\0';
		}
		
		
		if ( Influx_ShouldStyleDisplay( style ) )
		{
				Influx_GetStyleShortName( style, szStyle, sizeof( szStyle ) );
		}
		else
		{
				szStyle[0] = '\0';
		}
		
		
		Influx_GetRunName( runid, szRun, sizeof( szRun ) );
		
		GetClientName( client, szName, sizeof( szName ) );
		Influx_RemoveChatColors( szName, sizeof( szName ) );
		
		char webhook[1024];
		GetConVarString(g_hRecordAnnounceDiscord, webhook, 1024);
		if (StrEqual(webhook, "")) {
			return;
		}
			
		// Send Discord Announcement
		DiscordWebHook hook = new DiscordWebHook(webhook);
		hook.SlackMode = true;
	
		hook.SetUsername("SurfTimer Records");
	
		MessageEmbed Embed = new MessageEmbed();
	
		// Get a random colour for the.. left colour
		int hex = GetRandomInt(0, 6);
		switch (hex)
		{
			case 0: Embed.SetColor("#ff0000");
			case 1: Embed.SetColor("#ff7F00");
			case 2: Embed.SetColor("#ffD700");
			case 3: Embed.SetColor("#00aa00");
			case 4: Embed.SetColor("#0000ff");
			case 5: Embed.SetColor("#6600ff");
			case 6: Embed.SetColor("#8b00ff");
			default: Embed.SetColor("#ff0000");
		}
	
		Embed.SetTitle("**NEW MAP RECORD**");
	
		// Format The Message
		char szMessage[512];
		
		char szMapName[64];
		GetCurrentMap(szMapName, sizeof(szMapName));
	
		Format(szMessage, sizeof(szMessage),
		"%s has beaten the %s %s record  in the %s server with a time of %s",
		szName, szMapName, szRun, g_sServerName, szForm);
	
		// Get A Random Emoji
		int emoji = GetRandomInt(0, 3);
		char szEmoji[128];
		switch (emoji)
		{
			case 0: Format(szEmoji, sizeof(szEmoji), ":ok_hand: :ok_hand: :ok_hand: :ok_hand: :ok_hand:");
			case 1: Format(szEmoji, sizeof(szEmoji), ":thinking: :thinking: :thinking: :thinking: :thinking:");
			case 2: Format(szEmoji, sizeof(szEmoji), ":fire: :fire: :fire: :fire: :fire:");
			case 3: Format(szEmoji, sizeof(szEmoji), ":scream: :scream: :scream: :scream: :scream:");
			default: Format(szEmoji, sizeof(szEmoji), ":ok_hand: :ok_hand: :ok_hand: :ok_hand: :ok_hand:");
		}
	
		Embed.AddField(szEmoji, szMessage, false);
	
		hook.Embed(Embed);
		hook.Send();
		delete hook;
}
