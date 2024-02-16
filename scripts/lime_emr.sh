#!/bin/sh

# Configurable variables for the application
REPOSITORY_URL="https://github.com/MSF-OCG/LIME-EMR-project-demo.git"
BRANCH_NAME="dev"
APP_NAME="emr"
APP_URL="http://localhost/openmrs/login.htm"
CONTAINER_NAMES="openmrs-db openmrs-frontend openmrs-backend openmrs-gateway"

# List of dependencies to be installed
PACKAGES_TO_INSTALL="git gnupg curl vim mlocate rsync software-properties-common apt-transport-https ca-certificates gnupg2 docker.io"

# Get the current date and time in GMT
current_date_gmt=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Configurable variables for installation and logs
INSTALL_DIR="/home/lime/$APP_NAME"
LOG_DIR="/var/logs/lime"
SUCCESS_LOG="$LOG_DIR/setup-emr-success-$current_date_gmt.log"
ERROR_LOG="$LOG_DIR/setup-emr-stderr-$current_date_gmt.log"
MAX_ATTEMPTS=5
MAX_RETRIES=600
COMPOSE_VERSION="2.23.0"
CONFIG_DIR="$INSTALL_DIR/config"
BACKUP_DIR="/home/backup"
BACKUP_SERVER_CRIDENTIALS="backup@172.24.48.32"

# Get only the current date in GMT
current_date=$(date +"%Y_%m_%d")

# Must remain constant at the moment
OPENMRS_BACKUP_DIR="/openmrs/backup"

# backup and anonymisation configuration
CONTAINER_NAME=openmrs-db
SOURCE_DB=${OMRS_CONFIG_CONNECTION_DATABASE:-openmrs}
TEMP_DB=$SOURCE_DB"_copy"
HAS_PATIENT_FILES=false
MSF_OCG_SAMPLE_EMAIL_KEY="msf.ocg@example.com"
COMPLEX_OBS_DIR="$BACKUP_DIR/complex_obs"
PATIENT_FILES_BACKUP_FILE="patient_files_lime_dc_db_daily_$current_date.tar.gz"
ANONYMISED_PATIENT_FILES_BACKUP_FILE="anonymised_$PATIENT_FILES_BACKUP_FILE"
ANONYMISIND_SCRIPT="$INSTALL_DIR/scripts/anonymization-script.sql"
ANONYMISE_SAMPLE_COMPLEX_OBS="$INSTALL_DIR/scripts/sample-complex-obs"
ENCRYPTED_LOCAL_BACKUP="$BACKUP_DIR/encrypted_lime_dc_db_daily_$current_date.gz.gpg"
ENCRYPTED_REMOTE_PATIENT_FILES_BACKUP_DIR="$OPENMRS_BACKUP_DIR/lime_dc_storage/"
ENCRYPTED_REMOTE_DATABASE_BACKUP_DIR="$OPENMRS_BACKUP_DIR/lime_dc_database/"

# Ensure the log directories and files exist
mkdir -p "$LOG_DIR"

# Function to log success messages
log_success() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] Success: $1" >> "$SUCCESS_LOG"
}

# Function to log error messages
log_error() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] Error: $1" >> "$ERROR_LOG"
}

# Function to remove log file if it is empty
remove_empty_log() {
    local logfile="$1"
    if [ ! -s "$logfile" ]; then # Check if the file is empty
        rm -f "$logfile"
        echo "Removed empty log file: $logfile"
    fi
}

# Function to check if a command exists
command_exists() {
    type "$1" &> /dev/null
}

# Install necessary packages non-interactively
install_packages() {
  # Update the package list
  sudo apt-get update

  # Loop over the packages and attempt to install each one
  for package in $PACKAGES_TO_INSTALL; do
    echo "Installing $package..."
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $package; then
      # If the package is installed successfully, log this to the success log
      log_success "Installed $package"
      echo "$package installed successfully."
    else
      # If there is an error installing the package, log this to the error log
      local error_message="Failed to install $package"
      log_error "$error_message"
      echo "$error_message. See '$ERROR_LOG' for details."
    fi
  done
}

# Check for Docker installation
if command_exists docker; then
    echo "Docker is installed."
    echo "Docker version: $(docker --version)"
    log_success "Docker version $(docker --version) is installed."
    # Check if Docker service is running
    sudo systemctl start docker
    if sudo systemctl is-active --quiet docker; then
        echo "Docker service is running."
        log_success "Docker service is running."
    else
        echo "Docker service is not running."
        log_error "Docker service is not running."
    fi
else
    echo "Docker is not installed."
    log_error "Docker is not installed."
fi

