#############################################################################
##-->						TCL ReplicaServ Service						<--##
#---------------------------------------------------------------------------#
## Auteur	: MalaGaM
## Website	: https://github.com/MalaGaM/TCL-ReplicaServ-Service
## Support	: https://github.com/MalaGaM/TCL-ReplicaServ-Service/issues
##
## Greet	:
##		-> DJ-Philo,Averell & NiCkOoS pour versions tclsh 'Les poupées linkeuses'
##		-> pchevee de www.eggdrop.fr pour la demande de mise à jour
##		-> MenzAgitat de www.eggdrop.fr pour ses astuces/conseils
##		-> CrazyCat de www.eggdrop.fr pour sa communauté eggdrop français
#############################################################################
if { [catch { package require IRCServices 0.0.4 }] } { putloglev o * "\00304\[ReplicaServ - erreur\]\003 ReplicaServ nécessite le package IRCServices 0.0.1 (ou plus) pour fonctionner, Télécharger sur 'https://github.com/MalaGaM/TCL-PKG-IRCServices'. Le chargement du script a été annulé." ; die }
if { [catch { package require IRCC 0.0.1 }] } { putloglev o * "\00304\[ReplicaServ - erreur\]\003 ReplicaServ nécessite le package IRCC 0.0.1 (ou plus) pour fonctionner, Télécharger sur 'https://github.com/MalaGaM/TCL-PKG-IRCC'. Le chargement du script a été annulé." ; die }
if {[info commands ::ReplicaServ::uninstall] eq "::ReplicaServ::uninstall" } { ::ReplicaServ::uninstall }
namespace eval ReplicaServ {
	variable config
	variable SERVICEBOT_PIPELINE	""
	variable SERVICE_PIPELINE		""
	variable IRCC_DATA
	array set IRCC_DATA				{}	

	set config(scriptname)		"ReplicaServ Service"
	set config(version)			"1.1.20210327"
	set config(auteur)			"MalaGaM"

	set config(init)			0

	set config(path_script)		[file dirname [info script]];

	set config(db_list)			[list	\
				"link.db"				\
				"network.db"
	];

	set config(vars_list)		[list	\
					"uplink_host"		\
					"uplink_ssl"		\
					"uplink_port"		\
					"uplink_password"	\
					"serverinfo_name"	\
					"serverinfo_descr"	\
					"serverinfo_id"		\
					"uplink_useprivmsg"	\
					"uplink_debug"		\
					"service_nick"		\
					"service_user"		\
					"service_host"		\
					"service_gecos"		\
					"service_modes"		\
					"service_channel"	\
					"service_chanmodes"	\
					"service_usermodes"	\
					"admin_password"	\
					"admin_console"		\
					"scriptname"		\
					"version"			\
					"auteur"
	];
	proc uninstall {args} {
		variable config

		putlog "Désallocation des ressources de \002[set config(scriptname)]\002..."

		foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " \{?(::)?$ns"] {
			unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]
		}
		# Arrêt des timers en cours.
		foreach running_timer [timers] {
			if { [::tcl::string::match "*[namespace current]::*" [lindex $running_timer 1]] } { killtimer [lindex $running_timer 2] }
		}
		
		if { [info exists config(idx)] } { 
			close $config(idx)
		}
		namespace delete ::ReplicaServ
	}
}
proc ::ReplicaServ::INIT { } {
	variable config
	variable database
	#######################
	# ReplicaServ Fichier #
	#######################
	if { ![file isdirectory "[::ReplicaServ::Get:ScriptDir "db"]"] } { file mkdir "[::ReplicaServ::Get:ScriptDir "db"]" }
	::ReplicaServ::DB:INIT $config(db_list)

	######################
	# ReplicaServ Source #
	######################
	if { [file exists [::ReplicaServ::Get:ScriptDir]ReplicaServ.conf] } {
		source [::ReplicaServ::Get:ScriptDir]ReplicaServ.conf
		::ReplicaServ::Check:Config
	} else {
		if { [file exists [::ReplicaServ::Get:ScriptDir]ReplicaServ.Example.conf] } {
			putlog "Editez, configurer et renomer 'ReplicaServ.Example.conf' en 'ReplicaServ.conf' dans '[::ReplicaServ::Get:ScriptDir]'"
			exit "ReplicaServ quit"
		} else {
			putlog "Fichier de configuration '[::ReplicaServ::Get:ScriptDir]ReplicaServ.conf' manquant."
			exit "ReplicaServ quit"
		}
	}

	::ReplicaServ::INIT:SERVICE

	set config(putlog) "[set config(scriptname)] v[set config(version)] par [set config(auteur)]"
}
proc ::ReplicaServ::INIT:SERVICE {} {
	variable config
	variable SERVICE_PIPELINE

	#############################
	# ReplicaServ Services init #
	#############################
	if { $config(uplink_ssl)	== 1	} { set config(uplink_port) "+$config(uplink_port)" }
	if { $config(serverinfo_id)	!= ""	} { set config(uplink_ts6) 1 } else { set config(uplink_ts6) 0 }
	
	set SERVICE_PIPELINE	[::IRCServices::connection]; # Creer une instance services
	$SERVICE_PIPELINE connect $config(uplink_host) $config(uplink_port) $config(uplink_password) $config(uplink_ts6) $config(serverinfo_name) $config(serverinfo_id); # Connexion de l'instance service

	if { $config(uplink_debug) == 1} { $SERVICE_PIPELINE config logger 1; $SERVICE_PIPELINE config debug 1; }
	::ReplicaServ::INIT:BOTSERVICE

}
proc ::ReplicaServ::INIT:BOTSERVICE {} {
	variable config
	variable SERVICE_PIPELINE
	variable SERVICEBOT_PIPELINE
	
	set SERVICEBOT_PIPELINE		[$SERVICE_PIPELINE bot]; #Creer une instance bot dans linstance services
	
	$SERVICEBOT_PIPELINE create $config(service_nick) $config(service_user) $config(service_host) $config(service_gecos) $config(service_modes); # Creation d'un bot service

	
	if { $config(service_channel) != "" } { 
		$SERVICEBOT_PIPELINE join $config(service_channel)
		$SERVICEBOT_PIPELINE mode $config(service_channel) $config(service_chanmodes)
		if { $config(service_usermodes) != "" } { 
			$SERVICEBOT_PIPELINE mode $config(service_channel) $config(service_usermodes) $config(service_nick)
		}
	}
	

	$SERVICEBOT_PIPELINE registerevent SERVER {
		variable config
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Initialisation ...."
		# set fichier(salon) "[::ReplicaServ::Get:ScriptDir "db"]/channel_local.db"
		# set fp [open $fichier(salon) "r"]
		# set fc -1
		# while {![eof $fp]} {
		# 	set CHAN [gets $fp]
		# 	incr fc
		# 	if {$CHAN !=""} {
		# 		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Join le salon local $CHAN"
		# 		[bid] join $CHAN
		# 		if { $config(service_usermodes) != "" } { 
		# 			[sid] mode $CHAN $config(service_usermodes) $config(service_nick)
		# 		}
		# 	}
		# 	unset CHAN
		# }
		# close $fp

		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Chargement des réseaux IRC..."
		set fichier(network) "[::ReplicaServ::Get:ScriptDir "db"]/network.db"
		set fp [open $fichier(network) "r"]
		set fc -1
		while {![eof $fp]} {
			set data [gets $fp]
			incr fc
			if {$data !=""} {
				set IRC_NAME		[lindex $data 0]
				set IRC_NICKNAME	[lindex $data 1]
				set IRC_USERNAME	[lindex $data 2]
				set network_data	[split [lindex $data 3] :]

				set IRC_HOST		[lindex $network_data 0]
				set IRC_PORT		[lindex $network_data 1]
				set IRC_PASSWORD	[lindex $network_data 2]
				::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Chargement du réseau IRC $IRC_NAME ..."
				::ReplicaServ::IRC:Connexion $IRC_NAME $IRC_HOST $IRC_PORT $IRC_PASSWORD $IRC_NICKNAME $IRC_USERNAME
			}
			unset data
		}
		close $fp
		
	}
	$SERVICEBOT_PIPELINE registerevent PRIVMSG {
		set cmd		[string tolower [lindex [msg] 0]]
		set data	[lrange [msg] 1 end]
		##########################
		#--> Commandes Privés <--#
		##########################
		# si [target] ne commence pas par # c'est un pseudo
		if { [string index [target] 0] != "#"} {
			if { $cmd == "help"		}	{ 
				# [21:49:04] Received: :001119S0G PRIVMSG 00CAAAAAB :part
				::ReplicaServ::IRC:CMD:PRIV:HELP [who2] [target] $cmd $data
			} elseif { $cmd == "network"	}	{
				::ReplicaServ::IRC:CMD:PRIV:NETWORK [who2] [target] $cmd $data
			} elseif { $cmd == "link"		}	{
				::ReplicaServ::IRC:CMD:PRIV:LINK [who2] [target] $cmd $data
			} else {
				::ReplicaServ::IRC:CMD:PRIV:HELP [who2] [target] $cmd $data
			}
		}
		##########################
		#--> Commandes Salons <--#
		##########################
		# si [target] commence par # c'est un salon
		if { [string index [target] 0] == "#"} {
			if { $cmd == "!help"	}	{
				# Received: :MalaGaM PRIVMSG #Eva :!help
				::ReplicaServ::IRC:CMD:PUB:HELP [who] [target] $cmd $data
			}
		}
	}; # Creer un event sur PRIVMSG
	
}

