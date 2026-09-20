# home-lab-setup
This is my own home lab setup to use

# Prequisites:
- Docker Engine
- Makefile

## Installation:
1. Docker Engine:
[Tutorial Link (Digital Ocean)](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)
[Tutorial Link (Docker Official Docs)](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)

```bash
    sudo apt update
    sudo apt install ca-certificates curl gnupg

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    apt-cache policy docker-ce

    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl status docker
    
# Add user to docker system
    sudo usermod -aG docker ${USER}
```

2. Makefile