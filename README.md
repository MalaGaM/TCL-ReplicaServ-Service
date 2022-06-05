[<span class="badge-opencollective"><a href="https://github.com/ZarTek-Creole/DONATE" title="Donate to this project"><img src="https://img.shields.io/badge/open%20collective-donate-yellow.svg" alt="Open Collective donate button" /></a></span>
[![CC BY 4.0][cc-by-shield]][cc-by]

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg
[![CC BY 4.0][cc-by-shield]][cc-by]
This work is licensed under a [Creative Commons Attribution 4.0 International License][cc-by].
[![CC BY 4.0][cc-by-image]][cc-by]
[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-image]: https://i.creativecommons.org/l/by/4.0/88x31.png
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg

 <span class="badge-opencollective"><a href="https://github.com/ZarTek-Creole/DONATE" title="Donate to this project"><img src="https://img.shields.io/badge/open%20collective-donate-yellow.svg" alt="Open Collective donate button" /></a></span>
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
