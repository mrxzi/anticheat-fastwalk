/* Anti Speed Hack Detection - Powerful Version
 * Detects players running abnormally fast (speed hack)
 * Uses OnPlayerUpdate for real-time detection
 * Automatically kicks players who exceed normal running speed
 * 
 * Created by: Jaden
 * Version: 1.0
 */

#if !defined FILTERSCRIPT

#if defined _rSpeedHackIncluded_
	#endinput
#endif

#define _rSpeedHackIncluded_

#include <a_samp>
#include <YSI\y_hooks>

// Maximum allowed speed on foot (in km/h)
// Normal walking speed: ~5 km/h
// Normal running speed: ~15-22 km/h (GTA normal, bisa sampai 22 km/h saat sprint maksimal)
// Fast walk hack: usually 40-50+ km/h
// Threshold diset SANGAT TINGGI agar lari normal tidak terdeteksi
#define MAX_ONFOOT_SPEED 42.0  // Hanya deteksi jika melebihi 42 km/h (lari normal max ~22 km/h, dengan toleransi tinggi)
#define EXTREME_SPEED 55.0      // Langsung kick jika > 55 km/h (pasti speed hack)

enum E_PLAYER_SPEED_INFO
{
	Float:lastPosX,
	Float:lastPosY,
	Float:lastPosZ,
	lastCheckTick,
	speedViolations,
	lastViolationTime,
	speedCheckTimer,
	lastJumpTime,
	wasJumping
};

static
	playerData[MAX_PLAYERS][E_PLAYER_SPEED_INFO];

#if defined SPH_OnPlayerUpdate
	forward SPH_OnPlayerUpdate(playerid);
#endif

#if defined SPH_OnPlayerConnect
	forward SPH_OnPlayerConnect(playerid);
#endif

#if defined SPH_OnPlayerDisconnect
	forward SPH_OnPlayerDisconnect(playerid, reason);
#endif

#if defined OnPlayerSpeedHack
	forward OnPlayerSpeedHack(playerid, Float:speed);
forward CheckPlayerSpeedTimer(playerid);
#endif

// Check if player is jumping or in air
static bool:IsPlayerInJumpState(playerid)
{
	new Float:vX, Float:vY, Float:vZ;
	GetPlayerVelocity(playerid, vX, vY, vZ);
	
	// Check if player is in air (velocity Z != 0 means moving up or down)
	// Gunakan threshold lebih kecil untuk deteksi lebih sensitif
	if(floatabs(vZ) > 0.005) // Player is moving vertically (jumping or falling)
	{
		playerData[playerid][lastJumpTime] = GetTickCount();
		playerData[playerid][wasJumping] = 1;
		return true;
	}
	
	// Check animation index for jump animations
	new animIndex = GetPlayerAnimationIndex(playerid);
	// Jump animations: 1195, 1196, 1197, 1198, 1231 (running jump), 1062 (jump), 1063 (jump land)
	if(animIndex == 1195 || animIndex == 1196 || animIndex == 1197 || animIndex == 1198 || animIndex == 1231 || animIndex == 1062 || animIndex == 1063)
	{
		playerData[playerid][lastJumpTime] = GetTickCount();
		playerData[playerid][wasJumping] = 1;
		return true;
	}
	
	// Check if player Z position is changing (comparing with last position)
	new Float:posX, Float:posY, Float:posZ;
	GetPlayerPos(playerid, posX, posY, posZ);
	
	// If Z position changed significantly (more than 0.05 meter), player is likely jumping/falling
	if(playerData[playerid][lastPosZ] != 0.0 && floatabs(posZ - playerData[playerid][lastPosZ]) > 0.05)
	{
		playerData[playerid][lastJumpTime] = GetTickCount();
		playerData[playerid][wasJumping] = 1;
		return true;
	}
	
	return false;
}

// Check if player recently jumped (within cooldown period)
static bool:PlayerRecentlyJumped(playerid)
{
	// Jika pernah lompat dalam 2.5 detik terakhir, anggap masih dalam efek lompat (diperpanjang untuk lebih toleran)
	if(playerData[playerid][wasJumping] && (GetTickCount() - playerData[playerid][lastJumpTime]) < 2500)
		return true;
	
	// Reset flag jika sudah lebih dari 2.5 detik
	if((GetTickCount() - playerData[playerid][lastJumpTime]) >= 2500)
		playerData[playerid][wasJumping] = 0;
	
	return false;
}

