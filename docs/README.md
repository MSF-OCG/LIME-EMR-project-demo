# Introduction

> Note: This documentation tends to explain how the OpenMRS 3.x demo for the MSF OCG LIME project is running. It follow stnadards practices from OpenMRS and the community, and goes through the lifecycle of the product. The integration with other dependencies such as [OpenConceptLab (OCL)](https://openconceptlab.org/) and [DHIS2](https://dhis2.org/) is also documented here. 

# Getting started

## Prerequisites
1. Setup Docker on the localhost and hosting instances
2. Get the latest docker-conpose.yml 
3. Run Docker Compose

## File structure
```shell
│ docker-compose.yml # file to run Docker images for the App (docker-compose up -d)
├── distro/ # main folder for OpenMRS backend
│   ├── distro.properties # file to configure OpenMRS version and modules (OMODs)
│   └── configuration/ # folder with metadata loaded with Initializer
└── frontend / # main folder for OpenMRS frontend
    ├── spa-build-config.json # file to configure OpenMRS 3.x frontend properties and modules
    └── custom-config.json # file to configure frontend customizations (visiblity, order, logo, etc.)
```
## Docker Compose

> /docker-compose.yml

```yml
version: "3.7"

services:
  gateway:
    image: openmrs/openmrs-reference-application-3-gateway:${TAG:-nightly}
    depends_on:
      - frontend
      - backend
    ports:
      - "80:80"

  frontend:
    image: openmrs/openmrs-reference-application-3-frontend:${TAG:-nightly}
    environment:
      SPA_PATH: /openmrs/spa
      API_URL: /openmrs
      SPA_CONFIG_URLS: /openmrs/spa/custom-config.json
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      timeout: 5s
    depends_on:
      - backend
    volumes:
      - ./frontend/custom-config.json:/usr/share/nginx/html/custom-config.json

  backend:
    image: michaelbontyes/openmrs3-backend:dev
    depends_on:
      - db
    environment:
      OMRS_CONFIG_MODULE_WEB_ADMIN: "true"
      OMRS_CONFIG_AUTO_UPDATE_DATABASE: "true"
      OMRS_CONFIG_CREATE_TABLES: "true"
      OMRS_CONFIG_CONNECTION_SERVER: db
      OMRS_CONFIG_CONNECTION_DATABASE: openmrs
      OMRS_CONFIG_CONNECTION_USERNAME: ${OPENMRS_DB_USER:-openmrs}
      OMRS_CONFIG_CONNECTION_PASSWORD: ${OPENMRS_DB_PASSWORD:-openmrs}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/openmrs"]
      timeout: 5s
    volumes:
      - openmrs-data:/openmrs/data
      - ./distro/configuration:/openmrs/distribution/openmrs_config

  # MariaDB
  db:
    image: mariadb:10.8.2
    command: "mysqld --character-set-server=utf8 --collation-server=utf8_general_ci"
    healthcheck:
      test: "mysql --user=${OMRS_DB_USER:-openmrs} --password=${OMRS_DB_PASSWORD:-openmrs} --execute \"SHOW DATABASES;\""
      interval: 3s
      timeout: 1s
      retries: 5
    environment:
      MYSQL_DATABASE: openmrs
      MYSQL_USER: ${OMRS_DB_USER:-openmrs}
      MYSQL_PASSWORD: ${OMRS_DB_PASSWORD:-openmrs}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-openmrs}
    volumes:
      - db-data:/var/lib/mysql

volumes:
  openmrs-data: ~
  db-data: ~

```

# Configure

Types of configurations:
1. OpenMRS version (/distro/distro.properties)
2. Backend modules (/distro/distro.properties)
3. Frontend modules (/frontend/spa-build-config.json)
4. Frontend customizations (/frontend/custom-config.json)
5. Metadata (/distro/configuration) 
6. Concepts and content (OCL)

> #### [Diagram representing the types of configuration](https://docs.google.com/drawings/d/1FqoAuYAhWf-P8YAd18wHN-7yRBnAKEkrabBSGOCkWr8/edit?usp=sharing)


## OpenMRS version

> /distro/distro.properties

```shell
name=Ref 3.x distro
version=3.0.0
war.openmrs=${openmrs.version}
```
## Backend modules

> /distro/distro.properties

```shell
omod.initializer=${initializer.version}
omod.fhir2=${fhir2.version}
omod.webservices.rest=${webservices.rest.version}
omod.idgen=${idgen.version}
omod.addresshierarchy=${addresshierarchy.version}
omod.openconceptlab=${openconceptlab.version}
omod.attachments=${attachments.version}
omod.queue=${queue.version}
omod.appointments=${appointments.version}
omod.appointments.groupId=org.bahmni.module
omod.cohort=${cohort.version}
omod.reporting=${reporting.version}
omod.reportingrest=${reportingrest.version}
omod.calculation=${calculation.version}
omod.serialization.xstream=${serialization-xstream.version}
omod.serialization.xstream.type=omod
```
## Frontend modules

> /frontend/spa-build-config.json

```json
{
  "frontendModules": {
    "@openmrs/esm-devtools-app": "next",
    "@openmrs/esm-implementer-tools-app": "next",
    "@openmrs/esm-login-app": "next",
    "@openmrs/esm-offline-tools-app": "next",
    "@openmrs/esm-primary-navigation-app": "next",
    "@openmrs/esm-home-app": "next",
    "@openmrs/esm-form-entry-app": "next",
    "@openmrs/esm-generic-patient-widgets-app": "next",
    "@openmrs/esm-patient-allergies-app": "next",
    "@openmrs/esm-patient-appointments-app": "next",
    "@openmrs/esm-patient-attachments-app": "next",
    "@openmrs/esm-patient-banner-app": "next",
    "@openmrs/esm-patient-biometrics-app": "next",
    "@openmrs/esm-patient-chart-app": "next",
    "@openmrs/esm-patient-conditions-app": "next",
    "@openmrs/esm-patient-forms-app": "next",
    "@openmrs/esm-patient-medications-app": "next",
    "@openmrs/esm-patient-notes-app": "next",
    "@openmrs/esm-patient-programs-app": "next",
    "@openmrs/esm-patient-test-results-app": "next",
    "@openmrs/esm-patient-vitals-app": "next",
    "@openmrs/esm-active-visits-app": "next",
    "@openmrs/esm-appointments-app": "next",
    "@openmrs/esm-outpatient-app": "next",
    "@openmrs/esm-patient-list-app": "next",
    "@openmrs/esm-patient-registration-app": "next",
    "@openmrs/esm-patient-search-app": "next",
    "@openmrs/esm-openconceptlab-app": "next",
    "@openmrs/esm-dispensing-app": "next",
    "@openmrs/esm-fast-data-entry-app": "next",
    "@openmrs/esm-cohort-builder-app": "next",
    "@openmrs/esm-form-builder-app": "next"
  },
  "spaPath": "$SPA_PATH",
  "apiUrl": "$API_URL",
  "configUrls": ["$SPA_CONFIG_URLS"],
  "importmap": "$SPA_PATH/importmap.json"
}

```

## Frontend customizations

> /frontend/custom-config.json

```json
{
    "@openmrs/esm-patient-registration-app": {
      "fieldDefinitions": [
        {
          "id": "referredby",
          "name": "Referred by",
          "type": "person attribute",
          "uuid": "4dd56a75-14ab-4148-8700-1f4f704dc5b0",
          "answerConceptSetUuid": "6682d17f-0777-45e4-a39b-93f77eb3531c",
          "validation": {
            "matches": ""
          }
        }
      ],
      "sectionDefinitions": [
        {
          "id": "additionalDetails",
          "name": "Additional Details",
          "fields": [
            "referredby"
          ]
        }
      ],
      "sections": [
        "demographics",
        "relationships",
        "contact",
        "additionalDetails"
      ],
      "fieldConfigurations": {
        "gender": [
          {
            "id": "male",
            "value": "Male",
            "label": "Male"
          },
          {
            "id": "female",
            "value": "Female",
            "label": "Female"
          },
          {
            "id": "other",
            "value": "Other",
            "label": "Other"
          }
        ]
      }
    }
  }
```

## Metadata


Configurations are loaded through the Initializer module and located in the configuration folder
> /distro/configuration
```shell
# Configuration files are loaded when restarting OpenMRS and the Docker backend image
docker restart lime-emr-project-demo-backend
```

## Concepts and content

Content is organized in OpenConceptLab (OCL), in the [LIME Demo collection](https://app.openconceptlab.org/#/orgs/MSFOCG/collections/lime-demo/ ) and manually exported as ZIP files, then added to the configuration:
> /distro/configuration/OCL


# Build
Docker images will automatically be rebuilt and pushed to Docker Hub repository when binaries or configurations are modified. 

## Actions


### Build Docker images
### Update metadata and content
### Update documentation

## Branches

<div>
<img src="//raw.githubusercontent.com/MSF-OCG/LIME-EMR-project-demo/main/docs/_media/development-workflow.png" width=80%>
</div>

## Environments 

Dev, QA/UAT, Preprod, prod

# Deploy 

## On localhost
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

## In the Cloud

Ansible script to build

## On FiWi 

# Maintain

Type of maintenance activities

| Activity | Comments |
|---|---|
| 1. Backup data and patient files | Automated, nightly, locally on production |
| 2. Synchronize production data with QA and DEV environments | Manual, from GitHub Sync actions |
| 3. Upgrade binaries | Manual, from GitHub Build actions |
| 4. Update metadata and configurations | Manual, from GitHub Build actions |

## Backup

### Deitentify

## Restore

## Update 

Type of updates:
1. Binaries (OpenMRS files) - updated by Build actions
2. Metadata and configuration - updated by Configuration actions
3. Local data update - done manually by project team

Latest images can be pulled on instances using the Docker command:
```shell
docker-compose pull && docker-compose up -d
```
