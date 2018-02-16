#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#### Common aliases ####

alias listw='iwlist wlp6s0 scan'
alias fuck='sudo $(history -p \!\!)'
alias wearconnect='adb forward tcp:4444 localabstract:/adb-hub; adb connect 127.0.0.1:4444'
alias ..='cd ..'
alias ...="cd ../.."
alias app="sudo pacman -S $1"
alias sniff="sudo tcpdump | grep $*"
alias wake_session='wol -i 10.5.5.9 -p 9 F6:DD:9E:08:B9:DC'
alias rmdb='sudo rm /var/lib/pacman/db.lck'
alias fixmyshitup='sudo rm /var/lib/pacman/db.lck; sudo pacman -Syy'
alias trello='~/trello-cli/bin/trello'
alias cmusl='cmus --listen 0.0.0.0'
alias simplenotelist="vim -c 'Simplenote -l'"
alias pebblejs="git clone https://github.com/pebble/pebblejs.git"
alias youtube-dl="youtube-dl -o '%(title)s.%(ext)s'"
alias mp3='youtube-dl -x --audio-format "mp3" --audio-quality 0 --embed-thumbnail $*'
alias simplenote="vim -c 'SimplenoteNew'"
alias webserver='python3 -m http.server'
alias todo='python3 ~/todo $*'
alias sshpi='ssh pi@192.168.1.60'
alias cmesg='git diff --name-only'
alias gstore='git config credential.helper store'
alias open="gnome-open"
alias set_headphones="pacmd set-card-profile 4 a2dp_sink"
alias 2villalba="pyrenfe -o 10203 -d 10200"
alias media="printf 'covert2insta - converts video to instagram format\n\tconvert2insta video.mkv insta.mov\naudio4video - adds audio layer to video\n\taudio4video video.mp4 song.mp3 out.mp4\nmp3 - downloads youtube in mp3 format\n'"
alias pb="pastebinit -b http://pastebin.com -i "
alias gitg='git log --graph --oneline --decorate --all'
alias gs="git status"
alias sf='clear && neofetch -t'
alias q="exit"
alias mocp="mocp; mocp -x"
alias syy="sudo pacman -Syy"
alias syu="sudo pacman -Syu"
alias clear_cache="sudo paccache -rk0"
alias gpfw="python ~/GitHub/gopro_fw_dl/gopro-fw-dl.py"
alias inotify_increase="echo fs.inotify.max_user_watches=524288 | sudo tee /etc/sysctl.d/40-max-user-watches.conf && sudo sysctl --system"
alias clear='printf "\033c"'
alias sf="clear && screenfetch"
alias fixmega="pkill megasync && stfu megasync"
alias fixadb="sudo adb kill-server && sudo adb devices"
alias ve_py2="source /home/$USER/Desktop/ve/bin/activate"
### DIRS ###
alias d="cd ~/Downloads"
alias gh="cd ~/GitHub"
alias h="cd ~"
alias t="cd ~/Desktop/temp"


### FUNCTIONS ###

function convert2insta(){
	in="$1"
	out="$2"
	ffmpeg -i $in -c:v libx264 -strict -2 -c:a aac -ar 44100 -r 30 -pix_fmt yuv420p -shortest $out
}

function audio4video(){
	in="$1"
	music="$2"
	out="$3"
	ffmpeg -i $in -i $music -codec copy -shortest $out
}

function sprunge() {
	if [[ $1 ]]; then
	curl -F 'sprunge=<-' "http://sprunge.us" <"$1"
	else
	curl -F 'sprunge=<-' "http://sprunge.us"
	fi
}

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

function git_gud(){
git add $1
git commit -m $2
git push origin $3
}

function linx(){
	curl -T "$@" -H "Linx-Randomize: yes" https://linx.li/upload/  
}


function streamable(){
	curl https://api.streamable.com/upload -F file=@$1 | python3 -c "import sys, json; print('https://streamable.com/' + json.load(sys.stdin)['shortcode'])"
}

