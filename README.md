# TCL-ReplicaServ-Service
Version eggdrop du script "Les poupées linkeuses". Permet de répliqué sur votre IRCD les users/messages d'un ircd/salon distance 


# Mémo dev
1 Verification de la config

Creation d'une instance service ::ReplicaServ::INIT:SERVICE
creation du bot service ::ReplicaServ::INIT:BOTSERVICE 
lors de la connexion du services effectuer au irc :
	chargement de network.db pour creer les connexion aux IRC ::ReplicaServ::IRC:Connexion
		lors du signal 001 (RPL_WELCOME) utilisateur reconnu par IRC : 
		Verification link.db pour joindre les salons