install_docker_compose() {
    # Check if docker-compose is installed
    if ! command_exists docker-compose && ! (command_exists docker && docker compose version &> /dev/null); then
        echo "Docker Compose is not installed. Installing..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        # Check if Docker Compose (docker-compose or docker compose) is installed
        if command_exists docker-compose; then
            echo "Docker Compose (docker-compose) is installed."
            echo "Docker Compose version: $(docker-compose --version)"
            log_success "Docker Compose version $(docker-compose --version) is installed."
        elif command_exists docker && docker compose version &> /dev/null; then
            echo "Docker Compose (docker compose) is integrated into Docker."
            echo "Docker Compose version: $(docker compose version)"
            log_success "Docker Compose version $(docker compose version) is installed."
        else
            echo "Docker Compose installation failed."
            log_error "Docker Compose installation failed."
            return 1
        fi
    else
        log_success "Docker Compose is already installed."
    fi
}

# Function to start docker-compose
start_docker_compose() {
    echo "Starting docker-compose..."
    (cd "$INSTALL_DIR" && docker-compose up -d)
    if [ $? -eq 0 ]; then
        log_success "docker-compose started successfully."
    else
        log_error "Failed to start docker-compose."
    fi
}

# Function to check Docker containers
check_containers() {
    for container in $CONTAINER_NAMES; do
        attempt=1
        while [ $attempt -le $MAX_ATTEMPTS ]; do
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                log_success "Container $container is running."
                break
            else
                if [ $attempt -eq $MAX_ATTEMPTS ]; then
                    log_error "Container $container failed to run after $MAX_ATTEMPTS attempts."
                    return 1
                fi
                echo "Attempt $attempt of $MAX_ATTEMPTS: Container $container is not running."
                attempt=$((attempt+1))
                sleep 5
            fi
        done
    done
    return 0
}

# Function to verify the application URL is available
verify_application_url() {
    attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        http_status=$(curl -o /dev/null -s -w "%{http_code}\n" -I "$APP_URL")
        if [ "$http_status" -eq 200 ]; then
            log_success "The application at $APP_URL is reachable."
            return
        else
            echo "Attempt $attempt of $MAX_RETRIES: The application at $APP_URL is not reachable. Status: $http_status"
            if [ $attempt -eq $MAX_RETRIES ]; then
                log_error "Failed to reach the application at $APP_URL after $MAX_RETRIES attempts."
                return 1
            fi
            sleep 10
            attempt=$((attempt+1))
        fi
    done
}

# Function to clone the repository and handle updates
clone_repository() {
    if [ ! -d "$INSTALL_DIR/.git" ]; then
        echo "Cloning the repository branch '$BRANCH_NAME' into $INSTALL_DIR."
        git clone --single-branch --branch "$BRANCH_NAME" "$REPOSITORY_URL" "$INSTALL_DIR" && log_success "Cloned the '$BRANCH_NAME' branch of the repository into $INSTALL_DIR." || log_error "Failed to clone the '$BRANCH_NAME' branch of the repository into $INSTALL_DIR."
    else
        echo "Repository already cloned. Checking for updates..."
        (cd "$INSTALL_DIR" && git pull origin "$BRANCH_NAME") && log_success "Updated the '$BRANCH_NAME' branch of the repository in $INSTALL_DIR." || log_error "Failed to update the '$BRANCH_NAME' branch of the repository in $INSTALL_DIR."
    fi
}

# Function to determine the branch name based on the hostname
get_branch_name() {
    local last_char=$(hostname | awk '{print tolower(substr($0,length,1))}')
    case "$last_char" in
        d) BRANCH_NAME="dev";;
        t) BRANCH_NAME="qa";;
        p) BRANCH_NAME="main";;
        *)
          BRANCH_NAME="main"
          log_error "Hostname does not end with D, T, or P. Using default branch 'main'."
          ;;
    esac
    log_success "Branch name set to '$BRANCH_NAME' based on the hostname."
}

# Update application function
install_application() {
  # Implement installation logic
  echo "Installating application..."
    if install_packages && install_docker_compose && clone_repository && start_docker_compose && check_containers && verify_application_url; then
        log_success "Application installation completed successfully."
        echo "Installation completed successfully."
    else
        log_error "Application installation failed."
        echo "Installation failed. Check the logs for details."
        return 1 # Return from the function with an error status
    fi
}

# Generates a MySQL database backup command.
compress_database() {
    database="$1"
    output_file="$2"
    command="mysqldump --max_allowed_packet=51012M --user=root --password=${MYSQL_ROOT_PASSWORD:-openmrs} $database --skip-lock-tables --single-transaction --skip-triggers | gzip -v -f > $output_file"
    echo "$command"
}

# Executes a MySQL database command.
execute_database() {
    arguments="$@"
    command="mysql --user=root --password=${MYSQL_ROOT_PASSWORD:-openmrs} -e \"$arguments\""
    echo "$command"
}