#########################
# ReplicaServ fonctions #
#########################
proc ::ReplicaServ::Get:ScriptDir { {DIR ""} } {
	variable config
	return "[file normalize $config(path_script)/$DIR]/"
}

proc ::ReplicaServ::Check:Config { } {
	variable config
	foreach CONF $config(vars_list) {
		if { ![info exists config($CONF)] } {
			putlog "\[ Erreur \] Configuration de ReplicaServ Service Incorrecte... '$CONF' Paramettre manquant"
			exit "ReplicaServ quit"
		}
		if { $config($CONF) == "" &&  $CONF != "serverinfo_id"} {
			putlog "\[ Erreur \] Configuration de ReplicaServ Service Incorrecte... '$CONF' Valeur vide"
			exit "ReplicaServ quit"
		}
	}
}

proc ::ReplicaServ::JOIN { CHANNEL } {
	variable SERVICEBOT_PIPELINE
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Je join le salon $CHANNEL"
	$SERVICEBOT_PIPELINE	join $CHANNEL
}
proc ::ReplicaServ::IRC:JOIN { IRC_NAME CHANNEL } {
	variable IRCC_DATA
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Je join le salon $CHANNEL sur le réseau $IRC_NAME"
	$IRCC_DATA($IRC_NAME,PIPELINE) join $CHANNEL
}
proc ::ReplicaServ::SENT:NOTICE { DEST MSG } {
	variable SERVICEBOT_PIPELINE
	$SERVICEBOT_PIPELINE	notice $DEST [::ReplicaServ::apply_visuals $MSG]
}

proc ::ReplicaServ::SENT:PRIVMSG { DEST MSG } {
	variable SERVICEBOT_PIPELINE
	$SERVICEBOT_PIPELINE	privmsg $DEST [::ReplicaServ::apply_visuals $MSG]
}
proc ::ReplicaServ::VPRIVMSG { IRC_NAME IRC_CHANNEL IRC_USER IRC_MSG } {
	variable SERVICEBOT_PIPELINE
	variable SERVICE_PIPELINE
	set FILE(LINK)		"[::ReplicaServ::Get:ScriptDir "db"]/link.db"
	set FILE_PIPE		[open $FILE(LINK) "r"]
	set CHANNEL_LOCAL	""
	set fc	-1
	while { ![eof $FILE_PIPE] } {
		set FILE_LINE	[gets $FILE_PIPE]
		incr fc
		if { $FILE_LINE != "" } {
			if { [string match -nocase "$IRC_NAME * $IRC_CHANNEL" $FILE_LINE] } {
				set CHANNEL_LOCAL [lindex $FILE_LINE 1];
				break;
			}
		}
		unset FILE_LINE
	}
	close $FILE_PIPE
	unset FILE_PIPE
	set USER_UID	[[string map [list "::network" ""] ${SERVICE_PIPELINE}]::UID_GET $IRC_USER]
	$SERVICEBOT_PIPELINE	 send ":$USER_UID PRIVMSG $CHANNEL_LOCAL :$IRC_MSG"
}
proc ::ReplicaServ::VNOTICE { IRC_NAME IRC_CHANNEL IRC_USER IRC_MSG } {
	variable SERVICEBOT_PIPELINE
	variable SERVICE_PIPELINE
	set FILE(LINK)		"[::ReplicaServ::Get:ScriptDir "db"]/link.db"
	set FILE_PIPE		[open $FILE(LINK) "r"]
	set CHANNEL_LOCAL	""
	set fc	-1
	while { ![eof $FILE_PIPE] } {
		set FILE_LINE	[gets $FILE_PIPE]
		incr fc
		if { $FILE_LINE != "" } {
			if { [string match -nocase "$IRC_NAME * $IRC_CHANNEL" $FILE_LINE] } {
				set CHANNEL_LOCAL [lindex $FILE_LINE 1];
				break;
			}
		}
		unset FILE_LINE
	}
	close $FILE_PIPE
	unset FILE_PIPE
	set USER_UID	[[string map [list "::network" ""] ${SERVICE_PIPELINE}]::UID_GET $IRC_USER]
	$SERVICEBOT_PIPELINE	 send ":$USER_UID NOTICE $CHANNEL_LOCAL :$IRC_MSG"
}
proc ::ReplicaServ::SENT { DATA } {
	variable SERVICEBOT_PIPELINE
	variable config
	$SERVICEBOT_PIPELINE	send ":$config(serverinfo_id) $DATA"
}
proc ::ReplicaServ::SENT:MSG:TO:USER { DEST MSG } {
	variable config
	if { $config(uplink_useprivmsg) == 1 } {
		::ReplicaServ::SENT:PRIVMSG $DEST $MSG;
	} else {
		::ReplicaServ::SENT:NOTICE $DEST $MSG;
	}
}
proc ::ReplicaServ::SENT:MSG:TO:CHAN:LOG { MSG } {
	variable config
	::ReplicaServ::SENT:PRIVMSG $config(service_channel) $MSG;
}

