#!/bin/bash

# Atualizar pacotes
sudo yum update -y

# Instalar Docker
sudo yum install docker -y

# Iniciar e habilitar o Docker
sudo service docker start
sudo systemctl enable docker

# Adicionar o usuário ec2-user ao grupo docker
sudo usermod -a -G docker ec2-user

#Instalar o Docker Compose
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Reiniciar Docker para garantir que as mudanças entrem em vigor
sudo service docker restart

# Instalar NFS client
sudo yum install -y nfs-utils

#Montar EFS na instancia
mkdir -p /mnt/efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport <EFS_DNS_NAME>:/ /mnt/efs

# Configurar Docker Compose
cd /home/ec2-user
cat <<EOF > docker-compose.yml
version: '3.1'

services:
  wordpress:
    image: wordpress:latest
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: <SEU_RDS_ENDPOINT>
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: <SEU_DB_PASSWORD>
      WORDPRESS_DB_NAME: <NOME_DO_SEU_DB>
    volumes:
      - wp_data:/var/www/html

volumes:
  wp_data:
    driver: local
    driver_opts:
      type: "nfs"
      o: addr=<EFS_DNS_NAME>,rw,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport
      device: ":/"
EOF

docker-compose -f /home/ec2-user/docker-compose.yml up -d