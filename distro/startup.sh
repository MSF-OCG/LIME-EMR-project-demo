apt-get -y update

apt-get -y install ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get -y install git
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

git init
git remote add origin https://github.com/MSF-OCG/LIME-EMR-project-demo.git
git checkout -b 'dev'
git config core.sparsecheckout true
echo distro/ >> .git/info/sparse-checkout
git pull origin dev

docker compose -f distro/docker-compose.yml pull
docker compose -f distro/docker-compose.yml up -d 