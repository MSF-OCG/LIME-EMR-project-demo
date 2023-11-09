#!/bin/sh

# Configurable variables for the application
REPOSITORY_URL="https://github.com/MSF-OCG/LIME-EMR-project-demo.git"
BRANCH_NAME="main"
APP_NAME="emr"
APP_URL="http://localhost/openmrs/login.htm"
CONTAINER_NAMES="openmrs-db openmrs-frontend openmrs-backend openmrs-gateway"

# List of dependencies to be installed
PACKAGES_TO_INSTALL="git curl vim mlocate rsync software-properties-common apt-transport-https ca-certificates gnupg2"

# Configurable variables for installation and logs
INSTALL_DIR="/home/lime/$APP_NAME"
LOG_DIR="/var/logs/lime"
SUCCESS_LOG="$LOG_DIR/install_script_success.log"
ERROR_LOG="$LOG_DIR/install_script_error.log"
MAX_ATTEMPTS=5
MAX_RETRIES=100
COMPOSE_VERSION="2.23.0"

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

# Function to install Docker Compose if not already installed
install_docker_compose() {
    if ! command -v docker-compose > /dev/null 2>&1; then
        echo "Docker Compose is not installed. Installing..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        if [ "$(docker-compose --version)" = "docker-compose version ${COMPOSE_VERSION},"* ]; then
            log_success "Docker Compose version $COMPOSE_VERSION has been installed."
        else
            log_error "Failed to install Docker Compose."
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

# Backup function
backup_application() {
  # Implement backup logic
  echo "Backing up application..."
  # Backup commands to be added
}

# Update application function
update_application() {
  # Implement update logic
  echo "Updating application..."
  # Update commands to be added
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
  *)
    echo "Invalid procedure. Please specify 'install', 'update', or 'backup'."
    exit 1
    ;;
esac
