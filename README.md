# Deploy de WordPress com Docker, AWS RDS e AWS EFS

<p>Configuração de site WordPress dockerizado de forma automatizada com utilização de serviços AWS</p>

---

### Objetivos

1. instalação e configuração do DOCKER ou CONTAINERD no host EC2;
2. Efetuar Deploy de uma aplicação Wordpress com container de aplicação RDS database Mysql;
3. configuração da utilização do serviço EFS AWS para estáticos do container de aplicação Wordpress;
4. configuração do serviço de Load Balancer AWS para a aplicação Wordpress;

#### Pontos Importantes

* não utilizar ip público para saída do serviços WordPress (Evitem publicar o serviço WP via IP Público)
* sugestão para o tráfego de internet sair pelo LB (Load Balancer Classic)
* pastas públicas e estáticos do wordpress sugestão de utilizar o EFS (Elastic File Sistem)
* Aplicação Wordpress precisa estar rodando na porta 80 ou 8080;

#### Tecnologias utilizadas

* Amazon EC2 
* Amazon VPC
* Amazon RDS
* Amazon EFS
* Docker

<div align="center">
    <img src="src/wp_architecture.png" />
    <p><em>Arquitetura do serviço</em></p>
</div>

---

### Criando VPC

Primeiro irei criar a VPC onde irá ficar todos os serviços.

<div align="center">
    <img src="src/vpc.png" />
    <p><em>Arquitetura do VPC</em></p>
</div>

* Foi colocado NAT gateway na VPC para que a instância em uma subnet privada possa acessar a internet, porém não o inverso.

---

### Criando Security Group

Agora irei criar o Security Group para a instancia, EFS, RDS e Load Balancer.

<div align="center">
    <img src="src/ec2-sg.png" />
    <p><em>Security Group do EC2</em></p>
</div>

<div align="center">
    <img src="src/efs-sg.png" />
    <p><em>Security Group do EFS</em></p>
</div>

<div align="center">
    <img src="src/rds-sg.png" />
    <p><em>Security Group do RDS</em></p>
</div>

<div align="center">
    <img src="src/lb-sg.png" />
    <p><em>Security Group do Load Balancer</em></p>
</div>

---


### Criando EC2 Connect Endpoint

Depois vamos criar um EC2 Connect Endpoint para que possamos conectar nas instancias privadas.
* Adicione o VPC no endpoint
* Coloque alguma Subnet da VPC
* Coloque o mesmo Security Group do EC2

<p>À primeira vista não precisaremos utilizar o Endpoint, pois não precisaremos conectar na instância para configurá-la, mas foi criado caso precise.</p>

---

### Criando Elastic File System (EFS)

Para a criação do EFS basta ir até o serviço no portal AWS e localizar onde está escrito "Create file System".

<div align="center">
    <img src="src/efs-create.png" />
</div>

* Feito isso clique em "Customize".
* Coloque o tipo de File System "Regional".
* Na parte de Network Access, altere as opções de Mount Target e adicione o SG que criamos para o EFS nas duas Subnets privadas que criamos na VPC.

<div align="center">
    <img src="src/mount-targets.png" />
    <p><em>Mount Targets do EFS</em></p>
</div>

---

### Criando Relational Database Service (RDS)

Para criar o RDS, basta ir até o serviço e clicar em "Create database".

Vamos Criar o RDS com as seguintes características:

* **Tipo de Engine**: MySQL
* **Versão da Engine**: 8.0.35
* **Template**: Free Tier
* **Configuração da Instância**: db.t3.micro
* **Armazenamento**: 
    * gp3
    * 20GB
* **Conectividade**:
    * **VPC**: <"Sua VPC">
    * **Public Access**: Não
    * **VPC Security Group**: RDS-sg (VPC que criamos em [Criando Security Group](#criando-security-group))
* **Autenticação**: Password authentication

Em Configurações Adicionais (Additional configuration), vá até "Nome inicial do banco de dados"(Initial database name) e coloque o nome que você desejar no banco de dados.

---

### Criando Launch Template

Agora iremos criar um Launch Template para futuramente criar um Auto Scalling Group.

##### Caracteristicas da instância:

* **AMI**: Amazon Linux 2023 AMI
* **Arquitetura**: 64-bit(x86)
* **Instance Type**: t3.small
* **Key Pair**: Seu Par de chaves (se não tiver clique em "Create new key pair")
* **Networking Settings**:
    * **VPC**: <"Sua VPC">
    * **Subnet**: Não colocar no Template
    * **Security Group**: Seu SG (criado em [Criando Security Group](#criando-security-group))
* **Armazenamento**: 20GB gp3
* **Detalhes Avançados**: Em detalhes avançados você irá até User data e adicionará o arquivo [user_data.sh](/user_data.sh) que se encontra neste repositório. Todo o código irá instalar o Docker, Docker Compose e o NFS e em sequencia irá fazer a montagem do EFS na intância e depois disso configurar o `docker-compose.yml` para criar o container e iniciá-lo.

### Criando Auto Scalling Group

1. **Nome do Auto Scalling Group**: <*NOME QUE VOCÊ DESEJAR*>
2. **Launch Template**: Escolha a que criamos
3. **Network**:

    <div align="left">
        <img src="src/asg.png" />
        <p><em>Note-se que escolhemos a VPC que criamos e as Subnets que o Auto Scalling Group irá utilizar serão somente as privadas.</em></p>
    </div>
4. **Load Balancer**: Iremos deixar sem Load Balancer no momento.
5. **Capacidade desejada do grupo**: 2
6. **Scalling limits**: Minimo: 2 | Maximo: 4
---

### Criando Classic Load Balancer

1. **Nome**: <*Nome que desejar*>
2. **Scheme**: Voltado para a internet
3. **VPC**: <*VPC que criamos*>
    * Em **Mapeamento** iremos escolher as duas AZ's da VPC e iremos escolher a subnet pública de cada AZ para que possamos acessar a instância.
        <div align="left">
            <img src="src/lb.png" />
            <p><em></em></p>
        </div>
4. **Security Group**: <*Security Group que criamos para o LB*>
5. **Listener and Routing**:
        <div align="left">
            <img src="src/listener.png" />
            <p><em></em></p>
        </div>
6. **Health Checks**: Seguir configuração da imagem abaixo.
        <div align="left">
            <img src="src/health-check.png" />
            <p><em>Lembre-se que o Ping Path deverá ser o `/readme.html`</em></p>
        </div>
7. **Instances**: Adicione as instâncias que o Auto Scalling Group criou.
---
#### Feito isso, vá até o Auto Scalling Group novamente e irá editá-lo.
<div align="center">
    <img src="src/asg-lb.png">
    <p><em>Adicione seu Clasic Load Balancer no Auto Scalling Group.</em></p>
</div>

---
Para acessar o Wordpress, basta utilizar o DNS do Load Balancer.

<div align="center">
    <img src="src/lb-dns.png">
    <p><em></em></p>
</div>

---