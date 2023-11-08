#!/bin/sh

# Configurable variables for the application
REPOSITORY_URL="https://github.com/MSF-OCG/LIME-EMR-project-demo.git"
BRANCH_NAME="main"
APP_NAME="emr"
APP_URL="http://localhost/openmrs/login.htm"
CONTAINER_NAMES="openmrs-db openmrs-frontend openmrs-backend openmrs-gateway"

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
touch "$SUCCESS_LOG"
touch "$ERROR_LOG"

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
install_packages() {
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git curl vim screen gettext-base jq pwgen mlocate rsync software-properties-common apt-transport-https ca-certificates gnupg2
    log_success "All required packages have been installed."
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
    (cd "$INSTALL_DIR" && docker-compose up -d) >> "$SUCCESS_LOG" 2>> "$ERROR_LOG"
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
          return 1
          ;;
    esac
    log_success "Branch name set to '$BRANCH_NAME' based on the hostname."
    return 0
}

# Function to clone the repository
clone_repository() {
    get_branch_name

    if [ ! -d "$INSTALL_DIR/.git" ]; then
        echo "Cloning the repository branch '$BRANCH_NAME' into $INSTALL_DIR."
        git clone --single-branch --branch "$BRANCH_NAME" "$REPOSITORY_URL" "$INSTALL_DIR" 2>>"$ERROR_LOG"
        if [ $? -eq 0 ]; then
            log_success "Cloned the '$BRANCH_NAME' branch of the repository into $INSTALL_DIR."
        else
            log_error "Failed to clone the '$BRANCH_NAME' branch of the repository into $INSTALL_DIR."
            exit 1
        fi
    else
        echo "Repository already cloned. Checking for updates..."
        (cd "$INSTALL_DIR" && git fetch && git checkout "$BRANCH_NAME" && git pull origin "$BRANCH_NAME" 2>>"$ERROR_LOG")
        if [ $? -eq 0 ]; then
            log_success "Updated the '$BRANCH_NAME' branch of the repository in $INSTALL_DIR."
        else
            log_error "Failed to update the '$BRANCH_NAME' branch of the repository in $INSTALL_DIR."
            exit 1
        fi
    fi
}

# Main installation function
install_application() {
    install_packages
    log_success "Installation and verifications completed successfully." || \
    log_error "Installation or verification failed." && return 1
    remove_empty_log "$SUCCESS_LOG"
    remove_empty_log "$ERROR_LOG"
}

# Start the installation process
install_application
