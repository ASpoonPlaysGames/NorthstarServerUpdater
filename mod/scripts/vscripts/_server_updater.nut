global function ServerUpdateChecker_Init

struct {
	bool hasFoundUpdate = false
	float updateFoundTime = -1
	bool isShuttingDown = false
} file

// amount of time to wait before reading the file again
const float READ_FILE_DELAY = 60
const string UPDATE_FILE = "update.txt"
const int MAX_UPDATE_DELAY_MINS = 10
const int DISCONNECT_WARNING_DELAY_MINS = 1

void function ServerUpdateChecker_Init()
{
	// wait for file write
	thread WaitForFileWrite()

	AddCallback_OnClientDisconnected( OnClientDisconnected )
	AddCallback_GameStateEnter( eGameState.Postmatch, OnMatchEnd )
}

void function WaitForFileWrite()
{
	while ( !file.hasFoundUpdate )
	{
		// if the file doesn't exist, then just assume there is no update
		if ( NSDoesFileExist( UPDATE_FILE ) )
			NSLoadFile( UPDATE_FILE, OnFileReadSuccess, OnFileReadFailure )
		else
			printt( "update file could not be found" )
		
		wait READ_FILE_DELAY
	}
}

void function OnFileReadSuccess( string contents )
{
	if ( contents.len() && contents[0] != '0' )
	{
		// we have found an update
		file.hasFoundUpdate = true
		// start the doomsday clock
		thread WaitForTime()
		thread WarnPlayersAboutUpdate_Threaded()
		OnClientDisconnected( null ) // bit hacky but it forces the "client disconnected" check
	}
}

void function OnFileReadFailure()
{
	printt( "Updater failed to read file?", UPDATE_FILE )
}

void function WaitForTime()
{
	wait MAX_UPDATE_DELAY_MINS * 60
	DisconnectAllPlayersAndShutdownServer_Threaded()
}

void function OnClientDisconnected( entity player )
{
	if ( !file.hasFoundUpdate )
		return
	
	bool hasHumanPlayer = false
	foreach( serverPlayer in GetPlayerArray() )
	{
		if ( serverPlayer.IsBot() )
			continue

		if ( serverPlayer == player )
			continue

		hasHumanPlayer = true
		break
	}

	if ( !hasHumanPlayer )
		thread DisconnectAllPlayersAndShutdownServer_Threaded()
}

void function OnMatchEnd()
{
	if ( !file.hasFoundUpdate )
		return

	thread DisconnectAllPlayersAndShutdownServer_Threaded()
}

// just put something in chat every minute or so, let them know what is happening
void function WarnPlayersAboutUpdate_Threaded()
{
	int minsRemaining = MAX_UPDATE_DELAY_MINS
	while ( file.hasFoundUpdate )
	{
		Chat_ServerBroadcast( format( "Server will update in \x1b[93m%i minutes\x1b[110m or after the current match ends.", minsRemaining ) )
		wait DISCONNECT_WARNING_DELAY_MINS * 60
		minsRemaining -= DISCONNECT_WARNING_DELAY_MINS
	}
}

void function DisconnectAllPlayersAndShutdownServer_Threaded()
{
	// better to not have this run more than once at a time
	if ( file.isShuttingDown )
		return
	file.isShuttingDown = true

	// disconnect all players with a nice error message
	foreach ( player in GetPlayerArray() )
		NSDisconnectPlayer( player, "Server has shut down for an update" )
	// wait a frame
	WaitFrame()
	// close the server
	ServerCommand( "quit" )
}





