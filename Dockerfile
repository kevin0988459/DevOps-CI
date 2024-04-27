FROM jenkins/jenkins:lts-jdk17

# Switch to root to modify file system
USER root

# Copy jenkins as a code config file into jenkins path
COPY /jcasc.yaml /var/jenkins_home/casc_configs/jcasc.yaml

# Set enviornment variable. see reademe.md in https://github.com/jenkinsci/configuration-as-code-plugin/blob/master
ENV CASC_JENKINS_CONFIG /var/jenkins_home/casc_configs/jcasc.yaml

# Update and install Maven, a specific JDK version, and Ansible
RUN apt-get update && apt-get install -y maven ansible

# Pre-install plugin
RUN jenkins-plugin-cli --plugins json-path-api blueocean-pipeline-api-impl token-macro favorite github blueocean-bitbucket-pipeline blueocean-rest-impl blueocean sonar configuration-as-code

# Add default Ansible inventory file, if necessary
# Note: Adjust this step based on your actual deployment setup and inventory needs
COPY ./ansible/hosts /etc/ansible/hosts

# Ensure proper permissions and ownership
RUN chown -R jenkins:jenkins /var/jenkins_home /etc/ansible


## Modify default jenkins port to avoid conflict with petclinic
## https://www.jenkins.io/doc/book/installing/initial-settings/
## Passing Jenkins launcher parameters: https://github.com/jenkinsci/docker?tab=readme-ov-file
ENV JENKINS_OPTS="--httpPort=8081"

# switch back to user
USER jenkins