// Get player speed using velocity (same method as SlideBug)
static GetPlayerOnFootSpeed(playerid)
{
	new Float:ST[4];
	GetPlayerVelocity(playerid, ST[0], ST[1], ST[2]);
	ST[3] = floatsqroot(floatpower(floatabs(ST[0]), 2.0) + floatpower(floatabs(ST[1]), 2.0) + floatpower(floatabs(ST[2]), 2.0)) * 179.28625;
	return floatround(ST[3]);
}

// Get player speed using position calculation (backup method)
static Float:GetPlayerSpeedByPosition(playerid)
{
	new Float:posX, Float:posY, Float:posZ;
	GetPlayerPos(playerid, posX, posY, posZ);
	
	new currentTick = GetTickCount();
	
	// First check, store position
	if(playerData[playerid][lastCheckTick] == 0)
	{
		playerData[playerid][lastPosX] = posX;
		playerData[playerid][lastPosY] = posY;
		playerData[playerid][lastPosZ] = posZ;
		playerData[playerid][lastCheckTick] = currentTick;
		return 0.0;
	}
	
	// Calculate distance moved (in meters)
	new Float:distance = floatsqroot(
		floatpower(posX - playerData[playerid][lastPosX], 2.0) + 
		floatpower(posY - playerData[playerid][lastPosY], 2.0) + 
		floatpower(posZ - playerData[playerid][lastPosZ], 2.0)
	);
	
	// Calculate time difference (in milliseconds)
	new tickDiff = currentTick - playerData[playerid][lastCheckTick];
	if(tickDiff < 50) tickDiff = 50; // Minimum 50ms untuk menghindari false positive dari lag spike
	
	// Calculate speed: distance (meters) / time (seconds) * 3.6 = km/h
	new Float:speed = (distance / (float(tickDiff) / 1000.0)) * 3.6;
	
	// Update last position and time
	playerData[playerid][lastPosX] = posX;
	playerData[playerid][lastPosY] = posY;
	playerData[playerid][lastPosZ] = posZ;
	playerData[playerid][lastCheckTick] = currentTick;
	
	return speed;
}

