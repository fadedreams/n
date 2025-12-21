```
sudo pacman -Syu 7zip
sudo apt install 7zip
7z a -p -mhe=on n.7z ~/.cng/n

cd ~
curl -L -o n.7z https://github.com/fadedreams/n/releases/download/v1.0/n.7z && 7z x -y n.7z -o.config/ && rm n.7z
```
