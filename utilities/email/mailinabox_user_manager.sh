#!/bin/bash

# Mailinabox User Management Script
# Script to manage mail users using Mailinabox API

# Default configuration
BASE_URL=""
ADMIN_EMAIL=""
ADMIN_PASSWORD=""
CSV_FILE=""
BATCH_PASSWORD=""
USE_BATCH_PASSWORD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
    echo "Mailinabox User Management Script"
    echo "Usage: $0 [OPTIONS] COMMAND [ARGUMENTS]"
    echo ""
    echo "SETUP OPTIONS:"
    echo "  -u, --url URL           Mailinabox base URL (example: https://your-mailinabox-domain.com)"
    echo "  -a, --admin EMAIL       Admin email for authentication"
    echo "  -p, --password PASS     Admin password for authentication"
    echo ""
    echo "COMMANDS:"
    echo "  list                    Display active mail users only"
    echo "  list-inactive           Display inactive mail users only"
    echo "  list-all                Display all mail users (active and inactive)"
    echo "  add EMAIL PASSWORD      Add new user"
    echo "  remove EMAIL            Remove user"
    echo "  add-admin EMAIL         Add admin privilege to user"
    echo "  remove-admin EMAIL      Remove admin privilege from user"
    echo ""
    echo "BATCH OPERATIONS:"
    echo "  batch-add CSV_FILE [--use-batch-password PASSWORD]"
    echo "                          Add multiple users from CSV"
    echo "  batch-remove CSV_FILE   Remove multiple users from CSV"
    echo ""
    echo "CSV FORMAT:"
    echo "  email,password"
    echo "  test1@mail.com,str0ngP@ssWd"
    echo "  test2@mail.com,an0th3rP@ss"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 -u https://your-mailinabox-domain.com -a admin@domain.com -p secret123 list"
    echo "  $0 -u https://your-mailinabox-domain.com -a admin@domain.com -p secret123 list-inactive"
    echo "  $0 -u https://your-mailinabox-domain.com -a admin@domain.com -p secret123 list-all"
    echo "  $0 -u https://your-mailinabox-domain.com -a admin@domain.com -p secret123 add user@domain.com password123"
    echo "  $0 -u https://your-mailinabox-domain.com -a admin@domain.com -p secret123 batch-add users.csv"
    echo "  $0 -u https://your-mailinabox-domain.com -a admin@domain.com -p secret123 batch-add users.csv --use-batch-password samepass123"
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate configuration
validate_config() {
    if [[ -z "$BASE_URL" ]]; then
        log_error "Base URL is not set. Use -u or --url"
        return 1
    fi
    
    if [[ -z "$ADMIN_EMAIL" ]]; then
        log_error "Admin email is not set. Use -a or --admin"
        return 1
    fi
    
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        log_error "Admin password is not set. Use -p or --password"
        return 1
    fi
    
    return 0
}

# Function to validate email format
validate_email() {
    local email=$1
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Function to make HTTP requests
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local url="${BASE_URL}${endpoint}"
    
    if [[ "$method" == "GET" ]]; then
        curl -s -X GET "$url" --user "${ADMIN_EMAIL}:${ADMIN_PASSWORD}"
    else
        curl -s -X POST $data "$url" --user "${ADMIN_EMAIL}:${ADMIN_PASSWORD}"
    fi
}

# Function to display active users only
list_users() {
    log_info "Retrieving active mail users list..."
    
    local response
    response=$(make_request "GET" "/admin/mail/users?format=json")
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to retrieve users list"
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        log_error "Invalid response: $response"
        return 1
    fi
    
    log_success "Active Mail Users List:"
    
    # Get all active users
    echo "$response" | jq -r '.[] | .users[] | select(.status == "active") | "ACTIVE: \(.email) - \(.status)"' | while IFS='|' read -r email status privileges; do
        echo "$email - Status: $status - Privileges: $privileges"
    done
}

# Function to display inactive users only
list_inactive_users() {
    log_info "Retrieving inactive mail users list..."
    
    local response
    response=$(make_request "GET" "/admin/mail/users?format=json")
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to retrieve users list"
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        log_error "Invalid response: $response"
        return 1
    fi
    
    log_success "Inactive Mail Users List:"
    
    local found_inactive=false
    
    # Get all inactive users
    echo "$response" | jq -r '.[] | .users[] | select(.status == "inactive") | "INACTIVE: \(.email) - \(.status)"' | while IFS='|' read -r email status privileges; do
        echo "$email - Status: $status - Privileges: $privileges"
    done
    
    # Note: This approach won't show "No inactive users found" due to subshell limitation
    # But it will work for filtering
}

