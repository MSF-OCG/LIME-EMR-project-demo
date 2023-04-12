<div>
<img src="https://www.msf.org/themes/custom/msf_theme/ogimage.jpg" width=300px>
<img src="https://raw.githubusercontent.com/MSF-OCG/LIME-EMR-project-demo/main/documentation/MSF_LIMEProject_logo_CMJN_full.png" width=300px>
</div>


## Configure

Types of configurations:
1. OpenMRS version (/distro/distro.properties)
2. Backend modules (/distro/distro.properties)
3. Frontend modules (/frontend/spa-build-config.json)
4. Frontend customizations (/frontend/custom-config.json)
5. Metadata (/distro/configuration) 
6. Concepts and content (OCL)

### 1. OpenMRS version
```shell
/distro/distro.properties
```
### 2. Backend modules
```shell
/distro/distro.properties
```
### 3. Frontend modules
```shell
/frontend/spa-build-config.json
```

### 4. Frontend customizations
```shell
/frontend/custom-config.json
```

### 5. Metadata

```shell
# Configurations are loaded through the Initializer module and located in the configuration folder
/distro/configuration
# Configuration files are loaded when restarting OpenMRS and the Docker backend image
restart openmrs-distro-referenceapplication-backend
```

### 6. Concepts and content

Content is organized in OpenConceptLab (OCL), in the [LIME Demo collection](https://app.openconceptlab.org/#/orgs/MSFOCG/collections/lime-demo/ ) and manually exported as ZIP files, then added to the configuration:
```shell
/distro/configuration/OCL
```


## Build
Docker images will automatically be rebuilt and pushed to Docker Hub repository when binaries or configurations are modified. 

### Actions

Build, push, tag

### Branches

Dev, QA, Prod

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

In case of 


