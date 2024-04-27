#########-------ToolingList--------#########
1. Tooling list and version information
    • OS Host: M2 chips macOS 14.1 
    • Virtualizer: Docker 25.0.3
    • MacOS packet manager: Homebrew 4.2.16
    • Provisioning tool: Terraform v1.7.5
    • Jenkins docker image: jenkins/jenkins:lts-jdk17
    • Sonarqube official docker image: sonarqube:latest
    • Shell: Bash

#########-------END--------#########

#########-------Instruction--------#########
1. How to run (please ensure your docker engine is running)
    •$bash lab_pipeline.sh
2. Examine pet-clinic server
    • Read the final output from the terminal, pet-clinic is running on http://localhost:8080
3. Clean Up
    • $terraform destroy
4. Clean up "lab_jenkins" image also
    • $docker rmi lab_jenkins
5. Steps, Provisioning script(main.tf), and automated script(config.xml) is provided below

#########-------END--------#########

#########-------Steps--------#########     
1. Download Homebrew (ignore this if you already have brew)
    • $ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    • $ (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.bash_profile
    • $ eval "$(/opt/homebrew/bin/brew shellenv)"
2. Download Terraform using Homebrew
    • $brew tap hashicorp/tap
    • $brew install hashicorp/tap/terraform
3. Create a new directory HW4 and navigate to it
    • $mkdir HW4
    • $cd HW4
4. Create a terraform file called main.tf
    • $touch main.tf
5. Consigure main.tf, terraform will help you provision two containers. One is jenkins server, the other is SonarQube server.
    • Use VScode open main.tf
    • Copy my main.tf to you main.tf
6. Create a custom jenkins image
    • $touch Dockerfile
7. Configure jenkins Dockerfile, it will pre-install maven, blueocean, sonar-scanner, and Jenkins Configuration as a Code(JCaSC) plugin
    • The code is provided in the "Dockerfile"
8. To fully automate the Jenkins setup, you need to install JCaSC into Jenkins server. JCaSC will read the yaml file and setup Jenkins configuration.
    • $touch jcasc.yaml
9. Configure jcasc.yaml, it will setup the SonarQube crediential, and put the crediential into sonar-scanner.
    • Copy my jcasc.yaml to your jcasc.yaml
10. We will use Pipeline DSL to configure the different stages in the pipeline. The stages include, git clone, build, scan, and run.
    To fully automate the pipeline setup, we'll create config.xml, which include the Pipeline DSL. 
    We will then upload config.xml to the Jenkins Server by Jenkins CLI (in the shell script).
    • $touch config.xml
    • Copy my config.xml to your config.xml
11. Now you have created all the required file. The last step is writing a shell script to fully automate the assignment.
    The script can Run the IaC, configure Jenkins and SonarQube, setup pipline, and execute the pipeline.
    • $touch lab_pipeline.sh
    • Copy my lab_pipeline.sh to your lab_pipeline.sh
    • Step by step explanation is provided in the lab_pipeline.sh file
12. Run the shell script. It will automatically complete the assignment. Pet-clinic is running in the jenkins container
    • $bash lab_pipeline.sh
#########-------END--------#########

#########-------Provisioning script--------#########
terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

#configure shared network
resource "docker_network" "my_network" {
  name = "my_network"
}

#Pulls the jenksins image
resource "docker_image" "lab_jenkins" {
    name = "lab_jenkins:latest"
    # prevent pulling from remote
    keep_locally = true 
}

#Create a jenksins container
resource "docker_container" "jenkins_container" {
    image = docker_image.lab_jenkins.image_id
    name = "jenkins"
    networks_advanced {
      name = docker_network.my_network.name
    }
    ports {
        internal = 8080
        external = 8080
    }
    ports{
        internal = 8081
        external = 8081
    }
}

#Pulls the sonarqube image
resource "docker_image" "sonarqube_image" {
    name = "sonarqube:latest"
}

#Create a sonarqube container
resource "docker_container" "sonarqube_container" {
    image = docker_image.sonarqube_image.image_id
    name = "sonarqube"
    networks_advanced {
      name = docker_network.my_network.name
    }
    ports {
      internal = 9000
      external = 9000
    }
}
#########-------END--------#########

#########-------Automated/shell scripts--------#########
##Jenkins pipeline DSL is mentioned inside config.xml##

pipeline {
    agent any
    stages {
        stage('git clone') {
            steps {
                git branch: 'main', url: 'https://github.com/kevin0988459/spring-petclinic.git'
            }  
            post {
                failure { echo "[*] git clone failure" }
                success { echo '[*] git clone successful' }
            }
        }
        stage('Build') {
            steps { sh './mvnw package' }
        }
        stage('scan') {
            steps {
                withSonarQubeEnv(installationName: 'sonar'){
                    sh './mvnw org.sonarsource.scanner.maven:sonar-maven-plugin:3.7.0.1746:sonar'
                }
            }
        }
        stage('Run') {
            steps {
                withEnv(['JENKINS_NODE_COOKIE=dontkill']) {
                    sh 'nohup java -jar target/*.jar &'
                }
            }
        }
    }
}
#########-------END--------#########

###Reference###
1. Terraform Docker provider documentation
https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs
2. Terraform Docker tutorial
https://developer.hashicorp.com/terraform/tutorials/docker-get-started/install-cli
3. Pre-install sonarqube and blueocean plug-in into the image
https://www.jenkins.io/doc/book/installing/docker/
https://plugins.jenkins.io/sonar/releases/
https://plugins.jenkins.io/blueocean/releases/
4. Unable to download plugins
https://stackoverflow.com/questions/16213982/unable-to-find-plugins-in-list-of-available-plugins-in-jenkins
5. Passing Jenkins launcher parameters for modifing default port:
https://www.jenkins.io/doc/book/installing/initial-settings/
https://github.com/jenkinsci/docker?tab=readme-ov-file
6. Prevent jenkins kills the application
https://stackoverflow.com/questions/75464666/how-to-run-jar-through-jenkins-as-a-separate-process
7. Jenkins as a code
https://medium.com/globant/jenkins-jcasc-for-beginners-819dff6f8bc
https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/demos
8. Jeknins reload Configuration as a code
https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/docs/features/configExport.md