# Function to display all users (active and inactive)
list_all_users() {
    log_info "Retrieving all mail users list..."
    
    local response
    response=$(make_request "GET" "/admin/mail/users?format=json")
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to retrieve users list"
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        log_error "Invalid response: $response"
        return 1
    fi
    
    log_success "All Mail Users List:"
    
    # Get all users without filtering
    echo "$response" | jq -r '.[] | .users[] | "Email: " + .email + " | Status: " + .status + " | Privileges: " + (.privileges | join(", "))' | while IFS='|' read -r email status privileges; do
        echo "$email - Status: $status - Privileges: $privileges"
    done
}

# Function to debug user list filtering
list_debug_users() {
    log_info "Debug: Retrieving all mail users with detailed info..."
    
    local response
    response=$(make_request "GET" "/admin/mail/users?format=json")
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to retrieve users list"
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        log_error "Invalid response: $response"
        return 1
    fi
    
    echo "=== RAW JSON RESPONSE ==="
    echo "$response" | jq .
    
    echo -e "\n=== ALL USERS WITH STATUS ==="
    echo "$response" | jq -r '.[] | .users[] | "Email: " + .email + " | Status: " + .status + " | Privileges: " + (.privileges | join(", "))'
    
    echo -e "\n=== ACTIVE USERS FILTER TEST ==="
    local active_test
    active_test=$(echo "$response" | jq -r '.[] | .users[] | select(.status == "active") | "ACTIVE: \(.email) - \(.status)"')
    if [[ -n "$active_test" ]]; then
        echo "$active_test"
    else
        echo "No users found with status 'active'"
    fi
    
    echo -e "\n=== INACTIVE USERS FILTER TEST ==="
    local inactive_test
    inactive_test=$(echo "$response" | jq -r '.[] | .users[] | select(.status == "inactive") | "INACTIVE: \(.email) - \(.status)"')
    if [[ -n "$inactive_test" ]]; then
        echo "$inactive_test"
    else
        echo "No users found with status 'inactive'"
    fi
    
    echo -e "\n=== STATUS VALUES FOUND ==="
    echo "$response" | jq -r '.[] | .users[] | .status' | sort | uniq -c
    
    echo -e "\n=== TESTING EXACT COMMAND USED IN list_users() ==="
    echo "$response" | jq -r '.[] | .users[] | select(.status == "active") | .email + " - Status: " + .status + " - Privileges: " + (.privileges | join(", "))'
}

# Function to add user
add_user() {
    local email=$1
    local password=$2
    
    if [[ -z "$email" || -z "$password" ]]; then
        log_error "Email and password are required"
        return 1
    fi
    
    if ! validate_email "$email"; then
        log_error "Invalid email format: $email"
        return 1
    fi
    
    log_info "Adding user: $email"
    
    local response
    response=$(make_request "POST" "/admin/mail/users/add" "-d email=$email -d password=$password")
    
    if [[ "$response" == *"mail user added"* ]]; then
        log_success "User $email successfully added"
        return 0
    else
        log_error "Failed to add user $email: $response"
        return 1
    fi
}

# Function to remove user
remove_user() {
    local email=$1
    
    if [[ -z "$email" ]]; then
        log_error "Email is required"
        return 1
    fi
    
    if ! validate_email "$email"; then
        log_error "Invalid email format: $email"
        return 1
    fi
    
    log_info "Removing user: $email"
    
    local response
    response=$(make_request "POST" "/admin/mail/users/remove" "-d email=$email")
    
    if [[ "$response" == "OK" || "$response" == *"mail user removed"* ]]; then
        log_success "User $email successfully removed"
        return 0
    else
        log_error "Failed to remove user $email: $response"
        return 1
    fi
}

# Function to add admin privilege
add_admin_privilege() {
    local email=$1
    
    if [[ -z "$email" ]]; then
        log_error "Email is required"
        return 1
    fi
    
    if ! validate_email "$email"; then
        log_error "Invalid email format: $email"
        return 1
    fi
    
    log_info "Adding admin privilege for: $email"
    
    local response
    response=$(make_request "POST" "/admin/mail/users/privileges/add" "-d email=$email -d privilege=admin")
    
    if [[ "$response" == "OK" ]]; then
        log_success "Admin privilege successfully added for $email"
        return 0
    else
        log_error "Failed to add admin privilege for $email: $response"
        return 1
    fi
}

# Function to remove admin privilege
remove_admin_privilege() {
    local email=$1
    
    if [[ -z "$email" ]]; then
        log_error "Email is required"
        return 1
    fi
    
    if ! validate_email "$email"; then
        log_error "Invalid email format: $email"
        return 1
    fi
    
    log_info "Removing admin privilege for: $email"
    
    local response
    response=$(make_request "POST" "/admin/mail/users/privileges/remove" "-d email=$email")
    
    if [[ "$response" == "OK" ]]; then
        log_success "Admin privilege successfully removed for $email"
        return 0
    else
        log_error "Failed to remove admin privilege for $email: $response"
        return 1
    fi
}