function haste(){

	server='hastebin.com';

	usage="$0 pastes into $server
	usage: $0 something
	example: '$0 pie' or 'ps aufx |$0'"

	if [ -z $1 ]; then 
		str=`cat /dev/stdin`;
		else 
		str=$1;
	fi

	if [ -z "$str" ]; then
		echo $usage;
		exit 1;
	fi

	output=`curl -s -X POST -d "$str" $server/documents |perl -pi -e 's|.+:\"(.+)\"}|$1|'`

	echo "http://"$server/$output
}

function mdd(){
	mkdir $1 && cd $1
}
function webm(){
	ffmpeg -i $i -c:v libvpx -b:v 1M -c:a libvorbis $o
}

function yturlfix(){
	url=$1;
	echo $url | sed 's/.be\//be.com\/watch?v=/g'
}

function dl4chan() {

    if [[ $# -ne 1 ]]
    then
        echo 'No URL specified! Give the URL to thread as the ONLY argument'
        return 1
    fi

    url=$1

    grep 'boards\.4chan\.org/[a-z0-9]\{1,4\}/thread/[0-9]\{4,12\}.*' <<< $url 2>&1 > /dev/null
    exit_code=$?    # I know this isn't the best approach, but it's the best I can come up with.
    if [[ $exit_code -ne 0 ]]
    then
        echo 'Malformed URL! Give the URL to thread as the ONLY argument'
        return 2
    fi

    curl -k -f -s $url 2>&1 > /dev/null
    exit_code=$?    # I know this isn't the best approach, but it's the best I can come up with.
    if [[ $exit_code -ne 0 ]]
    then
        echo 'Invalid URL! Or you don`t have permission to view the page'
        return 3
    fi

    if [[ $(grep '^http' <<< $url) ]]    # If thread doesn't have any protocol, add https
    then
        :
    else
        url=$(sed 's/^/https:\/\//' <<< $url)
    fi

    if [[ $(grep '^http:' <<< $url) ]]
    then
        url=$(sed 's/^http\(.*\)$/https\1/' <<< $url)
    fi

    total=$(curl -k -s $url | grep -o '\/\/i\.4cdn\.org\/.\{1,4\}\/[0-9]\{6,15\}\.[a-z]\{3,4\}' | uniq | wc -l)
    counter=1

    for image_url in $(curl -k -s $url | grep -o '\/\/i\.4cdn\.org\/.\{1,4\}\/[0-9]\{6,15\}\.[a-z]\{3,4\}' | uniq | sed 's/^/https:/')
    do
        echo -n Downloading image $counter of $total...
        wget --no-check-certificate -q -nc $image_url
        echo ' Done'
        counter=$(($counter + 1))
    done
}

#For routing phone audio to my PC where I have my headphones connected so that when someone calls me I hear them thru the headphones

function startcall(){

	#enable usb routing
	adb shell su -c "setprop sys.usb.config \"audio_source,adb\""
	pactl load-module module-loopback latency_msec=1
}

function endcall(){

	adb shell su -c "setprop sys.usb.config \"mtp, adb\""
	pactl unload-module module-loopback
}

stfu() {
	exec "$@" 1>/dev/null 2>/dev/null &
}


function tscreen(){
	if [[ $* == "disable" ]]
	then
		xinput disable 11
	else
		xinput enable 11
	fi
}

### no-out commands ###
alias gedit='stfu gedit'
alias gimp='stfu gimp'
alias firefox='stfu firefox'

parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
### Variables ###

BROWSER=/usr/bin/firefox
EDITOR=vim
export GREP_COLOR="1;32"
export PS1="\[\033[38;5;33m\]\u\[$(tput sgr0)\]\[\033[38;5;45m\]@\[$(tput sgr0)\]\[\033[38;5;27m\]\h\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]\[\033[38;5;6m\][\[$(tput sgr0)\]\[\033[38;5;15m\]\W\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;15m\]\[$(tput sgr0)\]\$(parse_git_branch)\[\033[38;5;6m\]]:\[$(tput sgr0)\] "
### DOCKER commands ###
alias docker_start="sudo systemctl start docker"
alias docker_debian="sudo docker run -it debian /bin/bash"
alias docker_psh="sudo docker run -it microsoft/powershell"

### TERMUX ###
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

if [ -e ~/bash_private.sh ]; then
	. ~/bash_private.sh
fi
