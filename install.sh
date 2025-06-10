#!/usr/bin/env bash

###############################################
# Remember to forward 3 ports in your router. #
###############################################

menu() {
  RED="\e[31m"
  GREEN="\e[32m"
  YELLOW="\e[33m"
  ENDCOLOR="\e[0m"
  tput clear
  echo -e "\n${YELLOW}*** Main Menu ***${ENDCOLOR}"
  echo -e "${GREEN}1. Install server${ENDCOLOR}"
  echo -e "${RED}2. Remove server${ENDCOLOR}"
  echo "q. Quit"
  echo ""
  read -p "Enter 1, 2, or q: " choice
}

installer() {
# Check if pacman or apt are available and 
# update the system before installing anything.
# Install the proper 32-bit GCC for SteamCMD
if command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman -S"
    LIB32_GCC="lib32-gcc-libs"
    sudo pacman -Syu
elif command -v apt >/dev/null 2>&1; then
    PKG_MANAGER="apt install"
    LIB32_GCC="lib32gcc-s1"
    sudo apt update && sudo apt upgrade
else
    echo "Unsupported distro. Aborting."
    exit 1
fi

sudo $PKG_MANAGER "$LIB32_GCC" ufw curl bpytop iftop htop nano

# Enable the firewall, allow relevant ports then reload the firewall
sudo ufw enable
sudo ufw allow $GPort/udp
sudo ufw allow $QPort/udp
sudo ufw allow $RPort/tcp
sudo ufw reload

cd $HOME
mkdir server
cd $HOME/server

# Download & decompress SteamCMD
curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Append Sandstorm management aliases to ~/.bashrc
cat <<EOF >> $HOME/.bashrc

# Sandstorm Aliases
# Use these short commands to manage the game server from a terminal

# Stop the game server
alias stop="sudo systemctl stop insserver.service"

# Start the game server
alias start="sudo systemctl start insserver.service"

# Restart the game server (used to apply map/mod updates)
alias restart="stop && start"

# Edit the startup command (a systemd unit file) using the nano text editor
alias alter="sudo nano /etc/systemd/system/insserver.service"

# Use after changing the unit file with the alter command
alias reload="sudo systemctl daemon-reload"

# Update the game server to the latest version
alias update="bash $HOME/server/update.sh"

# View the startup command
alias icat="cat /etc/systemd/system/insserver.service"

# Watch the game's logfile in real time
alias itail="tail -f $HOME/server/sandstorm/Insurgency/Saved/Logs/Insurgency.log"
EOF

# Create update.sh so the update alias works
touch $HOME/server/update.sh
chmod +x $HOME/server/update.sh
cat <<EOF > $HOME/server/update.sh
#!/usr/bin/env bash

sudo systemctl stop insserver.service
$HOME/server/steamcmd.sh +force_install_dir $HOME/server/sandstorm +login anonymous +app_update 581330 validate +quit
sudo systemctl daemon-reload
sudo systemctl start insserver.service
EOF

# Our startup command begins with ExecStart= under [Service]
touch $HOME/insserver.service
cat <<EOF > $HOME/insserver.service
[Unit]
Description=Sandstorm Server
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=$USER
Group=$USER
ExecStart=$HOME/server/sandstorm/Insurgency/Binaries/Linux/InsurgencyServer-Linux-Shipping Farmhouse?Scenario=Scenario_Farmhouse_Checkpoint_Security -ModDownloadTravelTo=Farmhouse?Scenario=Scenario_Farmhouse_Checkpoint_Security -Port=$GPort -QueryPort=$QPort -GSLTToken=$gslt -GameStats -Mods -GameStatsToken=$GameToken -AdminList=Admins -MapCycle=MapCycle -NoEAC -hostname=$Host

[Install]
WantedBy=multi-user.target
EOF

sudo mv $HOME/insserver.service /etc/systemd/system

# Install server files into the sandstorm folder by running SteamCMD
bash $HOME/server/steamcmd.sh +force_install_dir $HOME/server/sandstorm +login anonymous +app_update 581330 validate +quit

# Run the game server process for 30s to create needed 
# files and folders, then stop the game server process
sudo systemctl daemon-reload
sudo systemctl enable insserver.service
sudo systemctl start insserver.service
echo -e "\nService creation started..."
echo -e "\nCreating and populating files (30s)...\n"
sleep 30
sudo systemctl stop insserver.service

# Create more needed files and folders that the process failed to make
mkdir -p $HOME/server/sandstorm/Insurgency/Config/Server
cd $HOME/server/sandstorm/Insurgency/Config/Server
touch Admins.txt Bans.json MapCycle.txt Mods.txt Motd.txt

mkdir -p $HOME/server/sandstorm/Insurgency/Saved/Config/LinuxServer/
cd $HOME/server/sandstorm/Insurgency/Saved/Config/LinuxServer/
touch Engine.ini Game.ini GameUserSettings.ini

# Populate Engine.ini (the last line is the server's configurable Tick Rate)
cat <<EOF > $HOME/server/sandstorm/Insurgency/Saved/Config/LinuxServer/Engine.ini
[Core.System]
Paths=../../../Engine/Content
Paths=%GAMEDIR%Content
Paths=../../../Insurgency/Plugins/Wwise/Content
Paths=../../../Engine/Plugins/FX/Niagara/Content
Paths=../../../Insurgency/Plugins/InsurgencyUnitTests/Content
Paths=../../../Engine/Plugins/Developer/TraceSourceFiltering/Content
Paths=../../../Insurgency/Plugins/StatsCollector/Content
Paths=../../../Insurgency/Plugins/NWI/SlackFeedback/Content
Paths=../../../Insurgency/Plugins/ExampleContent/Content
Paths=../../../Insurgency/Plugins/NWI/InsurgencyGameplayDebugger/Content
Paths=../../../Insurgency/Plugins/NWI_Infected/Content
Paths=../../../Engine/Plugins/Developer/AnimationSharing/Content
Paths=../../../Engine/Plugins/Editor/GeometryMode/Content
Paths=../../../Engine/Plugins/Experimental/ChaosClothEditor/Content
Paths=../../../Engine/Plugins/Experimental/GeometryProcessing/Content
Paths=../../../Engine/Plugins/Experimental/GeometryCollectionPlugin/Content
Paths=../../../Engine/Plugins/Experimental/ChaosSolverPlugin/Content
Paths=../../../Engine/Plugins/Experimental/ChaosNiagara/Content
Paths=../../../Engine/Plugins/MovieScene/MovieRenderPipeline/Content

[/Script/OnlineSubsystemUtils.IpNetDriver]
NetServerMaxTickRate=64
EOF

# Populate MapCycle.txt with checkpoint (co-op) maps
# Stock day & night maps included
cat <<EOF > $HOME/server/sandstorm/Insurgency/Config/Server/MapCycle.txt
(Scenario="Scenario_Crossing_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Farmhouse_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Hideout_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Ministry_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Outskirts_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Precinct_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Refinery_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Summit_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Tideway_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_PowerPlant_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Tell_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Bab_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Hillside_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Hillside_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Prison_Checkpoint_Security",Lighting="Day")
(Scenario="Scenario_Prison_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Crossing_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Farmhouse_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Hideout_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Ministry_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Outskirts_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Precinct_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Refinery_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Summit_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Tideway_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_PowerPlant_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Tell_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Bab_Checkpoint_Insurgents",Lighting="Day")
(Scenario="Scenario_Crossing_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Farmhouse_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Hideout_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Ministry_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Outskirts_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Precinct_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Refinery_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Summit_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Tideway_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_PowerPlant_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Tell_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Bab_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Hillside_Checkpoint_Security",Lighting="Night")
(Scenario="Scenario_Hillside_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Crossing_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Farmhouse_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Hideout_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Ministry_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Outskirts_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Precinct_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Refinery_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Summit_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Tideway_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_PowerPlant_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Tell_Checkpoint_Insurgents",Lighting="Night")
(Scenario="Scenario_Bab_Checkpoint_Insurgents",Lighting="Night")
EOF

# Populate Game.ini, setup for the checkpoint (co-op) game mode
cat <<EOF > $HOME/server/sandstorm/Insurgency/Saved/Config/LinuxServer/Game.ini
[Rcon]
bEnabled=True
Password=$Rpwd
ListenPort=$RPort
bAllowConsoleCommands=True

[/script/aimodule.aisenseconfig_sight]
AutoSuccessRangeFromLastSeenLocation=-1

[/Script/Engine.GameSession]
MaxPlayers=12

[/Script/Insurgency.TeamInfo]
bVotingEnabled=False

[/script/insurgency.insgamemode]
bKillFeed=True
bKillFeedSpectator=True
bKillerInfo=True
bKillerInfoRevealDistance=True
TeamKillLimit=3
bDeadSay=True
bDeadSayTeam=True
bVoiceAllowDeadChat=True
bVoiceEnemyHearsLocal=False
ObjectiveSpeedup=0.05
ObjectiveMaxSpeedupPlayers=10
bEnforceFriendlyFireReflect=False
bLoseSpawnProtectionOnMove=True
LoseSpawnProtectionOnMoveGrace=0.1
bDisableVehicles=False
bStartPlayersAsSpectators=True
DroppedWeaponLifespan=60

[/script/insurgency.insmultiplayermode]
GameStartingIntermissionTime=15
WinTime=5
PostRoundTime=10
PostGameTime=10
bAllowFriendlyFire=True
FriendlyFireModifier=0.5
bMapVoting=True
bUseMapCycle=False
bVoiceIntermissionAllowAll=True
IdleLimit=3600
IdleCheckFrequency=30
RoundLimit=1
WinLimit=1
PreRoundTime=5
InitialSupply=250
MaximumSupply=250
MinimumPlayers=1
bSupplyGainEnabled=False

[/script/insurgency.inscoopmode]
bUseVehicleInsertion=True
bRestrictClassByPlayerLevel=False
MaxPlayersToScaleEnemyCount=12
MinimumEnemies=8
MaximumEnemies=40
AIDifficulty=0.7
bBots=False

[/script/insurgency.inscheckpointgamemode]
DefendTimer=90
DefendTimerFinal=180
RetreatTimer=1
RespawnDPR=0.1
RespawnDelay=1
PostCaptureRushTimer=120
CounterAttackRespawnDPR=0.1
CounterAttackRespawnDelay=1
bCounterAttackReinforce=True
RoundTime=1800
EOF

cd $HOME

echo -e "\nRemember to execute 'source .bashrc' so the command aliases work."
echo -e "Install finished, but some files must be populated manually."
echo -e "See the bottom of the script for more info.\n"

exit 0
}