proc ::ReplicaServ::DB:INIT { LISTDB } {
	foreach DB_FILE_NAME [split $LISTDB] {
		if { ![file exists "[::ReplicaServ::Get:ScriptDir "db"]${DB_FILE_NAME}"] } {
			set FILE_PIPE	[open "[::ReplicaServ::Get:ScriptDir "db"]${DB_FILE_NAME}" a+];
			close $FILE_PIPE
		}
	}
}
###############################################################################
### Substitution des symboles couleur/gras/soulignement/...
###############################################################################
# Modification de la fonction de MenzAgitat
# <cXX> : Ajouter un Couleur avec le code XX : <c01>; <c02,01>
# </c> : Enlever la Couleur (refermer la deniere declaration <cXX>) : </c>
# <b> : Ajouter le style Bold/gras
# </b> : Enlever le style Bold/gras
# <u> : Ajouter le style Underline/souligner
# </u> : Enlever le style Underline/souligner
# <i> : Ajouter le style Italic/Italique
# <s> : Enlever les styles precedent
proc ::ReplicaServ::apply_visuals { data } {
	regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} $data "\003\\1" data
	regsub -all -nocase {<b>|</b>} $data "\002" data
	regsub -all -nocase {<u>|</u>} $data "\037" data
	regsub -all -nocase {<i>|</i>} $data "\026" data
	return [regsub -all -nocase {<s>} $data "\017"]
}
proc ::ReplicaServ::Remove_visuals { data } {
	regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} $data "" data
	regsub -all -nocase {<b>|</b>} $data "" data
	regsub -all -nocase {<u>|</u>} $data "" data
	regsub -all -nocase {<i>|</i>} $data "" data
	return [regsub -all -nocase {<s>} $data ""]
}

proc ::ReplicaServ::TXT:ESPACE:DISPLAY { text length } {
	set text			[string trim $text]
	set text_length		[string length $text];
	set espace_length	[expr ($length - $text_length)/2.0]
	set ESPACE_TMP		[split $espace_length .]
	set ESPACE_ENTIER	[lindex $ESPACE_TMP 0]
	set ESPACE_DECIMAL	[lindex $ESPACE_TMP 1]
	if { $ESPACE_DECIMAL == 0 } {
		set espace_one			[string repeat " " $ESPACE_ENTIER];
		set espace_two			[string repeat " " $ESPACE_ENTIER];
		return "$espace_one$text$espace_two"
	} else {
		set espace_one			[string repeat " " $ESPACE_ENTIER];
		set espace_two			[string repeat " " [expr ($ESPACE_ENTIER+1)]];
		return "$espace_one$text$espace_two"
	}

}

proc ::ReplicaServ::IRC:QUIT { IRC_NAME MSG } {
	variable config
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Fermeture du Socket IRC :<c04> $IRC_NAME <c11>raison<c04> $MSG"
	::ReplicaServ::IRC:Sent $IRC_NAME "QUIT $MSG"
}
proc ::ReplicaServ::IRC:Sent { IRC_NAME arg } {
	variable config
	if { $config(uplink_debug) == 1 } {
		putlog "ReplicaServ IRC $IRC_NAME Sent: $arg"
	}
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c11>Sent<c04> $arg"
	puts $config(idx_$IRC_NAME) $arg
}
proc ::ReplicaServ::Socket:Sent { arg } {
	variable config
	if { $config(uplink_debug) == 1 } {
		putlog "ReplicaServ Socket Sent: $arg"
	}
	puts $config(idx) $arg
}

