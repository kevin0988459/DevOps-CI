#!/bin/bash

## 1. build jenkins image
docker build -t lab_jenkins:latest .

## 2. Terraform provision IaC
terraform init 
terraform apply -auto-approve


######-------SonarQube------######

## 3. wait for SonarQube server to be up
SONARQUBE_URL="http://localhost:9000"
SONARQUBE_ADMIN_USER="admin"
SONARQUBE_ADMIN_PASS="admin"
TOKEN_NAME="sonar-token"
echo -e "\033[0;36mWaiting for SonarQube server to start...\033[0m"

## Wait sonarqube server ready
while true; do
  RESPONSE=$(curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" "$SONARQUBE_URL/api/system/health")
  HEALTH_STATUS=$(echo $RESPONSE | grep -o '"health":"[^"]*' | awk -F'"' '{ print $4 }')
  if [ "$HEALTH_STATUS" == "GREEN" ]; then
    echo -e "\033[0;32mSonarQube server is up and running\033[0m"
    break
  else
    echo "Waiting for SonarQube server to be ready (average 1 min)..."
    sleep 5
  fi
done

## 4. Generate sonarqube user token
GENERATE_TOKEN_RESPONSE=$(curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" \
  -X POST "$SONARQUBE_URL/api/user_tokens/generate" \
  -d "name=$TOKEN_NAME")

SONARQUBE_TOKEN=$(echo $GENERATE_TOKEN_RESPONSE | grep -o '"token":"[^"]*' | awk -F'"' '{ print $4 }')

if [ ! -z "$SONARQUBE_TOKEN" ]; then
  echo "SonarQube Token: $SONARQUBE_TOKEN"
else
  echo "Token exists, failed to generate SonarQube token."
fi

######-------Systems------######

## 5. reaplce SONAR_TOKEN by overwriting jcasc.yaml
cp jcasc.yaml jcasc.yaml.backup
sed -i '' "s/SONAR_TOKEN/$SONARQUBE_TOKEN/g" jcasc.yaml

## 6. Replace jenkins as a code config file into jenkins path
docker cp jcasc.yaml jenkins:/var/jenkins_home/casc_configs/jcasc.yaml

######-------Jenkins------######
JENKINS_URL="http://localhost:8081"
JENKINS_USER="admin"
JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
JOB_NAME="lab4"
CONFIG_XML_PATH="./config.xml"

## 8. Download Jenkins CLI
echo "Downloading Jenkins CLI..."
curl -O "${JENKINS_URL}/jnlpJars/jenkins-cli.jar"
chmod +r jenkins-cli.jar

## 9. reload Configuration as a Code
java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_USER}:${JENKINS_PASSWORD} reload-jcasc-configuration

## 10. Create the Job
echo "Creating job '${JOB_NAME}'..."
java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_USER}:${JENKINS_PASSWORD} create-job ${JOB_NAME} < ${CONFIG_XML_PATH}

# 11. Trigger the Job
echo "Triggering job '${JOB_NAME}'..."
java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_USER}:${JENKINS_PASSWORD} build ${JOB_NAME} -s -v



echo "##################################################"
echo -e "\n"
echo -e "\033[0;32mPipeline created\033[0m"
echo "Visit http://localhost:8080 to view the petclinc homepage"
echo "Visit http://localhost:8081/blue/organizations/jenkins/lab4/detail/lab4/1/pipeline to visit blueocean, login to jenkins first"
echo "Visit http://localhost:8081 to login to the Jenkins server, the default password is: $JENKINS_PASSWORD"
echo "Visit http://localhost:9000 to login to the Sonaqube server, the default username and password are both admin"
echo -e "\n"
echo "##################################################"


## revoke jcasc.yaml to original template
mv jcasc.yaml.backup jcasc.yaml