while true; do
  menu

  case "$choice" in
    1)
      echo "Get your GSLT from https://steamcommunity.com/dev/managegameservers"
      read -p "Paste your Steam GSLT: " gslt
      echo "Get your Game Token from https://gamestats.sandstorm.game/auth/login?ReturnUrl=%2F"
      read -p "Paste your Sandstorm Game Token: " GameToken
      read -p "State your Game Port: " GPort
      read -p "Now your Query Port: " QPort
      read -p "And your RCON Port: " RPort
      read -p "The RCON password: " Rpwd
      read -p "And lastly, the server's hostname: " Host
      installer
      ;;
    2)
      server_folder="$HOME/server/sandstorm"
      if [ -d "$server_folder" ]; then
        sudo systemctl stop insserver.service
        sudo systemctl disable insserver.service
        echo "Service stopped and disabled."
        echo "Found folder at: $server_folder"
        rm -rf "$server_folder" && echo "Folder deleted."
        rm $HOME/server/update.sh && echo "update.sh removed."
        sleep 3
      else
        echo "No server folder found at: $server_folder"
        sleep 3
      fi
      ;;
    q|Q)
      echo -e "~~~~ Goodbye ~~~~\n"
      break # Exit the while loop
      ;;
    *)
      echo "Invalid choice. Please try again."
      sleep 2
      ;;
  esac