hook OnPlayerUpdate(playerid)
{
	// Only check if player is on foot and spawned
	// NOTE: Admin juga akan terdeteksi dan di-kick jika menggunakan speed hack
	if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || !AccountData[playerid][pSpawned])
	{
		#if defined SPH_OnPlayerUpdate
			return SPH_OnPlayerUpdate(playerid);
		#else
			return 1;
		#endif
	}
	
	// Skip if player is in water, frozen, or in special states
	if(IsPlayerInWater(playerid) || AccountData[playerid][pFreeze])
	{
		#if defined SPH_OnPlayerUpdate
			return SPH_OnPlayerUpdate(playerid);
		#else
			return 1;
		#endif
	}
	
	// Skip if player is surfing a vehicle (being dragged)
	if(GetPlayerSurfingVehicleID(playerid) != INVALID_VEHICLE_ID)
	{
		#if defined SPH_OnPlayerUpdate
			return SPH_OnPlayerUpdate(playerid);
		#else
			return 1;
		#endif
	}
	
	// Skip if player is in an event
	if(IsPlayerInEvent(playerid))
	{
		#if defined SPH_OnPlayerUpdate
			return SPH_OnPlayerUpdate(playerid);
		#else
			return 1;
		#endif
	}
	
	// Use position-based detection as PRIMARY (more accurate for fast walk)
	new Float:playerSpeedFloat = GetPlayerSpeedByPosition(playerid);
	
	// Also check velocity method as backup
	new playerSpeed = GetPlayerOnFootSpeed(playerid);
	new Float:velocitySpeed = float(playerSpeed);
	
	// Use the higher value (more accurate detection)
	if(velocitySpeed > playerSpeedFloat)
	{
		playerSpeedFloat = velocitySpeed;
	}
	
	// Ignore jika speed terlalu rendah atau tidak valid (mungkin lag spike)
	if(playerSpeedFloat < 1.0)
	{
		#if defined SPH_OnPlayerUpdate
			return SPH_OnPlayerUpdate(playerid);
		#else
			return 1;
		#endif
	}
	
	// Check if player is jumping FIRST - skip speed check entirely if jumping
	new bool:isJumping = IsPlayerInJumpState(playerid);
	
	// Check if player recently jumped (cooldown period)
	new bool:recentlyJumped = PlayerRecentlyJumped(playerid);
	
	// Skip speed check jika player sedang lompat ATAU baru saja lompat (untuk menghindari false positive)
	if(isJumping || recentlyJumped)
	{
		#if defined SPH_OnPlayerUpdate
			return SPH_OnPlayerUpdate(playerid);
		#else
			return 1;
		#endif
	}
	
	// Adjust threshold (normal threshold karena sudah skip jika jumping)
	new Float:adjustedThreshold = MAX_ONFOOT_SPEED;
	new Float:adjustedExtreme = EXTREME_SPEED;
	
	// Check if speed exceeds maximum allowed (only if speed is valid dan cukup tinggi)
	// Hanya deteksi jika benar-benar melebihi threshold (tidak ada toleransi untuk lari normal)
	if(playerSpeedFloat > adjustedThreshold)
	{
		// Extreme speed hack - kick immediately (no warning)
		if(playerSpeedFloat > adjustedExtreme)
		{
			// Send notification to admins first
			SendAdminMessage(X11_RED, "[AntiCheat]:"YELLOW" %s(%d)"LIGHTGREY" telah ditendang dari server karena diduga menggunakan speed hack / fast walk"YELLOW" [Kecepatan: %.1f km/h]", ReturnName(playerid), playerid, playerSpeedFloat);
			
			format(Strcmd1, sizeof(Strcmd1), "{FFFFFF}Halo, {FF000E}%s\n\n{FFFFFF}Anda telah dikeluarkan karena diduga: {FF000E}Speed Hack / Fast Walk\n\n{FFFFFF}Kecepatan terdeteksi: {FF000E}%.1f km/h\n{FFFFFF}Kecepatan maksimal: {00FF00}%.1f km/h\n\n{FFFFFF}Catatan: Jika pelanggaran ini terus berlanjut, hukuman akan lebih berat. Jika ini adalah kesalahan\nsilakan hubungi Admin!", GetPlayerNameEx(playerid), playerSpeedFloat, MAX_ONFOOT_SPEED);
			ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "JADEN | ANTICHEAT", Strcmd1, "Oke", "");
			
			KickEx(playerid);
			
			#if defined SPH_OnPlayerUpdate
				return SPH_OnPlayerUpdate(playerid);
			#else
				return 1;
			#endif
		}
		
		// Moderate speed hack (42-55 km/h) - count violations
		// Beri banyak kesempatan untuk menghindari false positive dari lag
		playerData[playerid][speedViolations]++;
		playerData[playerid][lastViolationTime] = gettime();
		
		// Kick after 15 violations untuk moderate speed (sangat toleran)
		// Ini memastikan hanya speed hack yang konsisten yang terdeteksi
		// Lari normal tidak akan mencapai 15 violations berturut-turut
		if(playerData[playerid][speedViolations] >= 15)
		{
			// Send notification to admins first
			SendAdminMessage(X11_RED, "[AntiCheat]:"YELLOW" %s(%d)"LIGHTGREY" telah ditendang dari server karena diduga menggunakan speed hack / fast walk"YELLOW" [Kecepatan: %.1f km/h]", ReturnName(playerid), playerid, playerSpeedFloat);
			
			format(Strcmd1, sizeof(Strcmd1), "{FFFFFF}Halo, {FF000E}%s\n\n{FFFFFF}Anda telah dikeluarkan karena diduga: {FF000E}Speed Hack / Fast Walk\n\n{FFFFFF}Kecepatan terdeteksi: {FF000E}%.1f km/h\n{FFFFFF}Kecepatan maksimal: {00FF00}%.1f km/h\n\n{FFFFFF}Catatan: Jika pelanggaran ini terus berlanjut, hukuman akan lebih berat. Jika ini adalah kesalahan\nsilakan hubungi Admin!", GetPlayerNameEx(playerid), playerSpeedFloat, MAX_ONFOOT_SPEED);
			ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "JADEN | ANTICHEAT", Strcmd1, "Oke", "");
			
			KickEx(playerid);
			
			#if defined SPH_OnPlayerUpdate
				return SPH_OnPlayerUpdate(playerid);
			#else
				return 1;
			#endif
		}
	}
	else
	{
		// Reset violation count lebih agresif jika speed normal
		// Ini memastikan hanya speed hack yang konsisten yang terdeteksi
		// Reset lebih cepat agar lari normal tidak terakumulasi
		if(playerData[playerid][speedViolations] > 0)
		{
			// Kurangi violations lebih banyak jika speed normal (lebih agresif reset)
			playerData[playerid][speedViolations] -= 2; // Kurangi 2 per check jika speed normal
			if(playerData[playerid][speedViolations] < 0)
				playerData[playerid][speedViolations] = 0;
		}
	}
	
	#if defined SPH_OnPlayerUpdate
		return SPH_OnPlayerUpdate(playerid);
	#else
		return 1;
	#endif
}

