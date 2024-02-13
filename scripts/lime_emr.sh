#!/bin/sh

# Configurable variables for the application
REPOSITORY_URL="https://github.com/MSF-OCG/LIME-EMR-project-demo.git"
BRANCH_NAME="main"
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

CONTAINER_NAME=openmrs-db
SOURCE_DB=${OMRS_CONFIG_CONNECTION_DATABASE:-openmrs}
TEMP_DB=$SOURCE_DB"_copy"

# backup and anonymisation configuration
ANONYMISE_FOLDER_PATH="$INSTALL_DIR/scripts/anonymization-script.sql"
ENCRYPTED_LOCAL_BACKUP_FILE="$BACKUP_DIR/encrypted_lime_dc_db_daily_$current_date.gz.gpg"
ENCRYPTED_REMOTE_BACKUP_DIR="/openmrs/backup/lime_dc_storage/"

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
function install_packages() {
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
    command="/usr/bin/mysqldump --max_allowed_packet=51012M --user=root --password=${MYSQL_ROOT_PASSWORD:-openmrs} $database --skip-lock-tables --single-transaction --skip-triggers | gzip -v -f > $output_file"
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
    if [ ! -d "$BACKUP_DIR" ]; then 
        echo "clearing backup directory"
        rm -rf "$BACKUP_DIR/*"
    else
        echo "creating backup directory"
        mkdir "$BACKUP_DIR"
    fi;

    echo "Copying anonymisation scripts to the $CONTAINER_NAME container"
    docker cp $ANONYMISE_FOLDER_PATH $CONTAINER_NAME:/usr/bin
    log_process_status "Copying anonymisation scripts to the $CONTAINER_NAME container completed successfully!" \
        "Error: Copying anonymisation scripts to the $CONTAINER_NAME container failed!"

    echo "Checking for dump in the $CONTAINER_NAME Container"

    docker exec $CONTAINER_NAME /bin/sh -c "\
        COMPRESSED_DUMP_FILE=/openmrs/backup/lime_dc_db_daily_$current_date.sql.g; \
        if [ ! -d "/openmrs/backup/" ]; then \
            echo 'Database dump Directory does not exist hence creating it'; \
            mkdir -p /openmrs/backup/; \
        else \
            echo 'Found Database dump replacing it'; \
            COMPRESSED_DUMP_FILE=\$(ls /openmrs/backup/lime_dc_db*.gz); \
            rm -rf \$COMPRESSED_DUMP_FILE; \
        fi; \
        echo 'creating databaas dump created '; \
        $(compress_database "$SOURCE_DB" "/openmrs/backup/lime_dc_db_daily_$current_date.sql.gz"); \
        echo 'anonymising database dump: '; \
        $(antonymize_database \$COMPRESSED_DUMP_FILE);\
    "
    log_process_status "Creating database dump in $CONTAINER_NAME completed successfully!" "Error: creating database dump in $CONTAINER_NAME failed!"

    echo "Copying both anonymised backup and non anonymised backup"
    docker cp $CONTAINER_NAME:/openmrs/backup/ $BACKUP_DIR | encrypt_database
    log_process_status "Copying files from $CONTAINER_NAME to host completed successfully!" "Error: copying files from $CONTAINER_NAME to host failed!"

    echo "cleaning $CONTAINER_NAME container"
    docker exec $CONTAINER_NAME /bin/sh -c "rm -f /openmrs"
    log_process_status "Cleaning $CONTAINER_NAME container completed successfully!" "Error: cleaning $CONTAINER_NAME container failed!"

    echo "synchronizing database dump to backup server"
    sync_to_remote_lime "$ENCRYPTED_LOCAL_BACKUP_FILE" "$ENCRYPTED_REMOTE_BACKUP_DIR"
}

# Database anonymization
antonymize_database() {
    compressed_database="$1"
    echo 'Attempting to decompress database dump: '; \
    gunzip -v -k -f \$compressed_database; \
    SQL_DUMP_FILE=\$(ls /openmrs/backup/lime_dc_db*.sql); \

    echo 'creating temp database'; \
    $(execute_database "DROP DATABASE IF EXISTS $TEMP_DB;" "CREATE DATABASE $TEMP_DB;");\

    echo 'Dumping and anonymising data into temp database'; \
    $(execute_database "USE $TEMP_DB;" "source \$SQL_DUMP_FILE;" "source /usr/bin/anonymization-script.sql;");\

    echo 'Compressing Anonymised temp database'; \
    $(compress_database "$TEMP_DB" "/openmrs/backup/anonymised_lime_dc_db.$current_date.sql.gz"); \

    echo 'Cleaning up temp database'; \
    rm -rf \$SQL_DUMP_FILE;\
    $(execute_database "DROP DATABASE IF EXISTS $TEMP_DB;");\
    log_process_status "Database anonymisation completed successfully!" "Error: database anonymisation failed!"
}

# ecnryption application functions
encrypt_database() {
    if ! command_exists gpg ; then 
        echo "gpg not installed attempting to install it."
        install_packages
    fi
    
    echo "checking for presence of the sample msf-ocg key"
    if ! gpg -K msf.ocg@example.com | grep -E '*msf\.ocg@example\.com' >/dev/null; then
        echo "No GPG key with the email 'msf.ocg@example.com' found, hence creating a new one"
        # gpg --quick-generate-key --batch "MSF OCG (MSF OCG LIME encryption key) <msf.ocg@example.com" default default 
        gpg --batch --passphrase '' --quick-gen-key msf.ocg@example.com
    fi

    # encrupt the comporessed datanases 
    # gpg --require-compliance --encrypt -r msf.ocg@example.com --batch --yes -o file.dat.gpg file.dat
    
    # Encrypt the contents of directory ‘$BACKUP_DIR’ for user msf.ocg@example.com to file ‘$BACKUP_DIR’:
    echo "Encryptig database backups and patient files to a single file"
    gpgtar --encrypt --output $ENCRYPTED_LOCAL_BACKUP_FILE -r msf.ocg@example.com $BACKUP_DIR
    log_process_status "Encryption completed successfully!" "Error: encryption failed!"

}

# function to sync the backup archive to a remote destination
sync_to_remote_lime() {
    source_path=$1
    remote_destination=$2

    rsync_cmd="rsync --delete $source_path $BACKUP_SERVER_CRIDENTIALS:$remote_destination"

    echo "Syncing $source_path to $BACKUP_SERVER_CRIDENTIALS:$remote_destination..."
    $rsync_cmd
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