## Configure

Types of configurations:
1. OpenMRS version (/distro/distro.properties)
2. Backend modules (/distro/distro.properties)
3. Frontend modules (/frontend/spa-build-config.json)
4. Frontend customizations (/frontend/custom-config.json)
5. Metadata (/distro/configuration) 
6. Concepts and content (OCL)

### OpenMRS version
```shell
/distro/distro.properties
```
### Backend modules
```shell
/distro/distro.properties
```
### Frontend modules
```shell
/frontend/spa-build-config.json
```

### Frontend customizations
```shell
/frontend/custom-config.json
```

### Metadata

```shell
# Configurations are loaded through the Initializer module and located in the configuration folder
/distro/configuration
# Configuration files are loaded when restarting OpenMRS and the Docker backend image
restart openmrs-distro-referenceapplication-backend
```

### Concepts and content

Content is organized in OpenConceptLab (OCL), in the [LIME Demo collection](https://app.openconceptlab.org/#/orgs/MSFOCG/collections/lime-demo/ ) and manually exported as ZIP files, then added to the configuration:
```shell
/distro/configuration/OCL
```


## Build
Docker images will automatically be rebuilt and pushed to Docker Hub repository when binaries or configurations are modified. 

### Actions

#### Build Docker images
#### Update documentation

### Branches

<div>
<img src="//raw.githubusercontent.com/MSF-OCG/LIME-EMR-project-demo/main/docs/_media/development-workflow.png" width=80%>
</div>

### Environments 

Dev, QA/UAT, Preprod, prod

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

## Maintain

### Backup

#### Deitentify

### Restore

### Update 

Latest images can be pulled on instances using the Docker command:
```shell
docker-compose pull && docker-compose up -d
```
