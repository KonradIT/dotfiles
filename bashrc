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
alias mp3='youtube-dl -x --audio-format "mp3" --audio-quality 0 $*'
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
alias nano="vim"
alias gitg='git log --graph --oneline --decorate --all'
alias gs="git status"
alias sf='clear && neofetch -t'
alias screenfetch="neofetch"
alias q="exit"
### DIRS ###
alias d="cd ~/Downloads"
alias gh="cd ~/GitHub"
alias h="cd ~"
alias t="cd ~/Desktop/temp"
alias m="cd /run/media/konrad/3b9877a0-5844-444b-8fa1-00a64be13f19/Downloads/"
alias mocp="mocp; mocp -x"
alias syy="sudo pacman -Syy"
alias syu="sudo pacman -Syu"
alias gpfw="python ~/GitHub/gopro_fw_dl/gopro-fw-dl.py"
alias inotify_increase = "echo fs.inotify.max_user_watches=524288 | sudo tee /etc/sysctl.d/40-max-user-watches.conf && sudo sysctl --system"

### FUNCTIONS ###
convert2insta(){
in="$1"
out="$2"
ffmpeg -i $in -c:v libx264 -strict -2 -c:a aac -ar 44100 -r 30 -pix_fmt yuv420p -shortest $out
}
audio4video(){
in="$1"
music="$2"
out="$3"
ffmpeg -i $in -i $music -codec copy -shortest $out
}

sprunge() {
if [[ $1 ]]; then
curl -F 'sprunge=<-' "http://sprunge.us" <"$1"
else
curl -F 'sprunge=<-' "http://sprunge.us"
fi
}

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

release_gh() {
curl -H "Authorization: token $1" \
-H "Accept: application/vnd.github.manifold-preview" \
-H "Content-Type: application/zip" \
--data-binary @$2 \
"https://uploads.github.com/repos/$4/$5/releases/123/assets?name=$3"
}
function git_gud(){
git add $1
git commit -m $2
git push origin $3
}
linx(){
curl -T "$@" -H "Linx-Randomize: yes" https://linx.li/upload/  
}
weather(){
date
wego -forecast-api-key bf17c0347442c7f7b99bd07f0f864335 -location "40.590,-4.161"
}

function streamable(){
curl https://api.streamable.com/upload -F file=@$1 | python3 -c "import sys, json; print('https://streamable.com/' + json.load(sys.stdin)['shortcode'])"

}

function haste(){
#!/bin/bash

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

### Variables ###


PS1='[\u@\h \W]\$ '
BROWSER=/usr/bin/firefox
EDITOR=vim
export GREP_COLOR="1;32"

export PS1="\[\033[38;5;33m\]\u\[$(tput sgr0)\]\[\033[38;5;45m\]@\[$(tput sgr0)\]\[\033[38;5;27m\]\h\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]\[\033[38;5;6m\][\[$(tput sgr0)\]\[\033[38;5;15m\]\W\[$(tput sgr0)\]\[\033[38;5;6m\]]:\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]"

#### COLORED OUT ###

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