# Backup function
backup_application() {

    # check if daily backup exists
    if [ -d "$BACKUP_DIR" ]; then 
        echo "clearing backup directory"
        rm -rf "$BACKUP_DIR/*"
    else
        echo "creating backup directory"
        mkdir "$BACKUP_DIR"
    fi;

    if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
        echo "Container $CONTAINER_NAME is not running."
        log_error "Container $CONTAINER_NAME is not running."
        start_docker_compose
    fi

    echo "Copying anonymisation scripts to the $CONTAINER_NAME container"
    docker cp $ANONYMISIND_SCRIPT $CONTAINER_NAME:/usr/bin
    log_process_status "Copying anonymisation scripts to the $CONTAINER_NAME container completed successfully!" \
        "Error: Copying anonymisation scripts to the $CONTAINER_NAME container failed!"

    echo "Creating dump in $CONTAINER_NAME Container"

    docker exec $CONTAINER_NAME /bin/sh -c "\
        COMPRESSED_DUMP_FILE=$OPENMRS_BACKUP_DIR/lime_dc_db_daily_$current_date.sql.gz; \
        if [ ! -d "$OPENMRS_BACKUP_DIR/" ]; then \
            echo 'Database dump directory does not exist hence creating it'; \
            mkdir -p $OPENMRS_BACKUP_DIR/; \
        else \
            echo 'Found Database dump directory hence clearing it'; \
            rm -rf $OPENMRS_BACKUP_DIR/*; \
        fi \

        $(compress_database "$SOURCE_DB" "$OPENMRS_BACKUP_DIR/lime_dc_db_daily_$current_date.sql.gz"); \
        echo 'Attempting to decompress database dump: '; \
        gunzip -v -k -f \$COMPRESSED_DUMP_FILE; \
        SQL_DUMP_FILE=\$(ls $OPENMRS_BACKUP_DIR/lime_dc_db*.sql); \

        echo 'creating temp database'; \
        $(execute_database "DROP DATABASE IF EXISTS $TEMP_DB;" "CREATE DATABASE $TEMP_DB;");\

        echo 'Dumping and anonymising data into temp database'; \
        $(execute_database "USE $TEMP_DB;" "source \$SQL_DUMP_FILE;" "source /usr/bin/anonymization-script.sql;");\

        echo 'Compressing Anonymised temp database'; \
        $(compress_database "$TEMP_DB" "$OPENMRS_BACKUP_DIR/anonymised_lime_dc_db_daily_$current_date.sql.gz"); \

        echo 'Cleaning up temp database'; \
        rm -rf \$SQL_DUMP_FILE;\
        $(execute_database "DROP DATABASE IF EXISTS $TEMP_DB;");\
    "

    log_process_status "Creating database dump in $CONTAINER_NAME completed successfully!" "Error: creating database dump in $CONTAINER_NAME failed!"

    echo "Copying both anonymised backup and non anonymised backup"
    docker cp $CONTAINER_NAME:$OPENMRS_BACKUP_DIR/ /home 
    log_process_status "Copying files from $CONTAINER_NAME to host completed successfully!" "Error: copying files from $CONTAINER_NAME to host failed!"
    
    echo "copying and anonymising patient files"
    docker exec openmrs-backend /bin/sh -c "\
        if [ -d "/openmrs/data/complex_obs/" ]; then \
            echo 'patient files present'; \
            exit 0; \
        else \
            echo 'patient files abscent'; \
            exit 1; \
        fi \
    " && HAS_PATIENT_FILES=true

    if [ "$HAS_PATIENT_FILES" = true ]; then
        anonymise_patient_Files
        log_process_status "Anonymisng patient files completed successfully!" "Error: anonymisng patient files failed!"
    fi

    echo "Encrypting database backup to a single file"
    encrypt_database
    log_process_status "Encryption completed successfully!" "Error: encryption failed!"

    echo "cleaning backup"
    rm -rf $BACKUP_DIR/*lime_dc_db_daily*$current_date.*.gz

    echo "cleaning $CONTAINER_NAME container"
    docker exec $CONTAINER_NAME /bin/sh -c "rm -rf /openmrs/"
    log_process_status "Cleaning $CONTAINER_NAME container completed successfully!" "Error: cleaning $CONTAINER_NAME container failed!"

    echo "synchronizing database dump to backup server"
    sync_to_remote_lime "$BACKUP_DIR/lime_dc_db_daily_$current_date.sql.gz.gpg" "$ENCRYPTED_REMOTE_DATABASE_BACKUP_DIR"
    sync_to_remote_lime "$BACKUP_DIR/anonymised_lime_dc_db_daily_$current_date.sql.gz.gpg" "$ENCRYPTED_REMOTE_DATABASE_BACKUP_DIR"
    if [ "$HAS_PATIENT_FILES" = true ]; then
        sync_to_remote_lime "$BACKUP_DIR/$PATIENT_FILES_BACKUP_FILE.gpg" "$ENCRYPTED_REMOTE_PATIENT_FILES_BACKUP_DIR"
        sync_to_remote_lime "$BACKUP_DIR/$ANONYMISED_PATIENT_FILES_BACKUP_FILE.gpg" "$ENCRYPTED_REMOTE_PATIENT_FILES_BACKUP_DIR"
    fi

}

anonymise_patient_Files() {
    if [ "$HAS_PATIENT_FILES" = true ]; then
        echo "Found patient files in system"
        docker cp openmrs-backend:/openmrs/data/complex_obs/ $BACKUP_DIR
        
        echo "Backing up patient files"
        tar -zcvf $BACKUP_DIR/$PATIENT_FILES_BACKUP_FILE $BACKUP_DIR/complex_obs
        log_process_status "Backing up patient files completed successfully!" "Error: backing up patient files failed!"

        # Loop through each file in the directory
        for patient_file in "$COMPLEX_OBS_DIR"/*; do
            if [ -f "$patient_file" ]; then
                patient_file_name=$(basename -- "$patient_file")
                # Anonymize the file by replacing it with our sample file
                cp "$ANONYMISE_SAMPLE_COMPLEX_OBS" "${COMPLEX_OBS_DIR}/${patient_file_name}"
                echo "Anonymized file: $patient_file_name"
            fi
        done
        echo "Anonymising patient files"
        tar -zcvf $BACKUP_DIR/$ANONYMISED_PATIENT_FILES_BACKUP_FILE $BACKUP_DIR/complex_obs
        log_process_status "Anonymising patient files completed successfully!" "Error: anonymising patient files failed!"

        rm -rf $BACKUP_DIR/complex_obs
    else
        echo "No patient files found in system"
    fi
}

# ecnryption application functions
encrypt_database() {
    if ! command_exists gpg ; then 
        echo "gpg not installed attempting to install it."
        install_packages
    fi
    
    echo "checking for presence of the sample msf-ocg key"
    # note that the MSF_OCG_SAMPLE_EMAIL_KEY is msf.ocg@example.com'
    if ! gpg -K $MSF_OCG_SAMPLE_EMAIL_KEY | grep -E '*msf\.ocg@example\.com' >/dev/null; then
        echo "No GPG key with the email '$MSF_OCG_SAMPLE_EMAIL_KEY' found, hence creating a new one"
        gpg --batch --passphrase '' --quick-gen-key $MSF_OCG_SAMPLE_EMAIL_KEY
    fi

    echo "Encryptig database backup"
    gpg --batch --yes --encrypt-files --recipient $MSF_OCG_SAMPLE_EMAIL_KEY $BACKUP_DIR/*lime_dc*$current_date.*.gz
}

# function to sync the backup archive to a remote destination
sync_to_remote_lime() {
    source_path=$1
    remote_destination=$2

    echo "Syncing $source_path to $BACKUP_SERVER_CRIDENTIALS:$remote_destination..."
    rsync --delete $source_path $BACKUP_SERVER_CRIDENTIALS:$remote_destination
    log_process_status "Synchronizing database dump to backup server completed successfully!" "Error: synchronizing database dump to backup server failed!"
}

# logging previous command function
log_process_status() {
    if [ $? -eq 0 ]; then
        echo "$1"
        log_success "$1"
    else
        echo "$2"
        log_error "$2"
        exit 1
    fi
}

# Update application function
update_application() {
  # Implement update logic
  echo "Updating application..."
  # Update commands to be added
}

# Uninstall application function
uninstall_application() {
  echo "Uninstalling application..."

  # Navigate to the Docker Compose directory
  cd "$INSTALL_DIR" || { echo "Failed to enter directory $INSTALL_DIR"; exit 1; }

  # Stop and remove containers, networks, and volumes created by `docker-compose up`
  echo "Stopping services and removing containers, networks, and volumes..."
  docker-compose down -v || { echo "Failed to remove containers, networks, and volumes."; exit 1; }

  # Remove application files after stopping Docker services
  echo "Removing application files..."
  rm -rf "$INSTALL_DIR" || { echo "Failed to remove application files."; exit 1; }

  # Remove logs
  echo "Removing log files..."
  rm -rf $LOG_DIR/* || { echo "Failed to remove log files."; exit 1; }

  echo "Application uninstalled successfully."
}

# Check the command line argument and call the appropriate procedure
case "$1" in
  "install")
    install_application
    ;;
  "update")
    update_application
    ;;
  "backup")
    backup_application
    ;;
  "uninstall")
    uninstall_application
    ;;
  *)
    echo "Invalid procedure. Please specify 'install', 'update', or 'backup'."
    exit 1
    ;;
esac