# Function to validate CSV file
validate_csv() {
    local csv_file=$1
    
    if [[ ! -f "$csv_file" ]]; then
        log_error "CSV file not found: $csv_file"
        return 1
    fi
    
    # Check CSV header
    local header
    header=$(head -n 1 "$csv_file")
    if [[ "$header" != "email,password" ]]; then
        log_error "Invalid CSV format. Header must be: email,password"
        return 1
    fi
    
    # Check if there's data
    local line_count
    line_count=$(wc -l < "$csv_file")
    if [[ $line_count -lt 2 ]]; then
        log_error "CSV is empty or contains only header"
        return 1
    fi
    
    return 0
}

# Function to batch add users
batch_add_users() {
    local csv_file=$1
    
    if ! validate_csv "$csv_file"; then
        return 1
    fi
    
    log_info "Starting batch add users from: $csv_file"
    
    local success_count=0
    local error_count=0
    local line_num=1
    
    # Skip header and process each line
    tail -n +2 "$csv_file" | while IFS=',' read -r email password; do
        ((line_num++))
        
        # Trim whitespace
        email=$(echo "$email" | xargs)
        password=$(echo "$password" | xargs)
        
        # Skip empty lines
        if [[ -z "$email" ]]; then
            log_warning "Line $line_num: Empty email, skipped"
            continue
        fi
        
        # Use batch password if set
        if [[ "$USE_BATCH_PASSWORD" == true ]]; then
            password="$BATCH_PASSWORD"
        fi
        
        # Validate password
        if [[ -z "$password" ]]; then
            log_error "Line $line_num: Empty password for $email"
            ((error_count++))
            continue
        fi
        
        # Add user
        if add_user "$email" "$password"; then
            ((success_count++))
        else
            ((error_count++))
        fi
        
        # Small delay to avoid rate limiting
        sleep 0.5
    done
    
    log_info "Batch add completed. Success: $success_count, Failed: $error_count"
}

# Function to batch remove users
batch_remove_users() {
    local csv_file=$1
    
    if ! validate_csv "$csv_file"; then
        return 1
    fi
    
    log_info "Starting batch remove users from: $csv_file"
    
    local success_count=0
    local error_count=0
    local line_num=1
    
    # Skip header and process each line
    tail -n +2 "$csv_file" | while IFS=',' read -r email password; do
        ((line_num++))
        
        # Trim whitespace
        email=$(echo "$email" | xargs)
        
        # Skip empty lines
        if [[ -z "$email" ]]; then
            log_warning "Line $line_num: Empty email, skipped"
            continue
        fi
        
        # Remove user
        if remove_user "$email"; then
            ((success_count++))
        else
            ((error_count++))
        fi
        
        # Small delay to avoid rate limiting
        sleep 0.5
    done
    
    log_info "Batch remove completed. Success: $success_count, Failed: $error_count"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            BASE_URL="$2"
            # Remove trailing slash
            BASE_URL=${BASE_URL%/}
            shift 2
            ;;
        -a|--admin)
            ADMIN_EMAIL="$2"
            shift 2
            ;;
        -p|--password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --use-batch-password)
            USE_BATCH_PASSWORD=true
            BATCH_PASSWORD="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

# Check if jq is available
if ! command -v jq &> /dev/null; then
    log_error "jq not found. Please install jq first:"
    log_error "Ubuntu/Debian: sudo apt-get install jq"
    log_error "CentOS/RHEL: sudo yum install jq"
    log_error "macOS: brew install jq"
    exit 1
fi

# Validate configuration
if ! validate_config; then
    echo ""
    show_help
    exit 1
fi

# Parse command
COMMAND="$1"
shift

case "$COMMAND" in
    list)
        list_users
        ;;
    list-inactive)
        list_inactive_users
        ;;
    list-all)
        list_all_users
        ;;
    list-debug)
        list_debug_users
        ;;
    add)
        if [[ $# -lt 2 ]]; then
            log_error "Usage: $0 add EMAIL PASSWORD"
            exit 1
        fi
        add_user "$1" "$2"
        ;;
    remove)
        if [[ $# -lt 1 ]]; then
            log_error "Usage: $0 remove EMAIL"
            exit 1
        fi
        remove_user "$1"
        ;;
    add-admin)
        if [[ $# -lt 1 ]]; then
            log_error "Usage: $0 add-admin EMAIL"
            exit 1
        fi
        add_admin_privilege "$1"
        ;;
    remove-admin)
        if [[ $# -lt 1 ]]; then
            log_error "Usage: $0 remove-admin EMAIL"
            exit 1
        fi
        remove_admin_privilege "$1"
        ;;
    batch-add)
        if [[ $# -lt 1 ]]; then
            log_error "Usage: $0 batch-add CSV_FILE [--use-batch-password PASSWORD]"
            exit 1
        fi
        batch_add_users "$1"
        ;;
    batch-remove)
        if [[ $# -lt 1 ]]; then
            log_error "Usage: $0 batch-remove CSV_FILE"
            exit 1
        fi
        batch_remove_users "$1"
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac