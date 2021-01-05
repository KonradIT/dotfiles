#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#####################
#                   #
#       ALIAS       #
#                   #    
#####################


alias ..='cd ..'
alias ...="cd ../.."
alias rmdb='sudo rm /var/lib/pacman/db.lck'
alias youtube-dl="youtube-dl -o '%(title)s.%(ext)s'"
alias mp3='youtube-dl -x --audio-format "mp3" --audio-quality 0 --embed-thumbnail $*'
alias webserver='python3 -m http.server'
alias cmesg='git diff --name-only'
alias gstore='git config credential.helper store'
alias open="gnome-open"
alias pb="pastebinit -b http://pastebin.com -i "
alias gitg='git log --graph --oneline --decorate --all'
alias gs="git status"
alias q="exit"
alias mocp="mocp; mocp -x"
alias clear_cache="sudo paccache -rk0"
alias gpfw="python ~/GitHub/gopro_fw_dl/gopro-fw-dl.py"
alias inotify_increase="echo fs.inotify.max_user_watches=524288 | sudo tee /etc/sysctl.d/40-max-user-watches.conf && sudo sysctl --system"
alias clear='printf "\033c"'
alias fixadb="sudo adb kill-server && sudo adb devices"
alias dmenu_fixed="dmenu_run -fn '-xos4-terminus-medium-r-*-*-14-*' -h 26"
alias cleanphoto="exiftool -all= $*"
alias today='git log --pretty=format:"%h" --since="6am" | tail -1 | xargs -0 -I {} git diff {}..HEAD'

#####################
#                   #
#     SHORTCUTS     #
#                   #    
#####################

alias d="cd ~/Downloads"
alias gh="cd ~/GitHub"
alias h="cd ~"
alias t="cd ~/Desktop/temp"

#####################
#                   #
#     FUNCTIONS     #
#                   #    
#####################

sprunge() {
	if [[ $1 ]]; then
	curl -F 'sprunge=<-' "http://sprunge.us" <"$1"
	else
	curl -F 'sprunge=<-' "http://sprunge.us"
	fi
}

linx(){
	curl -T "$@" -H "Linx-Randomize: yes" https://linx.li/upload/  
}

mdd(){
	mkdir $1 && cd $1
}

webm(){
	ffmpeg -i $i -c:v libvpx -b:v 1M -c:a libvorbis $o
}

yturlfix(){
	url=$1;
	echo $url | sed 's/.be\//be.com\/watch?v=/g'
}

stfu() {
	exec "$@" 1>/dev/null 2>/dev/null &
}

parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

update_fork() {
git fetch upstream
git rebase upstream/master
git push -f origin master
}

#####################
#                   #
#  NO-OUT COMMANDS  #
#                   #    
#####################

alias gedit='stfu gedit'
alias gimp='stfu gimp'
alias firefox='stfu firefox'


#####################
#                   #
#  GLOBAL VARIABLES #
#                   #    
#####################

BROWSER=/usr/bin/firefox
EDITOR=vim
export GREP_COLOR="1;32"
export PS1="\[\033[38;5;33m\]\u\[$(tput sgr0)\]\[\033[38;5;45m\]@\[$(tput sgr0)\]\[\033[38;5;27m\]\h\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]\[\033[38;5;6m\][\[$(tput sgr0)\]\[\033[38;5;15m\]\W\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;15m\]\[$(tput sgr0)\]\$(parse_git_branch)\[\033[38;5;6m\]]:\[$(tput sgr0)\] "
export PATH=$PATH:~/.npm-global/bin

###############################
#                             #
#  SHORTHAND DOCKER COMMANDS  #
#                             #    
###############################

alias docker_start="sudo systemctl start docker"
alias docker_debian="sudo docker run -it debian /bin/bash"
alias docker_psh="sudo docker run -it microsoft/powershell"


#####################
#                   #
#      TERMUX       #
#                   #    
#####################

var=$0
if [ $var = "/data/data/com.termux/files/usr/bin/bash" ]
	then
		date

		alias t="tmux"
		alias l="ls"
		alias c="cat"
		alias r="ranger"
		alias py="python"
		alias tree='tree -C'
		alias ls='ls -sh1 --color=auto'
	else
		alias ls='ls -sh1 --color=auto'
		alias grep='grep --color=auto'
		alias diff='diff --color=auto'
		alias dmesg='dmesg --color=auto'
		alias tree='tree -C'
		alias dir='dir --color=auto'
		alias egrep='egrep --color=auto'
		alias fgrep='fgrep --color=auto'
		alias ip='ip -c'
		alias pcregrep='pcregrep --color=auto'
		alias vdir='vdir --color=auto'
		alias watch='watch --color'
		alias cower='cower --color=auto'
		alias pacman='pacman --color auto'
		alias pactree='pactree --color'
		alias mc="mc -b"
		alias mocp='mocp -T blackwhite'
fi

### MISC ###

shopt -s autocd

if [ -e ~/scripts/bash_private.sh ]; then
	. ~/scripts/bash_private.sh
fi

# added by travis gem
[ -f /home/konrad/.travis/travis.sh ] && source /home/konrad/.travis/travis.sh

eval $(thefuck --alias)