public OnPlayerSpeedHack(playerid, Float:speed)
{
	// Send notification to admins first
	SendAdminMessage(X11_RED, "[AntiCheat]:"YELLOW" %s(%d)"LIGHTGREY" telah ditendang dari server karena diduga menggunakan speed hack / fast walk"YELLOW" [Kecepatan: %.1f km/h]", ReturnName(playerid), playerid, speed);
	
	format(Strcmd1, sizeof(Strcmd1), "{FFFFFF}Halo, {FF000E}%s\n\n{FFFFFF}Anda telah dikeluarkan karena diduga: {FF000E}Speed Hack / Fast Walk\n\n{FFFFFF}Kecepatan terdeteksi: {FF000E}%.1f km/h\n{FFFFFF}Kecepatan maksimal: {00FF00}%.1f km/h\n\n{FFFFFF}Catatan: Jika pelanggaran ini terus berlanjut, hukuman akan lebih berat. Jika ini adalah kesalahan\nsilakan hubungi Admin!", GetPlayerNameEx(playerid), speed, MAX_ONFOOT_SPEED);
	ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "JADEN | ANTICHEAT", Strcmd1, "Oke", "");
	
	KickEx(playerid);
	return 1;
}

// Timer-based check as backup (runs every 200ms)
public CheckPlayerSpeedTimer(playerid)
{
	if(!IsPlayerConnected(playerid))
		return 0;
	
	// Only check if player is on foot and spawned
	// NOTE: Admin juga akan terdeteksi dan di-kick jika menggunakan speed hack
	if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || !AccountData[playerid][pSpawned])
		return 1;
	
	// Skip if player is in water, frozen, or in special states
	if(IsPlayerInWater(playerid) || AccountData[playerid][pFreeze])
		return 1;
	
	// Skip if player is surfing a vehicle (being dragged)
	if(GetPlayerSurfingVehicleID(playerid) != INVALID_VEHICLE_ID)
		return 1;
	
	// Skip if player is in an event
	if(IsPlayerInEvent(playerid))
		return 1;
	
	// Use position-based detection
	new Float:playerSpeedFloat = GetPlayerSpeedByPosition(playerid);
	
	// Also check velocity method
	new playerSpeed = GetPlayerOnFootSpeed(playerid);
	new Float:velocitySpeed = float(playerSpeed);
	
	// Use the higher value
	if(velocitySpeed > playerSpeedFloat)
	{
		playerSpeedFloat = velocitySpeed;
	}
	
	// Ignore jika speed terlalu rendah atau tidak valid (mungkin lag spike)
	if(playerSpeedFloat < 1.0)
	{
		return 1;
	}
	
	// Check if player is jumping FIRST - skip speed check entirely if jumping
	new bool:isJumping = IsPlayerInJumpState(playerid);
	
	// Check if player recently jumped (cooldown period)
	new bool:recentlyJumped = PlayerRecentlyJumped(playerid);
	
	// Skip speed check jika player sedang lompat ATAU baru saja lompat (untuk menghindari false positive)
	if(isJumping || recentlyJumped)
	{
		return 1;
	}
	
	// Adjust threshold (normal threshold karena sudah skip jika jumping)
	new Float:adjustedThreshold = MAX_ONFOOT_SPEED;
	new Float:adjustedExtreme = EXTREME_SPEED;
	
	// Check if speed exceeds maximum allowed (hanya jika benar-benar melebihi threshold)
	if(playerSpeedFloat > adjustedThreshold)
	{
		// Extreme speed hack - kick immediately
		if(playerSpeedFloat > adjustedExtreme)
		{
			// Send notification to admins first
			SendAdminMessage(X11_RED, "[AntiCheat]:"YELLOW" %s(%d)"LIGHTGREY" telah ditendang dari server karena diduga menggunakan speed hack / fast walk"YELLOW" [Kecepatan: %.1f km/h]", ReturnName(playerid), playerid, playerSpeedFloat);
			
			format(Strcmd1, sizeof(Strcmd1), "{FFFFFF}Halo, {FF000E}%s\n\n{FFFFFF}Anda telah dikeluarkan karena diduga: {FF000E}Speed Hack / Fast Walk\n\n{FFFFFF}Kecepatan terdeteksi: {FF000E}%.1f km/h\n{FFFFFF}Kecepatan maksimal: {00FF00}%.1f km/h\n\n{FFFFFF}Catatan: Jika pelanggaran ini terus berlanjut, hukuman akan lebih berat. Jika ini adalah kesalahan\nsilakan hubungi Admin!", GetPlayerNameEx(playerid), playerSpeedFloat, MAX_ONFOOT_SPEED);
			ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "JADEN | ANTICHEAT", Strcmd1, "Oke", "");
			
			KickEx(playerid);
			return 1;
		}
		
		// Moderate speed hack (42-55 km/h) - count violations
		// Beri banyak kesempatan untuk menghindari false positive dari lag
		playerData[playerid][speedViolations]++;
		playerData[playerid][lastViolationTime] = gettime();
		
		// Kick after 15 violations untuk moderate speed (sangat toleran)
		// Ini memastikan hanya speed hack yang konsisten yang terdeteksi
		// Lari normal tidak akan mencapai 15 violations berturut-turut
		if(playerData[playerid][speedViolations] >= 15)
		{
			// Send notification to admins first
			SendAdminMessage(X11_RED, "[AntiCheat]:"YELLOW" %s(%d)"LIGHTGREY" telah ditendang dari server karena diduga menggunakan speed hack / fast walk"YELLOW" [Kecepatan: %.1f km/h]", ReturnName(playerid), playerid, playerSpeedFloat);
			
			format(Strcmd1, sizeof(Strcmd1), "{FFFFFF}Halo, {FF000E}%s\n\n{FFFFFF}Anda telah dikeluarkan karena diduga: {FF000E}Speed Hack / Fast Walk\n\n{FFFFFF}Kecepatan terdeteksi: {FF000E}%.1f km/h\n{FFFFFF}Kecepatan maksimal: {00FF00}%.1f km/h\n\n{FFFFFF}Catatan: Jika pelanggaran ini terus berlanjut, hukuman akan lebih berat. Jika ini adalah kesalahan\nsilakan hubungi Admin!", GetPlayerNameEx(playerid), playerSpeedFloat, MAX_ONFOOT_SPEED);
			ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "JADEN | ANTICHEAT", Strcmd1, "Oke", "");
			
			KickEx(playerid);
			return 1;
		}
	}
	else
	{
		// Reset violation count lebih agresif jika speed normal
		// Ini memastikan hanya speed hack yang konsisten yang terdeteksi
		// Reset lebih cepat agar lari normal tidak terakumulasi
		if(playerData[playerid][speedViolations] > 0)
		{
			// Kurangi violations lebih banyak jika speed normal (lebih agresif reset)
			playerData[playerid][speedViolations] -= 2; // Kurangi 2 per check jika speed normal
			if(playerData[playerid][speedViolations] < 0)
				playerData[playerid][speedViolations] = 0;
		}
	}
	
	return 1;
}