proc ::ReplicaServ::CMD:LOG { cmd sender } {
	variable config
	if { $config(admin_console) eq "1" } { ::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Commandes :<c04> [string trim $cmd] <c12>par<c04> $sender" }
}

proc ::ReplicaServ::CMD:SHOW:LIST { DEST } {
	set max				8;
	set l_espace		13;
	set CMD_LIST		""
	foreach CMD [::ReplicaServ::DB:CMD:LIST] {
		lappend CMD_LIST	"<c04>[::ReplicaServ::TXT:ESPACE:DISPLAY $CMD $l_espace]<c12>"
		if { [incr i] > $max-1 } {
			unset i
		::ReplicaServ::SENT:MSG:TO:USER $DEST [join $CMD_LIST " | "];
			set CMD_LIST	""
		}
	}
	::ReplicaServ::SENT:MSG:TO:USER $DEST [join $CMD_LIST " | "];
	::ReplicaServ::SENT:MSG:TO:USER $DEST "<c>";
}
proc ::ReplicaServ::DB:NETWORK:EXIST { DATA } {
	set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/network.db"
	if { ![file exist $DB_FILE] } { return "-1"; }
	set FILE_PIPE	[open $DB_FILE r];
	while { ![eof $FILE_PIPE] } {
		gets $FILE_PIPE FILE_DATA;
		if { [string match -nocase $DATA [lindex $FILE_DATA 0]] } {
			close $FILE_PIPE;
			return 1;
		}
	}
	close $FILE_PIPE;
	return 0;
}

proc ::ReplicaServ::DB:DATA:EXIST { DB DATA } {
	set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/${DB}.db"
	if { ![file exist $DB_FILE] } { return "-1"; }
	set FILE_PIPE	[open $DB_FILE r];
	while { ![eof $FILE_PIPE] } {
		gets $FILE_PIPE FILE_DATA;
		if { [string match -nocase $DATA $FILE_DATA] } {
			close $FILE_PIPE;
			return 1;
		}
	}
	close $FILE_PIPE;
	return 0;
}

proc ::ReplicaServ::DB:DISTANT:LINK:CONNECT { IRC_NAME CHAN_LOCAL CHAN_DISTANT } {
	variable config
	::ReplicaServ::Socket:Sent ":$config(service_nick) JOIN $CHAN_LOCAL"
	::ReplicaServ::IRC:Sent $IRC_NAME "JOIN $CHAN_DISTANT"
}
proc ::ReplicaServ::DB:DISTANT:ADD:LINK { NETWORK_NAME CHAN_LOCAL CHAN_DISTANT } {
	if { [string index $CHAN_LOCAL 0] != "#" } { return 0; }
	if { [string index $CHAN_DISTANT 0] != "#" } { return 0; }
	if { ![::ReplicaServ::DB:NETWORK:EXIST $NETWORK_NAME] } { return 0; }
	set DATA [list $NETWORK_NAME $CHAN_LOCAL $CHAN_DISTANT]
	if { [::ReplicaServ::DB:DATA:EXIST "channel_distant" $DATA] == 0 } {
		set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/channel_distant.db"
		set FILE_PIPE	[open $DB_FILE a];
		puts $FILE_PIPE $DATA;
		close $FILE_PIPE;
		::ReplicaServ::DB:DISTANT:LINK:CONNECT $NETWORK_NAME $CHAN_LOCAL $CHAN_DISTANT
		return 1;
	} else {
		return -1;
	}
}

proc ::ReplicaServ::DB:DATA:REMOVE { DB DATA } {
	set DB_FILE			"[::ReplicaServ::Get:ScriptDir "db"]/${DB}.db"
	if { ![file exist $DB_FILE] } { return "-1"; }

	set FILE_PIPE		[open $DB_FILE r];
	set STATE			0;
	set FILE_NEW_DATA	[list];
	while { ![eof $FILE_PIPE] } {
		gets $FILE_PIPE FILE_DATA;
		if { [string match -nocase $DATA $FILE_DATA] } {
			set STATE		1;
		} elseif { $FILE_DATA != "" } {
			lappend FILE_NEW_DATA $FILE_DATA;
		}
	}
	close $FILE_PIPE
	set FILE_PIPE		[open $DB_FILE w+];
	foreach LINE_NEW $FILE_NEW_DATA { puts $FILE_PIPE $LINE_NEW }
	close $FILE_PIPE
	return $STATE;
}
####################
#--> Procedures <--#
####################
proc ::ReplicaServ::IRC:AUTO:JOIN { IRC_NAME IRC_NICKNAME } {
	set FILE(LINK)	"[::ReplicaServ::Get:ScriptDir "db"]/link.db";
	set FILE_PIPE	[open $FILE(LINK) "r"];
	set fc			-1;
	while { ![eof $FILE_PIPE] } {
		set FILE_LINE	[gets $FILE_PIPE];
		incr fc;
		if { $FILE_LINE != "" } {
			set F_IRC_NAME		[lindex $FILE_LINE 0];
			set F_CHAN_LOCAL	[lindex $FILE_LINE 1];
			set F_CHAN_DISTANT	[lindex $FILE_LINE 2];
			if { [string match -nocase $F_IRC_NAME $IRC_NAME] } {
				::ReplicaServ::JOIN $F_CHAN_LOCAL;
				::ReplicaServ::IRC:JOIN $IRC_NAME $F_CHAN_DISTANT;
				::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>$IRC_NICKNAME LINK $IRC_NAME :<c04> $F_CHAN_LOCAL <c12>à<c04> $F_CHAN_DISTANT"
			}
		}
		unset FILE_LINE
	}
	close $FILE_PIPE
}

proc ::ReplicaServ::IRC:Connexion { IRC_NAME IRC_HOST IRC_PORT {IRC_PASSWORD ""} {IRC_NICKNAME ""} {IRC_USERNAME ""} } {
	variable config
	variable IRCC_DATA
	set IRCC_DATA($IRC_NAME,PIPELINE)	[::IRCC::connection]
	set PIPELINE $IRCC_DATA($IRC_NAME,PIPELINE)
	$PIPELINE config logger	1;
	$PIPELINE config debug	1; 
	# Connect to the server.
	$PIPELINE connect	$IRC_HOST $IRC_PORT $IRC_PASSWORD
	$PIPELINE user		$IRC_NICKNAME $IRC_USERNAME "ReplicaServ. Visit: https://git.io/JYGvA"
						# username localhostname localdomainname userinfo
	$PIPELINE registerevent defaultevent "
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"IRC '$IRC_NAME' (\[action\]-\[numname\]) \[msg\] | \[header\]\"
	"
	$PIPELINE registerevent defaultcmd "
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"IRC '$IRC_NAME' (\[action\]-\[numname\]) \[msg\] | \[header\]\"
	"
	$PIPELINE registerevent defaultnumeric "
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"IRC '$IRC_NAME' (\[action\]-\[numname\]) \[msg\] | \[header\]\"
	"
	$PIPELINE registerevent 001 "
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"Connexion à l'IRC '$IRC_NAME' de '\[lindex \[msg\] 6\]' reussi.. \[msg\]\"
		::ReplicaServ::IRC:AUTO:JOIN $IRC_NAME $IRC_NICKNAME
	"
	# EVENTS NON UTILISER 
	$PIPELINE registerevent 002 "
		# (002) Your host is irc.qnet.net, running version UnrealIRCd-5.0.8 irc.qnet.net 002 TESTIRC
	"
	$PIPELINE registerevent 003 "
		# (003) This server was created Fri Mar 19 2021 at 14:33:34 CET irc.qnet.net 003 TESTIRC
	"
	$PIPELINE registerevent 004 "
		# (004) irc.qnet.net 004 TESTIRC irc.qnet.net UnrealIRCd-5.0.8 iowrsxzdHtIDZRqpWGTSB lvhopsmntikraqbeIHzMQNRTOVKDdGLPZSCcf
	"
	$PIPELINE registerevent 005 "
		# (005) are supported by this server irc.qnet.net 005 TESTIRC AWAYLEN=307 BOT=B CASEMAPPING=ascii CHANLIMIT=#:10 CHANMODES=beIqa,kLf,lH,psmntirzMQNRTOVKDdGPZSCc CHANNELLEN=32 CHANTYPES=# DEAF=d ELIST=MNUCT EXCEPTS EXTBAN=~,ptmTSOcarnqjf HCN
	"
	$PIPELINE registerevent 250 "
		# (250-RPL_STATSDLINE) Highest connection count: 3983 (3982 clients) (95857 connections received) | barjavel.freenode.net 250 Repliboy
	"
	$PIPELINE registerevent 251 "
		# (251) There are 7 users and 18 invisible on 3 servers irc.qnet.net 251 TESTIRC
	"
	$PIPELINE registerevent 252 "
		# (252) operator(s) online irc.qnet.net 252 TESTIRC 17
	"
	$PIPELINE registerevent 253 "
		# (253) unknown connection(s) irc.qnet.net 253 TESTIRC 1
	"
	$PIPELINE registerevent 254 "
		# (254) channels formed irc.qnet.net 254 TESTIRC 17
	"
	$PIPELINE registerevent 255 "
		# (255) I have 15 clients and 2 servers irc.qnet.net 255 TESTIRC
	"
	$PIPELINE registerevent 265 "
		# (265) Current local users 15, max 19 irc.qnet.net 265 TESTIRC 15 19
	"
	$PIPELINE registerevent 266 "
		# (266) Current global users 25, max 225 irc.qnet.net 266 TESTIRC 25 225
	"
	$PIPELINE registerevent 315 "
		# (315-RPL_ENDOFWHO) End of /WHO list. | barjavel.freenode.net 315 RepliBoy559 #feral
	"
	$PIPELINE registerevent 372 "
		# (372) - 13/11/2017 18:50 courbevoie2.fr.epiknet.org 372 Repliboy
	"
	$PIPELINE registerevent 375 "
		# (375) - courbevoie2.fr.epiknet.org Message of the Day - courbevoie2.fr.epiknet.org 375 Repliboy
	"
	$PIPELINE registerevent 376 "
		# (376) End of /MOTD command. courbevoie2.fr.epiknet.org 376 Repliboy
	"
	$PIPELINE registerevent 396 "
		# (396) is now your displayed host irc.qnet.net 396 TESTIRC QNET-1E3F7F74.clients.your-server.de
	"
	$PIPELINE registerevent 422 "
		# (422) MOTD File is missing irc.qnet.net 422 TESTIRC
	"



	# EVENTS UTILISER
	$PIPELINE registerevent 366 "
		# Fin de /NAMES
		# (366) End of /NAMES list. courbevoie2.fr.epiknet.org 366 Repliboy #eggdrop
		set channel \[join \[additional\]\]
		set IRCC_DATA($IRC_NAME,TMP_CHAN)	\$channel
		set IRCC_DATA($IRC_NAME,CHAN_STATE)	1
		$PIPELINE send \"WHO \$channel\"
	"
	$PIPELINE registerevent 433 "
		if { \[lindex \[additional\] 0\] == \"$IRC_NICKNAME\" } {
			set nicknew	\"\[string trimright $IRC_NICKNAME 0123456789\]\[string range \[expr rand()\] end-2 end\]\"
			cmd-send \"NICK \$nicknew\"
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"Le NICK '$IRC_NICKNAME' est utilisé sur $IRC_NAME.. je prend \$nicknew\"
		}
	"
	# 353 MalaGaM2 = #feral :MalaGaM2 ZarTek ozymandias_ ant1mony_ EpicKitty _Lemon_ feralbot2 knv2[m] 
	$PIPELINE registerevent 353 "
		set IRC_CHANNEL		\[lindex \[additional\] 1\]
		set IRC_USERS_LIST	\[msg\]
		#::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"<c12>Socket IRC :<c04> $IRC_NAME <c11>\$IRC_CHANNEL<c04> \$IRC_USERS_LIST\"
			# /NAMES
	"
	$PIPELINE registerevent 352 "
		# 352 MalaGaM2 #feral ~limnoria 2607:5300:60:814::1 sinisalo.freenode.net feralbot2 H :0 Limnoria Limnoria 2016.12.08
		# 352 MalaGaM2 #feral ~joshua 185.21.216.160 beckett.freenode.net _Lemon_ H :0 Unknown
		# 352 MalaGaM2 #feral EpicKitty unaffiliated/epickitty wilhelm.freenode.net EpicKitty H :0 Richard Bowey
		# 352 MalaGaM2 #feral ~epollyon 185.21.216.154 beckett.freenode.net ant1mony_ H :0 Unknown
		set channel		\[lindex \[additional\] 0\]
		set ident		\[lindex \[additional\] 1\]
		set host		\[lindex \[additional\] 2\]
		set user		\[lindex \[additional\] 4\]
		set realname	\[join \[lrange \[rawline\] 10 end\]\]
		::ReplicaServ::IRC:VIRTUAL:USER:CREATE $IRC_NAME \$channel \$user \$ident \$host \$realname
		# Who
	"
	$PIPELINE registerevent PRIVMSG "
		::ReplicaServ::VPRIVMSG $IRC_NAME \[target\] \[who\] \[msg\]
	"
	$PIPELINE registerevent NOTICE "
		::ReplicaServ::VNOTICE $IRC_NAME \[target\] \[who\] \[msg\]
	"
	$PIPELINE registerevent NICK {
		if { [who] == $::IRCC::nick } {
			set ::IRCC::nick [msg]
		} else {
			putlog "*** [who] is now known as [msg]"
		}
	}
	
	$PIPELINE registerevent EOF "
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"Deconnexion du IRC $IRC_NAME\"
		::IRCC::connect \$::IRCC::IRCC_DATA $IRC_HOST $IRC_PORT
	"
}

	
proc ::ReplicaServ::IRC:VIRTUAL:USER:CREATE { IRC_NAME CHANNEL_DISTANT USERNAME USERIDENT USERHOST REALNAME } {
	variable config
	variable SERVICE_PIPELINE
	if { $USERIDENT == "" } { return }

	set FILE(LINK)		"[::ReplicaServ::Get:ScriptDir "db"]/link.db"
	set FILE_PIPE		[open $FILE(LINK) "r"]
	set CHANNEL_LOCAL	""
	set fc	-1
	while { ![eof $FILE_PIPE] } {
		set FILE_LINE	[gets $FILE_PIPE]
		incr fc
		if { $FILE_LINE != "" } {
			if { [string match -nocase "$IRC_NAME * $CHANNEL_DISTANT" $FILE_LINE] } {
				set CHANNEL_LOCAL [lindex $FILE_LINE 1];
				break;
			}
		}
		unset FILE_LINE
	}
	close $FILE_PIPE
	unset FILE_PIPE
	set USERUID [$SERVICE_PIPELINE vusercreate $USERNAME $USERIDENT $USERHOST $REALNAME]

	::ReplicaServ::SENT "SJOIN [clock seconds] $CHANNEL_LOCAL + :$USERUID"
	return
	if ![info exists comchan($user)] { 
		poupee::connect $user $ident $host $realname
		set comchan($user) ""
	}
	if { ![regexp {^#} $salon] } { return }

	if [info exists users([string toupper $salon])] {
		set i [lsearch -exact $users([string toupper $salon]) $user]
		if { $i < 0 && $force == 1 } { lappend users([string toupper $salon]) $user; lappend signes([string toupper $salon]) "" }
		set j [lsearch -exact $miroir([string toupper $salon]) $user]
		if { $j < 0 } {
			if { $force == 1 || $force < 1 && $i >= 0 } { lappend miroir([string toupper $salon]) $user
			 if { [lsearch -exact $comchan($user) [string toupper $salon]] < 0 } { lappend comchan($user) [string toupper $salon] }
				puts $::socket(poupee) ":$user JOIN $salon"
				set signe [acces [lindex $signes([string toupper $salon]) $i]]
				
				switch -exact $signe {
					"@" { puts $::socket(poupee) ":$poupee::link MODE $salon +o $user" }
					"%" { puts $::socket(poupee) ":$poupee::link MODE $salon +h $user" }
					"+" { puts $::socket(poupee) ":$poupee::link MODE $salon +v $user" }
					"&" { puts $::socket(poupee) ":$poupee::link MODE $salon +oa $user $user" }
					"~" { puts $::socket(poupee) ":$poupee::link MODE $salon +oq $user $user" }
				}
				
			} elseif { $force < 0 } { puts $::socket(poupee) ":$user MODE $user +o"; print "ircop depuis creer" }
		}
		# de $j < 0 (le salon miroir ne contient pas le pseudo)
	} elseif { [string compare -nocase $user $proxy::pseudo] == 0 } {
		# Le salon n'existe pas, il est créé par l'espion
		set users([string toupper $salon]) $user
		set miroir([string toupper $salon]) $user
		if { [lsearch -exact $salons [string toupper $salon]] < 0 } { lappend salons [string toupper $salon] }
		if { [lsearch -exact $comchan($user) [string toupper $salon]] < 0 } { lappend comchan($user) [string toupper $salon] }
		# Le set comchan c'est pour l'espion!
		puts $::socket(poupee) ":$user JOIN $salon"
	}
}

proc ::ReplicaServ::IRC:Event { IRC_NAME } {
	variable config
	if { [eof $config(idx_$IRC_NAME)] } {
		fileevent $config(idx_$IRC_NAME) readable "";
		::ReplicaServ::IRC:QUIT $IRC_NAME "fermeture par le serveur"
		putlog "Socket IRC $IRC_NAME closed\n";
		close $config(idx_$IRC_NAME)
		unset config(idx_$IRC_NAME);
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC:<c04> closed <c12>de<c04> $IRC_NAME";
		return
	}
	gets $config(idx_$IRC_NAME) arg
	set arg [split $arg]

	#::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c12>Receive<c04> $arg"
	putlog "[lindex $arg 0] ::IRC:Event recoi $arg"
	switch -exact [lindex $arg 0] {
		"PING" {
			::ReplicaServ::IRC:Sent $IRC_NAME "PONG [lindex $arg 1]"
		}
		"ERROR" {
			set MSG_ERR [string trim [lrange $arg 1 end] :]
			putlog "::ReplicaServ IRC $IRC_NAME error : $MSG_ERR"
			exit "ReplicaServ quit"
		}
	}
	switch -exact [lindex $arg 1] {
		"ERROR"	{
			set MSG_ERR [string trim [lrange $arg 1 end] :]
			putlog "::ReplicaServ IRC $IRC_NAME error : $MSG_ERR"
			exit "ReplicaServ quit"
		}
		"352" {
			# 352 MalaGaM2 #feral ~limnoria 2607:5300:60:814::1 sinisalo.freenode.net feralbot2 H :0 Limnoria Limnoria 2016.12.08
			# 352 MalaGaM2 #feral ~joshua 185.21.216.160 beckett.freenode.net _Lemon_ H :0 Unknown
			# 352 MalaGaM2 #feral EpicKitty unaffiliated/epickitty wilhelm.freenode.net EpicKitty H :0 Richard Bowey
			# 352 MalaGaM2 #feral ~epollyon 185.21.216.154 beckett.freenode.net ant1mony_ H :0 Unknown
			set channel		[lindex $arg 3]
			set ident		[lindex $arg 4]
			set host		[lindex $arg 5]
			set user		[lindex $arg 7]
			set realname	[join [lrange $arg 10 end]]
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "------------> $channel ->> $user!$ident@$host"
			#poupee::creer "$user!$ident@$host" [rvv $proxy::salon] $realname	1
			::ReplicaServ::IRC:VIRTUAL:USER:CREATE "$user!$ident@$host" $channel $realname	1
			#if [regexp {\*} [lindex $arg 8]] { puts $::socket(poupee) ":$user MODE $user +o"; print "ircop depuis 332" }
			# Who
			
		}
		"353"	{
			# 353 MalaGaM2 = #feral :MalaGaM2 ZarTek ozymandias_ ant1mony_ EpicKitty _Lemon_ feralbot2 knv2[m] 
			regexp {^\S+ \d+ \S+ \S (\S+) :(.+)$} [join $arg] - IRC_CHANNEL IRC_USERS_LIST
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c11>$IRC_CHANNEL<c04> $IRC_USERS_LIST"
			# /NAMES
		}
		"366"	{
			# 366 MalaGaM2 #feral :End of /NAMES list.
			regexp {^\S+ \d+ \S+ (\S+)} [join $arg] - IRC_CHANNEL
			# poupee::classer $IRC_CHANNEL
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c11>FIN DE /NAMES<c04> $IRC_CHANNEL"
			::ReplicaServ::IRC:Sent $IRC_NAME		"WHO $IRC_CHANNEL"
			# if {$proxy::who == "1"} { puts $::socket(proxy) "WHO $proxy::salon" }
			# Fin de /NAMES
		}
		"372"	{
			# 372 MalaGaM2 :- Welcome to barjavel.freenode.net in Paris, FR, EU. {}
			# 372 MalaGaM2 :- Thanks to Bearstech (www.bearstech.com) for sponsoring
		}
		"375"	{
			# 375 MalaGaM2 :- barjavel.freenode.net Message of the Day - {}
		}
		"376"	{
			# 376 MalaGaM2 :End of /MOTD command.
		}
		"433"	{
			# 433 * RepliBoy :Nickname is already in use.'
			# Nickname already in use
			set nick [lindex $arg 3]
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Pseudo deja utiliser<c04> $nick <c11>sur<c04> $IRC_NAME"
			
			::ReplicaServ::IRC:QUIT $IRC_NAME "Pseudo '$nick' deja utiliser"
		}
		default {
			putlog "ReplicaServ IRC $IRC_NAME Received: ([lindex $arg 1]) '$arg'" 
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c11>Received<c04> $arg"
		}
	}
}

proc ::ReplicaServ::Socket:Event { } {
	variable config
	global ::ReplicaServ::UID_DB
	if [eof $config(idx)] {
		fileevent $config(idx) readable ""
		close $config(idx)
		putlog "Socket closed\n"
		return
	}

	gets $config(idx) arg
	set arg [split $arg]

	if { $config(uplink_debug) == 1 } { 
		putlog "ReplicaServ Socket Received: '$arg'" 
		
	}
	switch -exact [lindex $arg 0] {
		"ERROR" {
			set MSG_ERR [string trim [lrange $arg 1 end] :]
			putlog "::ReplicaServ Socket error : $MSG_ERR"
			exit "ReplicaServ quit"
		}
		"PING" {
			::ReplicaServ::Socket:Sent "PONG [lindex $arg 1]"
		}
		"NETINFO" {
			set config(netinfo)		[lindex $arg 4]
			set config(network)		[lindex $arg 8]
			::ReplicaServ::Socket:Sent "NETINFO 0 [unixtime] 0 $config(netinfo) 0 0 0 $config(network)"
		}
		"SQUIT" {
			set serv		[lindex $arg 1]
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c>$config(console_com)Unlink <c>$config(console_deco):<c>$config(console_txt) $serv"
		}
		"SERVER" {
			# Received: SERVER irc.xxx.net 1 :U5002-Fhn6OoEmM-001 Serveur networkname
			if { $config(init) == 1 } {
				::ReplicaServ::Server:Connexion
			}
		}
	}
}

#######################
# --> Commandes <-- #
#######################

proc ::ReplicaServ::IRC:CMD:PRIV:LINK { sender destination cmd data } {
	variable config
	variable IRCC_DATA
	variable SERVICEBOT_PIPELINE
	set sub_cmd		[string tolower [lindex $data 0]];
	set cmd_data	[lrange $data 1 end];
	set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/link.db"
	if { $sub_cmd == "add" } {
		if { [lindex $cmd_data 2] == "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide d'ajout de link<c04> :."
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd $sub_cmd <nom du réseau> <#salon_local> <#salon_distant>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> Exemple:<c04> /msg $config(service_nick) $cmd $sub_cmd freenode #mon_salon #Salon_sur_freenode"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			return 0;
		}
		set IRC_NAME		[lindex $cmd_data 0]
		set CHAN_LOCAL		[lindex $cmd_data 1];
		set CHAN_DISTANT	[lindex $cmd_data 2];
		set FILE_PIPE		[open "[::ReplicaServ::Get:ScriptDir "db"]/network.db" "r"]
		set state			0
		set fc	-1
		while {![eof $FILE_PIPE]} {
			set FILE_LINE	[gets $FILE_PIPE]
			incr fc
			if { $FILE_LINE != "" } {
				if { [string match -nocase "$IRC_NAME *" $FILE_LINE] } { set state 1 }
			}
			unset FILE_LINE
		}
		close $FILE_PIPE
		unset FILE_PIPE
		if { $state == 0 } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Aucun réseau '$IRC_NAME'."
			return 0
		}
		set FILE_PIPE		[open $DB_FILE "r"]
		set state			0
		set fc	-1
		while {![eof $FILE_PIPE]} {
			set FILE_LINE	[gets $FILE_PIPE]
			incr fc
			if { $FILE_LINE != "" } {
				if { [string match -nocase "$IRC_NAME $CHAN_LOCAL $CHAN_DISTANT" [lindex $FILE_LINE 1]] } { set state 1 }
			}
			unset FILE_LINE
		}
		close $FILE_PIPE
		unset FILE_PIPE
		if { $state == 1 } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Link existe deja."
			return 0
		}
		set FILE_PIPE		[open $DB_FILE a]
		puts $FILE_PIPE		"$IRC_NAME $CHAN_LOCAL $CHAN_DISTANT"
		close $FILE_PIPE
		::ReplicaServ::JOIN $CHAN_LOCAL
		::ReplicaServ::IRC:JOIN $IRC_NAME $CHAN_DISTANT

	} elseif { $sub_cmd == "list" } {
		set FILE_PIPE	[open $DB_FILE "r"]
		set fc		-1
		set space	15
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>-------------------------------------------------------"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c12>[::ReplicaServ::TXT:ESPACE:DISPLAY RESEAU $space] <c04>|<c12> [::ReplicaServ::TXT:ESPACE:DISPLAY "CHANNEL LOCAL" $space] <c04>|<c12> [::ReplicaServ::TXT:ESPACE:DISPLAY "CHANNEL DISTANT" $space]"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>-------------------------------------------------------"
		while {![eof $FILE_PIPE]} {
			set FILE_LINE	[gets $FILE_PIPE]
			incr fc
			if { $FILE_LINE != "" } {
				# freenode #Amandine #feral
				set IRC_NAME		[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 0] $space];
				set CHANNEL_LOCAL	[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 1] $space];
				set CHANNEL_DISTANT	[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 2] $space];
				::ReplicaServ::SENT:MSG:TO:USER $sender "<c07>$IRC_NAME <c04>|<c07> $CHANNEL_LOCAL <c04>|<c07> $CHANNEL_DISTANT"
			}
			unset FILE_LINE
		}
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>-------------------------------------------------------"
		close $FILE_PIPE
	} elseif { $sub_cmd == "remove" } {
		if { [lindex $cmd_data 2] == "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide de supression de Link<c04> :."
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd $sub_cmd <réseau> <CHANNEL_LOCAL> <CHANNEL_DISTANT>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> Exemple:<c04> /msg $config(service_nick) $cmd $sub_cmd epiknet"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			return 0;
		}
		set IRC_NAME		[lindex $cmd_data 0]
		set CHANNEL_LOCAL	[lindex $cmd_data 1]; # nick irc
		set CHANNEL_DISTANT	[lindex $cmd_data 2]; # ident

		set FILE_PIPE		[open $DB_FILE r];
		set STATE			0;
		set FILE_NEW_DATA	[list];
		while { ![eof $FILE_PIPE] } {
			gets $FILE_PIPE FILE_DATA;
			if { [string match -nocase "$IRC_NAME*$CHANNEL_LOCAL*$CHANNEL_DISTANT" $FILE_DATA] } {
				set STATE		1;
			} elseif { $FILE_DATA != "" } {
				lappend FILE_NEW_DATA $FILE_DATA;
			}
		}
		close $FILE_PIPE
		set FILE_PIPE		[open $DB_FILE w+];
		foreach LINE_NEW $FILE_NEW_DATA { puts $FILE_PIPE $LINE_NEW }
		close $FILE_PIPE
		if { $STATE } {
			set IRC_PIPELINE	"$IRCC_DATA($IRC_NAME,PIPELINE)"
			::ReplicaServ::CMD:LOG "Suppression du link $IRC_NAME de $CHANNEL_DISTANT à $CHANNEL_LOCAL réussi.." $sender
			$IRC_PIPELINE part $CHANNEL_DISTANT
			$SERVICEBOT_PIPELINE part $CHANNEL_LOCAL
			::ReplicaServ::SENT:MSG:TO:USER $sender "Suppression du link $IRC_NAME de $CHANNEL_DISTANT à $CHANNEL_LOCAL réussi.."
			return 1
		} else {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Link  $IRC_NAME de $CHANNEL_DISTANT à $CHANNEL_LOCAL  non trouver.."
		}
		return 0
	} else {
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide Link<c04> :."
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Link Add" 15]<c12>- <c06>Ajoute un Link"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Link Remove" 15]<c12>- <c06>Suprime un Link"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Link List" 15]<c12>- <c06>Liste des Links"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
	}
	::ReplicaServ::CMD:LOG "$cmd $sub_cmd $cmd_data" $sender
}
proc ::ReplicaServ::IRC:CMD:PRIV:NETWORK { sender destination cmd data } {
	variable config
	variable IRCC_DATA
	set sub_cmd		[string tolower [lindex $data 0]];
	set cmd_data	[lrange $data 1 end];
	set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/network.db"
	if { $sub_cmd == "add" } {
		if { [lindex $cmd_data 3] == "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide d'ajout de réseau<c04> :."
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd $sub_cmd <nom> <nickname> <username> <adresse:<\[+\]port:\[password\]>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> Exemple:<c04> /msg $config(service_nick) $cmd $sub_cmd freenode RepliBoy Ident barjavel.freenode.net:+6697"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			return 0;
		}
		set IRC_NAME		[lindex $cmd_data 0]
		set IRC_NICKNAME	[lindex $cmd_data 1]; # nick irc
		set IRC_USERNAME	[lindex $cmd_data 2]; # ident
		set IRC_ADDRESS		[lindex $cmd_data 3]; # info de connexion

		set IRC_DATA		[split $IRC_ADDRESS :]
		set IRC_HOST		[lindex $IRC_DATA 0]
		set IRC_PORT		[lindex $IRC_DATA 1]
		set IRC_PASSWORD	[lindex $IRC_DATA 2]
		
		set FILE_PIPE	[open $DB_FILE "r"]
		set fc	-1

		while {![eof $FILE_PIPE]} {
			set FILE_LINE	[gets $FILE_PIPE]
			incr fc
			if { $FILE_LINE != "" } {
				set F_IRC_NAME	[lindex $FILE_LINE 0]
				if { [string match -nocase $IRC_NAME $F_IRC_NAME] } {
					::ReplicaServ::SENT:MSG:TO:USER $sender "Le réseau $F_IRC_NAME existe déjà."
					close $FILE_PIPE
					return 0
				}
			}
			unset FILE_LINE
		}
		close $FILE_PIPE
		set FILE_PIPE		[open $DB_FILE a]
		puts $FILE_PIPE		"$IRC_NAME $IRC_NICKNAME $IRC_USERNAME $IRC_ADDRESS"
		close $FILE_PIPE
		::ReplicaServ::SENT:MSG:TO:USER $sender "IRC ajouter! Connexion à $IRC_NAME ..."
		::ReplicaServ::IRC:Connexion $IRC_NAME $IRC_HOST $IRC_PORT $IRC_PASSWORD $IRC_NICKNAME $IRC_USERNAME
		
	} elseif { $sub_cmd == "list" } {
		set FILE_PIPE	[open $DB_FILE "r"]
		set fc	-1
		set space 15
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>---------------------------------------------------------------------------------------------"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c12>[::ReplicaServ::TXT:ESPACE:DISPLAY RESEAU $space] <c04>|<c12> [::ReplicaServ::TXT:ESPACE:DISPLAY NICK $space] <c04>|<c12> [::ReplicaServ::TXT:ESPACE:DISPLAY IDENT $space] <c04>|<c12> ADRESSE"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>---------------------------------------------------------------------------------------------"
		while {![eof $FILE_PIPE]} {
			set FILE_LINE	[gets $FILE_PIPE]
			incr fc
			if { $FILE_LINE != "" } {
				set IRC_NAME	[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 0] $space];
				set USER_NICK	[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 1] $space];
				set USER_IDENT	[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 2] $space];
				set IRC_ADRESS	[lindex $FILE_LINE 3];
				::ReplicaServ::SENT:MSG:TO:USER $sender "<c07>$IRC_NAME <c04>|<c07> $USER_NICK <c04>|<c07> $USER_IDENT <c04>|<c07> $IRC_ADRESS"
			}
			unset FILE_LINE
		}
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>---------------------------------------------------------------------------------------------"
		close $FILE_PIPE
	} elseif { $sub_cmd == "remove" } {
		if { [lindex $cmd_data 0] == "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide de supression de réseau<c04> :."
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd $sub_cmd <réseau>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> Exemple:<c04> /msg $config(service_nick) $cmd $sub_cmd epiknet"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			return 0;
		}
		set IRC_NAME		[lindex $cmd_data 0]
		set USER_NICK		[lindex $cmd_data 1]; # nick irc
		set USER_IDENT		[lindex $cmd_data 2]; # ident

		set FILE_PIPE		[open [::ReplicaServ::Get:ScriptDir "db"]/link.db r]
		while { ![eof $FILE_PIPE] } {
			gets $FILE_PIPE FILE_DATA;
			if { [string match -nocase "$IRC_NAME*" $FILE_DATA] } {
				::ReplicaServ::SENT:MSG:TO:USER $sender "Impossible de suprimer un réseau si un LINK existe encore... /msg $config(service_nick) link"
				close $FILE_PIPE
				return 0
			}
		}
		close $FILE_PIPE
		
		set FILE_PIPE		[open $DB_FILE r];
		set STATE			0;
		set FILE_NEW_DATA	[list];
		while { ![eof $FILE_PIPE] } {
			gets $FILE_PIPE FILE_DATA;
			if { [string match -nocase "$IRC_NAME*" $FILE_DATA] } {
				set STATE		1;
			} elseif { $FILE_DATA != "" } {
				lappend FILE_NEW_DATA $FILE_DATA;
			}
		}
		close $FILE_PIPE
		set FILE_PIPE		[open $DB_FILE w+];
		foreach LINE_NEW $FILE_NEW_DATA { puts $FILE_PIPE $LINE_NEW }
		close $FILE_PIPE
		if { $STATE } {
			set IRC_PIPELINE	"$IRCC_DATA($IRC_NAME,PIPELINE)"
			::ReplicaServ::CMD:LOG "Suppression du réseau $IRC_NAME réussi.." $sender
			$IRC_PIPELINE destroy
			::ReplicaServ::SENT:MSG:TO:USER $sender "Suppression du réseau $IRC_NAME réussi.."
			return 1
		} else {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Réseau $IRC_NAME non trouver.."
		}
		return 0

	} else {
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide réseau<c04> :."
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network Add" 15]<c12>- <c06> Ajoute un réseau"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network Remove" 15]<c12>- <c06> Suprime un réseau"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network List" 15]<c12>- <c06> Liste des réseaux"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
	}
	::ReplicaServ::CMD:LOG "$cmd $sub_cmd $cmd_data" $sender
}
proc ::ReplicaServ::IRC:CMD:PRIV:HELP { sender destination cmd data } {
	::ReplicaServ::IRC:CMD:PUB:HELP $sender $destination $cmd $data
}
proc ::ReplicaServ::IRC:CMD:PUB:HELP { sender destination cmd data } {
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide publique<c04> :."
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "!Help" 15]<c12>- <c06> Affiche cette aide"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> "
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide privé<c04> :."
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network" 15]<c12>- <c06> Gestion des réseaux IRC"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Link" 15]<c12>- <c06> Gestion des liens (local & distant)"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Help <Commande>" 15]<c12>- <c06> Affiche l'aide de <Commande>"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
	::ReplicaServ::CMD:LOG $cmd $sender
}
##########################################
# --> Procedures des Commandes Privés <--#
##########################################

ReplicaServ::INIT