done

exit 0

# See the official Server Admin Guide for important setup info:
# https://mod.io/g/insurgencysandstorm/r/server-admin-guide

# The game server is installed in $HOME/server/sandstorm
# Admins.txt is where you add server admins.
# Find it at $HOME/server/sandstorm/Insurgency/Config/Server
# Admins.txt needs one SteamID64 per line:
# 76523121973431725
# 76566798271142210
# Get SteamID64s from https://steamid.io/

# The provided Game.ini runs co-op, but you may want to change some values.
# See this comprehensive Game.ini example file for reference:
# https://github.com/zDestinate/INS_Sandstorm/blob/master/Insurgency/Saved/Config/WindowsServer/Game.ini
# Ensure that you stop the server before saving changes to Game.ini or Engine.ini!
# Stop the server before saving, or else your changes will be lost after a game server restart.

# Motd.txt allows you to set a "message of the day" 
# that will display to all players on each map change.
# The MOTD writes to the upper right quadrant of the screen.

# Mods.txt is for storing the Resource IDs of mods from mod.io.
# See https://mod.io/g/insurgencysandstorm?_sort=downloads for a mod list
# Mod and custom map entries take the form:
# 1234567; Mod/map name
# 3357788; WarGames map
# Where 1234567 is the Resource ID and anything 
# after the semicolon is a comment, and is ignored.

# Some mods require the use of a mutator, which goes in the startup 
# command (the line that begins with ExecStart) like so, with no spaces: 
# -Mutators=Mutator1,Mutator2,Mutator3
# Find mutators on their respective mod.io webpages.

# Run 'source .bashrc' before issuing the start command.

# Congrats! You now have a functioning 12-player checkpoint server.
# Use the 'start' command to fire up the server. Happy hunting!
