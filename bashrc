#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
BROWSER=/usr/bin/firefox
EDITOR=vim
alias listw='iwlist wlp6s0 scan'
alias fuck='sudo $(history -p \!\!)'
alias wearconnect='adb forward tcp:4444 localabstract:/adb-hub; adb connect localhost:4444'
alias up='cd ..'
alias app="sudo pacman -S $1"
alias sniff="sudo tcpdump | grep $*"
alias wake_gp='wol -i 10.5.5.9 -p 9 $*'
alias s2p='kdeconnect-cli -d $1 --ping-msg $2'
alias rmdb='sudo rm /var/lib/pacman/db.lck'
alias fixmyshitup='sudo rm /var/lib/pacman/db.lck; sudo pacman -Syy'
alias trello='~/trello-cli/bin/trello'
alias cmusl='cmus --listen 0.0.0.0'
streaming() {
INRES="1920x1080" # input resolution
OUTRES="1920x1080" # output resolution
FPS="15" # target FPS
GOP="30" # i-frame interval, should be double of FPS, 
GOPMIN="15" # min i-frame interval, should be equal to fps, 
THREADS="2" # max 6
CBR="1000k" # constant bitrate (should be between 1000k - 3000k)
QUALITY="ultrafast"  # one of the many FFMPEG preset
AUDIO_RATE="44100"
STREAM_KEY="$1" # use the terminal command Streaming streamkeyhere to stream your video to twitch or justin
SERVER="live-fra" # twitch server in frankfurt, see http://bashtech.net/twitch/ingest.php for list
                                                                 
ffmpeg -f x11grab -s "$INRES" -r "$FPS" -i :0.0 -f alsa -i pulse -f flv -ac 2 -ar $AUDIO_RATE \
-vcodec libx264 -g $GOP -keyint_min $GOPMIN -b:v $CBR -minrate $CBR -maxrate $CBR -pix_fmt yuv420p\
-s $OUTRES -preset $QUALITY -tune film -acodec libmp3lame -threads $THREADS -strict normal \
-bufsize $CBR "rtmp://$SERVER.twitch.tv/app/$STREAM_KEY"
}

alias simplenotelist="vim -c 'Simplenote -l'"
alias pebblejs="git clone https://github.com/pebble/pebblejs.git"
alias mp3='youtube-dl -x --audio-format "mp3" $*'
alias simplenote="vim -c 'Simplenote -n'"
alias sf2p='kdeconnect-cli -d 9e5ef0501c24e522 --share $*'
alias webserver='python3 -m http.server'
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
alias media="printf 'covert2insta - converts video to instagram format\n\tconvert2insta video.mkv insta.mov\naudio4video - adds audio layer to video\n\taudio4video video.mp4 song.mp3 out.mp4\nmp3 - downloads youtube in mp3 format\n'"
alias diff='diff --color=auto'
alias grep='grep --color=auto'
export GREP_COLOR="1;32"
alias ls='ls --color=auto'
export PS1="\[\033[38;5;33m\]\u\[$(tput sgr0)\]\[\033[38;5;45m\]@\[$(tput sgr0)\]\[\033[38;5;27m\]\h\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]\[\033[38;5;6m\][\[$(tput sgr0)\]\[\033[38;5;15m\]\W\[$(tput sgr0)\]\[\033[38;5;6m\]]:\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]"
sprunge() {
  if [[ $1 ]]; then
    curl -F 'sprunge=<-' "http://sprunge.us" <"$1"
  else
    curl -F 'sprunge=<-' "http://sprunge.us"
  fi
}
alias todo='python3 ~/todo $*'
alias sshpi='ssh pi@192.168.1.60'
export GOPROPATH=/run/media/konrad/8765-4321/DCIM