hook OnPlayerConnect(playerid)
{
	playerData[playerid][lastCheckTick] = 0;
	playerData[playerid][lastPosX] = 0.0;
	playerData[playerid][lastPosY] = 0.0;
	playerData[playerid][lastPosZ] = 0.0;
	playerData[playerid][speedViolations] = 0;
	playerData[playerid][lastViolationTime] = 0;
	playerData[playerid][lastJumpTime] = 0;
	playerData[playerid][wasJumping] = 0;
	// Start timer as backup (runs every 200ms)
	playerData[playerid][speedCheckTimer] = SetTimerEx("CheckPlayerSpeedTimer", 200, true, "i", playerid);
	
	#if defined SPH_OnPlayerConnect
		return SPH_OnPlayerConnect(playerid);
	#else
		return 1;
	#endif
}

hook OnPlayerDisconnect(playerid, reason)
{
	KillTimer(playerData[playerid][speedCheckTimer]);
	playerData[playerid][lastCheckTick] = 0;
	playerData[playerid][lastPosX] = 0.0;
	playerData[playerid][lastPosY] = 0.0;
	playerData[playerid][lastPosZ] = 0.0;
	playerData[playerid][speedViolations] = 0;
	playerData[playerid][lastViolationTime] = 0;
	playerData[playerid][lastJumpTime] = 0;
	playerData[playerid][wasJumping] = 0;
	
	#if defined SPH_OnPlayerDisconnect
		return SPH_OnPlayerDisconnect(playerid, reason);
	#else
		return 1;
	#endif
}

#if defined _ALS_OnPlayerUpdate
  #undef OnPlayerUpdate
#else
#define _ALS_OnPlayerUpdate
#endif

#if defined _ALS_OnPlayerConnect
  #undef OnPlayerConnect
#else
#define _ALS_OnPlayerConnect
#endif

#if defined _ALS_OnPlayerDisconnect
  #undef OnPlayerDisconnect
#else
#define _ALS_OnPlayerDisconnect
#endif

#define OnPlayerUpdate SPH_OnPlayerUpdate
#define OnPlayerConnect SPH_OnPlayerConnect
#define OnPlayerDisconnect SPH_OnPlayerDisconnect

#endif
