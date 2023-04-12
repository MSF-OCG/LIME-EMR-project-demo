# MSF-OCG LIME EMR Project - OpenMRS 3.x demo
<div>
<img src="https://www.msf.org/themes/custom/msf_theme/ogimage.jpg" width=300px>
<img src="https://raw.githubusercontent.com/MSF-OCG/lime-project/main/documentation/MSF_LIMEProject_logo_CMJN_full.png" width=300px>
</div>


## Configure

### Backend modules
```shell
/distro/distro.properties
```
### Frontend modules
```shell
/frontend/spa-build-config.json
```
### Configurations and content
```shell
/distro/configuration
```

## Build
Docker images will automatically be rebuilt and pushed to Docker Hub repository when binaries or configurations are modified. 

## Deploy 

### From localhost
```shell
# SSH Azure instance via jumphost
ssh username@msf-ocg-openmrs3-dev.westeurope.cloudapp.azure.com -p 22222
# switch to sudo privileges
sudo su
# Start OpenMRS
docker-compose up -d
# Verify that OpenMRS services are running
docker ps
# IF docker-compose file is missing, download configuration, then start OpenMRS
curl https://raw.githubusercontent.com/openmrs/openmrs-distro-referenceapplication/main/docker-compose.yml > docker-compose.yml 
# Verify that the web app is available
http://msf-ocg-openmrs3-dev.westeurope.cloudapp.azure.com 
# All done!
```
## Update 

Latest images can be pulled on instances using the Docker command:
```shell
docker-compose pull && docker-compose up -d
```
