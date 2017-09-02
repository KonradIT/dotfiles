cat ~/.zshrc | sed "s/nik123true/void/g" > ~/.bashrc
curl https://raw.githubusercontent.com/KonradIT/dotfiles/master/bashrc >> ~/.zshrc
git clone https://github.com/konradit/compsci
echo -ne "Enter your git token: "; read token
sudo xbps-install alsa-plugins-pulseaudio cmus-pulseaudio cmus moc notepadqq
wget https://addons.mozilla.org/firefox/downloads/file/685614/ublock_origin-1.13.8-an+fx+sm+tb.xpi -o ublock.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/vimfx/addon-404785-latest.xpi -o vimfx.xpi
gksudo firefox -install-global-extension ublock.xpi
gksudo firefox -install-global-extension vimfx.xpi
wget https://github.com/KonradIT/dotfiles/blob/master/wall/main.png
feh --bg-scale main.png
~/.zshrc
echo "Finished. Close this terminal and open a new one".
