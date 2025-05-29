#!/bin/bash

# IMAP Email Reader Script
# Script to read emails from Mailinabox using IMAP protocol

# Configuration
IMAP_SERVER=""
USERNAME=""
PASSWORD=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
    echo "IMAP Email Reader Script"
    echo "Usage: $0 [OPTIONS] COMMAND [ARGUMENTS]"
    echo ""
    echo "SETUP OPTIONS:"
    echo "  -s, --server SERVER     IMAP server (example: mail.yourdomain.com)"
    echo "  -u, --username EMAIL    Username/email for authentication"
    echo "  -p, --password PASS     Password for authentication"
    echo ""
    echo "COMMANDS:"
    echo "  list                                    List all emails with basic info"
    echo "  count                                   Count total emails in INBOX"
    echo "  read EMAIL_ID                           Read specific email by ID"
    echo "  search-sender INPUT                     Search emails from sender (EMAIL or CSV file - auto-detected)"
    echo "  search-sender-batch CSV                 Search emails from multiple senders from CSV file"
    echo "  process-results CSV ACTION              Process batch search results (list/read-all/read-filtered)"
    echo "  search-subject TEXT                     Search emails by subject"
    echo "  search-date DATE                        Search emails since date (YYYY-MM-DD)"
    echo "  unread                                  List unread emails"
    echo "  latest N                                Show latest N emails"
    echo "  read-from-sender EMAIL                  Read full content of all emails from sender"
    echo "  search-sender-subject SENDER SUBJECT    Search by sender and subject (contains)"
    echo "  search-advanced CRITERIA                Advanced IMAP search with custom criteria"
    echo "  search-filtered S SUB DATE STATUS       Multi-filter search (use 'SKIP' to skip)"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 list"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 read 5"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 search-sender 'admin@domain.com'"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 search-sender senders.csv"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 search-sender-batch senders.csv"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 extract-urls 'admin@domain.com' 'https://domain.com/verify/'"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 search-sender-subject 'admin@domain.com' 'invoice'"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 extract-urls senders.csv 'https://domain.com/verify/' results.csv"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 search-subject 'invoice'"
    echo "  $0 -s mail.domain.com -u user@domain.com -p pass123 search-date '2025-05-29'"
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
    if [[ -z "$IMAP_SERVER" ]]; then
        log_error "IMAP server is not set. Use -s or --server"
        return 1
    fi
    
    if [[ -z "$USERNAME" ]]; then
        log_error "Username is not set. Use -u or --username"
        return 1
    fi
    
    if [[ -z "$PASSWORD" ]]; then
        log_error "Password is not set. Use -p or --password"
        return 1
    fi
    
    return 0
}

# Function to execute IMAP commands
execute_imap_command() {
    local commands="$1"
    local delay="${2:-3}"
    local temp_file=$(mktemp)
    
    {
        echo "A001 LOGIN $USERNAME $PASSWORD"
        sleep 2
        echo "A002 SELECT INBOX"
        sleep 2
        echo "$commands"
        sleep $delay
        echo "A999 LOGOUT"
        sleep 1
    } | openssl s_client -connect $IMAP_SERVER:993 -quiet > "$temp_file" 2>&1
    
    cat "$temp_file"
    rm "$temp_file"
}

# Function to parse email IDs from search results
parse_email_ids() {
    local search_response="$1"
    
    # Extract only numeric IDs from SEARCH response
    local ids
    ids=$(echo "$search_response" | grep -E "\* SEARCH" | sed 's/.*\* SEARCH//' | sed 's/A[0-9]*.*$//' | grep -o '[0-9]\+' | tr '\n' ' ' | xargs)
    
    # Alternative parsing if first method fails
    if [[ -z "$ids" ]]; then
        # Try to find numbers after SEARCH keyword
        ids=$(echo "$search_response" | grep -i "search" | grep -o '[0-9]\+' | tr '\n' ' ' | xargs)
    fi
    
    # Remove any non-numeric entries
    local clean_ids=""
    for id in $ids; do
        if [[ "$id" =~ ^[0-9]+$ ]]; then
            clean_ids="$clean_ids $id"
        fi
    done
    
    # Clean up whitespace and return
    echo "$clean_ids" | xargs
}

# Function to count emails
count_emails() {
    log_info "Counting emails in INBOX..."
    
    local response
    response=$(execute_imap_command "A003 STATUS INBOX (MESSAGES)" 3)
    
    local count
    count=$(echo "$response" | grep "MESSAGES" | grep -o '[0-9]*' | tail -1)
    
    if [[ -n "$count" ]]; then
        log_success "Total emails in INBOX: $count"
    else
        log_error "Failed to get email count"
        echo "Response: $response"
    fi
}

# Function to list all emails with basic info
list_emails() {
    log_info "Listing all emails..."
    
    # First get email count
    local response
    response=$(execute_imap_command "A003 STATUS INBOX (MESSAGES)" 3)
    local count
    count=$(echo "$response" | grep "MESSAGES" | grep -o '[0-9]*' | tail -1)
    
    if [[ -z "$count" || "$count" -eq 0 ]]; then
        log_warning "No emails found in INBOX"
        return
    fi
    
    log_info "Found $count emails. Getting headers..."
    
    # Get headers for all emails
    for i in $(seq 1 $count); do
        echo "=== Email $i ==="
        local email_info
        email_info=$(execute_imap_command "A003 FETCH $i BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        
        echo "$email_info" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        echo ""
        
        # Small delay to avoid overwhelming server
        sleep 0.5
    done
}

# Function to read specific email
read_email() {
    local email_id=$1
    
    if [[ -z "$email_id" ]]; then
        log_error "Email ID is required"
        return 1
    fi
    
    if ! [[ "$email_id" =~ ^[0-9]+$ ]]; then
        log_error "Email ID must be a number"
        return 1
    fi
    
    log_info "Reading email ID: $email_id"
    
    # Get email headers first
    echo "=== Email Headers ==="
    local headers
    headers=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (FROM TO SUBJECT DATE)]" 3)
    
    # Parse headers
    local from=$(echo "$headers" | grep -i "From:" | cut -d' ' -f2- | tr -d '\r\n')
    local to=$(echo "$headers" | grep -i "To:" | cut -d' ' -f2- | tr -d '\r\n')
    local subject=$(echo "$headers" | grep -i "Subject:" | cut -d' ' -f2- | tr -d '\r\n')
    local date=$(echo "$headers" | grep -i "Date:" | cut -d' ' -f2- | tr -d '\r\n')
    
    echo "From: ${from:-N/A}"
    echo "To: ${to:-N/A}"
    echo "Subject: ${subject:-N/A}"
    echo "Date: ${date:-N/A}"
    
    echo -e "\n=== Email Body ==="
    
    # Try to get email body
    local temp_file=$(mktemp)
    local success=false
    
    # Method 1: Try BODY[TEXT]
    {
        echo "A001 LOGIN $USERNAME $PASSWORD"
        sleep 2
        echo "A002 SELECT INBOX"
        sleep 2
        echo "A003 FETCH $email_id BODY[TEXT]"
        sleep 8
        echo "A004 LOGOUT"
        sleep 1
    } | openssl s_client -connect $IMAP_SERVER:993 -quiet > "$temp_file" 2>&1
    
    # Check if we got body content
    if grep -q "BODY\[TEXT\]" "$temp_file"; then
        log_info "Found BODY[TEXT] response, parsing..."
        
        # Try multiple parsing methods
        local body_content=""
        
        # Method A: AWK parsing (most robust)
        body_content=$(awk '/A003.*FETCH.*BODY\[TEXT\]/{flag=1; next} /^A004|^\)/{flag=0} flag' "$temp_file" | grep -v "^A003\|^$")
        
        if [[ -n "$body_content" ]]; then
            echo "$body_content"
            success=true
        else
            # Method B: Simple grep after BODY[TEXT] - fixed head command
            local raw_body
            raw_body=$(grep -A 999 "BODY\[TEXT\]" "$temp_file" | tail -n +2)
            
            # Count lines and remove last 2 lines safely
            local line_count
            line_count=$(echo "$raw_body" | wc -l)
            if [[ $line_count -gt 2 ]]; then
                body_content=$(echo "$raw_body" | head -n $((line_count - 2)))
            else
                body_content="$raw_body"
            fi
            
            # Remove IMAP response lines
            body_content=$(echo "$body_content" | grep -v "^A004\|^)\|^$")
            
            if [[ -n "$body_content" ]]; then
                echo "$body_content"
                success=true
            fi
        fi
    fi
    
    # If BODY[TEXT] failed, try BODY[] (full email)
    if [[ "$success" == false ]]; then
        log_warning "BODY[TEXT] parsing failed, trying BODY[] (full email)..."
        
        {
            echo "A001 LOGIN $USERNAME $PASSWORD"
            sleep 2
            echo "A002 SELECT INBOX"
            sleep 2
            echo "A003 FETCH $email_id BODY[]"
            sleep 8
            echo "A004 LOGOUT"
            sleep 1
        } | openssl s_client -connect $IMAP_SERVER:993 -quiet > "$temp_file" 2>&1
        
        # Parse full email and extract body part
        if grep -q "BODY\[\]" "$temp_file"; then
            log_info "Found BODY[] response, extracting body part..."
            
            # Extract full email content
            local full_content
            full_content=$(awk '/A003.*FETCH.*BODY\[\]/{flag=1; next} /^A004|^\)/{flag=0} flag' "$temp_file")
            
            if [[ -n "$full_content" ]]; then
                # Find the first empty line (separator between headers and body)
                local body_start_line
                body_start_line=$(echo "$full_content" | grep -n "^$" | head -1 | cut -d: -f1)
                
                if [[ -n "$body_start_line" ]]; then
                    # Extract everything after the empty line
                    local email_body
                    email_body=$(echo "$full_content" | tail -n +$((body_start_line + 1)))
                    if [[ -n "$email_body" ]]; then
                        echo "$email_body"
                        success=true
                    fi
                else
                    # No empty line found, maybe it's a simple text email
                    # Skip first few lines (likely headers) and show the rest
                    local simple_body
                    simple_body=$(echo "$full_content" | tail -n +10)
                    if [[ -n "$simple_body" ]]; then
                        echo "$simple_body"
                        success=true
                    fi
                fi
            fi
        fi
    fi
    
    # Last resort: try to show any content we can find
    if [[ "$success" == false ]]; then
        log_warning "Standard parsing failed, trying simple content extraction..."
        
        # Just show everything after FETCH that looks like content
        local simple_content
        simple_content=$(grep -A 999 "FETCH" "$temp_file" | tail -n +3)
        
        # Remove obvious IMAP command lines
        simple_content=$(echo "$simple_content" | grep -v "^A[0-9]\|^)\|^$" | head -20)
        
        if [[ -n "$simple_content" ]]; then
            echo "$simple_content"
            success=true
            log_info "Content extracted using simple method"
        else
            log_error "No readable content found. Raw response:"
            cat "$temp_file"
        fi
    fi
    
    rm "$temp_file"
    
    if [[ "$success" == true ]]; then
        log_success "Email $email_id read successfully"
        return 0
    else
        log_error "Failed to read email $email_id"
        return 1
    fi
}

# Function to search emails by sender (with auto-detection)
search_by_sender() {
    local input="$1"
    local output_file="$2"
    
    if [[ -z "$input" ]]; then
        log_error "Email address or CSV file is required"
        return 1
    fi
    
    # Auto-detect if input is a file or email address
    if [[ -f "$input" ]]; then
        log_info "Detected CSV file input: $input"
        search_sender_batch "$input" "$output_file"
        return
    fi
    
    # Check if input looks like an email address
    if [[ "$input" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        log_info "Detected email address input: $input"
        search_single_sender "$input"
        return
    fi
    
    log_error "Input must be either a valid email address or existing CSV file"
    log_error "Examples:"
    log_error "  Email: admin@domain.com"
    log_error "  CSV file: senders.csv"
    return 1
}

# Function to search emails from single sender
search_single_sender() {
    local sender_email="$1"
    
    log_info "Searching emails from: $sender_email"
    
    local search_response
    search_response=$(execute_imap_command "A003 SEARCH FROM \"$sender_email\"" 4)
    
    local email_ids
    email_ids=$(parse_email_ids "$search_response")
    
    if [[ -z "$email_ids" ]]; then
        log_warning "No emails found from $sender_email"
        return
    fi
    
    # Convert to array to count - fix the array conversion
    local ids_array
    read -ra ids_array <<< "$email_ids"
    local count=${#ids_array[@]}
    
    if [[ $count -eq 1 ]]; then
        # Get the first (and only) email ID
        local single_id="${ids_array[0]}"
        log_success "Found 1 email from $sender_email (ID: $single_id)"
        echo "Auto-reading the email..."
        echo ""
        
        # Call read_email function directly
        read_email "$single_id"
        return
    fi
    
    log_success "Found $count emails with IDs: $email_ids"
    echo ""
    
    # Show details for each found email
    for email_id in "${ids_array[@]}"; do
        # Skip non-numeric IDs
        if [[ ! "$email_id" =~ ^[0-9]+$ ]]; then
            echo "Skipping non-numeric ID: $email_id"
            continue
        fi
        
        echo "=== Email ID: $email_id ==="
        local email_info
        email_info=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        echo "$email_info" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        echo ""
        sleep 0.5
    done
    
    echo "Use 'read <EMAIL_ID>' to read full content of any email above"
}

# Function to search emails by subject
search_by_subject() {
    local subject_text="$1"
    
    if [[ -z "$subject_text" ]]; then
        log_error "Subject text is required"
        return 1
    fi
    
    log_info "Searching emails with subject containing: $subject_text"
    
    local search_response
    search_response=$(execute_imap_command "A003 SEARCH SUBJECT \"$subject_text\"" 4)
    
    local email_ids
    email_ids=$(parse_email_ids "$search_response")
    
    if [[ -z "$email_ids" ]]; then
        log_warning "No emails found with subject containing '$subject_text'"
        return
    fi
    
    log_success "Found emails with IDs: $email_ids"
    echo ""
    
    # Show details for each found email
    for email_id in $email_ids; do
        echo "=== Email ID: $email_id ==="
        local email_info
        email_info=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        echo "$email_info" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        echo ""
        sleep 0.5
    done
    
    echo "Use 'read <EMAIL_ID>' to read full content of any email above"
}

# Function to search emails by date
search_by_date() {
    local since_date="$1"
    
    if [[ -z "$since_date" ]]; then
        log_error "Date is required (format: YYYY-MM-DD, example: 2025-05-29)"
        return 1
    fi
    
    # Validate date format YYYY-MM-DD
    if [[ ! "$since_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        log_error "Invalid date format. Use YYYY-MM-DD (example: 2025-05-29)"
        return 1
    fi
    
    # Convert YYYY-MM-DD to DD-MMM-YYYY format for IMAP
    local year month day
    year=$(echo "$since_date" | cut -d'-' -f1)
    month=$(echo "$since_date" | cut -d'-' -f2)
    day=$(echo "$since_date" | cut -d'-' -f3)
    
    # Convert numeric month to abbreviated month name
    local month_names=("" "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
    local month_abbr="${month_names[$((10#$month))]}"
    
    # Format as DD-MMM-YYYY for IMAP SEARCH
    local imap_date="${day}-${month_abbr}-${year}"
    
    log_info "Searching emails since: $since_date (IMAP format: $imap_date)"
    
    local search_response
    search_response=$(execute_imap_command "A003 SEARCH SINCE \"$imap_date\"" 4)
    
    local email_ids
    email_ids=$(parse_email_ids "$search_response")
    
    if [[ -z "$email_ids" ]]; then
        log_warning "No emails found since $since_date"
        return
    fi
    
    # Convert to array to count
    local ids_array
    read -ra ids_array <<< "$email_ids"
    local count=${#ids_array[@]}
    
    log_success "Found $count emails since $since_date with IDs: $email_ids"
    echo ""
    
    # Show details for each found email
    for email_id in "${ids_array[@]}"; do
        # Skip non-numeric IDs
        if [[ ! "$email_id" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        echo "=== Email ID: $email_id ==="
        local email_info
        email_info=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        echo "$email_info" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        echo ""
        sleep 0.5
    done
}

# Function to get unread emails
get_unread_emails() {
    log_info "Searching unread emails..."
    
    local search_response
    search_response=$(execute_imap_command "A003 SEARCH UNSEEN" 4)
    
    local email_ids
    email_ids=$(parse_email_ids "$search_response")
    
    if [[ -z "$email_ids" ]]; then
        log_warning "No unread emails found"
        return
    fi
    
    log_success "Found unread emails with IDs: $email_ids"
    echo ""
    
    # Show details for each unread email
    for email_id in $email_ids; do
        echo "=== Unread Email ID: $email_id ==="
        local email_info
        email_info=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        echo "$email_info" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        echo ""
        sleep 0.5
    done
}

# Function to search emails from multiple senders (batch)
search_sender_batch() {
    local csv_file="$1"
    local output_file="${2:-email_results.csv}"
    
    if [[ -z "$csv_file" ]]; then
        log_error "CSV file is required"
        return 1
    fi
    
    if [[ ! -f "$csv_file" ]]; then
        log_error "CSV file not found: $csv_file"
        return 1
    fi
    
    # Validate CSV format
    local header
    header=$(head -n 1 "$csv_file")
    if [[ "$header" != "email" ]]; then
        log_error "Invalid CSV format. Header must be: email"
        log_error "Example format:"
        log_error "email"
        log_error "user1@domain.com"
        log_error "user2@domain.com"
        return 1
    fi
    
    log_info "Processing batch search from: $csv_file"
    log_info "Results will be saved to: $output_file"
    
    # Create output CSV header
    echo "sender_email,email_id,subject,date,status" > "$output_file"
    
    local total_processed=0
    local total_found=0
    local line_num=1
    
    # Process each sender email
    tail -n +2 "$csv_file" | while IFS=',' read -r sender_email; do
        ((line_num++))
        ((total_processed++))
        
        # Trim whitespace
        sender_email=$(echo "$sender_email" | xargs)
        
        # Skip empty lines
        if [[ -z "$sender_email" ]]; then
            log_warning "Line $line_num: Empty email, skipped"
            continue
        fi
        
        log_info "Processing: $sender_email"
        
        # Search emails from this sender
        local search_response
        search_response=$(execute_imap_command "A003 SEARCH FROM \"$sender_email\"" 4)
        
        local email_ids
        email_ids=$(parse_email_ids "$search_response")
        
        if [[ -z "$email_ids" ]]; then
            log_warning "No emails found from: $sender_email"
            echo "$sender_email,N/A,No emails found,N/A,not_found" >> "$output_file"
        else
            # Get details for each found email
            for email_id in $email_ids; do
                ((total_found++))
                
                # Get email headers
                local email_info
                email_info=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (SUBJECT DATE)]" 3)
                
                local subject
                subject=$(echo "$email_info" | grep "Subject:" | cut -d' ' -f2- | tr -d '\r\n' | sed 's/,/;/g')
                
                local date
                date=$(echo "$email_info" | grep "Date:" | cut -d' ' -f2- | tr -d '\r\n' | sed 's/,/;/g')
                
                # Clean up subject and date
                subject=${subject:-"No Subject"}
                date=${date:-"No Date"}
                
                # Add to CSV
                echo "$sender_email,$email_id,\"$subject\",\"$date\",found" >> "$output_file"
                
                log_success "Found email ID $email_id from $sender_email"
            done
        fi
        
        # Small delay to avoid overwhelming server
        sleep 1
    done
    
    log_success "Batch search completed!"
    log_success "Processed: $total_processed senders"
    log_success "Found: $total_found emails total"
    log_success "Results saved to: $output_file"
    
    # Show summary
    echo ""
    echo "=== SUMMARY ==="
    echo "Total senders processed: $total_processed"
    echo "Total emails found: $total_found"
    echo "Results file: $output_file"
    echo ""
    echo "To read specific emails from the results, use:"
    echo "./script.sh read <EMAIL_ID>"
}

# Function to process batch search results (read emails from CSV results)
process_batch_results() {
    local results_csv="$1"
    local action="${2:-list}"  # list, read-all, or read-filtered
    
    if [[ -z "$results_csv" ]]; then
        log_error "Results CSV file is required"
        return 1
    fi
    
    if [[ ! -f "$results_csv" ]]; then
        log_error "Results CSV file not found: $results_csv"
        return 1
    fi
    
    # Validate CSV format
    local header
    header=$(head -n 1 "$results_csv")
    if [[ "$header" != "sender_email,email_id,subject,date,status" ]]; then
        log_error "Invalid results CSV format"
        return 1
    fi
    
    case "$action" in
        "list")
            log_info "Listing emails from results CSV:"
            echo ""
            printf "%-25s %-8s %-40s %-20s %s\n" "SENDER" "EMAIL_ID" "SUBJECT" "DATE" "STATUS"
            echo "$(printf '%.0s-' {1..120})"
            
            tail -n +2 "$results_csv" | while IFS=',' read -r sender email_id subject date status; do
                # Clean quotes from subject and date
                subject=$(echo "$subject" | sed 's/^"//;s/"$//')
                date=$(echo "$date" | sed 's/^"//;s/"$//')
                
                printf "%-25s %-8s %-40s %-20s %s\n" \
                    "${sender:0:24}" \
                    "$email_id" \
                    "${subject:0:39}" \
                    "${date:0:19}" \
                    "$status"
            done
            ;;
        "read-all")
            log_info "Reading all emails from results CSV:"
            
            tail -n +2 "$results_csv" | while IFS=',' read -r sender email_id subject date status; do
                if [[ "$status" == "found" && "$email_id" != "N/A" ]]; then
                    echo "========================================"
                    echo "Reading Email ID: $email_id from $sender"
                    echo "========================================"
                    read_email "$email_id"
                    echo ""
                    sleep 2
                fi
            done
            ;;
        "read-filtered")
            local filter_sender="$3"
            if [[ -z "$filter_sender" ]]; then
                log_error "Sender filter is required for read-filtered action"
                return 1
            fi
            
            log_info "Reading emails from $filter_sender only:"
            
            tail -n +2 "$results_csv" | while IFS=',' read -r sender email_id subject date status; do
                if [[ "$sender" == "$filter_sender" && "$status" == "found" && "$email_id" != "N/A" ]]; then
                    echo "========================================"
                    echo "Reading Email ID: $email_id from $sender"
                    echo "========================================"
                    read_email "$email_id"
                    echo ""
                    sleep 2
                fi
            done
            ;;
        *)
            log_error "Invalid action. Use: list, read-all, or read-filtered"
            return 1
            ;;
    esac
}

# Function to search emails by combined sender and subject
search_by_sender_and_subject() {
    local sender_email="$1"
    local subject_text="$2"
    
    if [[ -z "$sender_email" ]]; then
        log_error "Sender email is required"
        return 1
    fi
    
    if [[ -z "$subject_text" ]]; then
        log_error "Subject text is required"
        return 1
    fi
    
    if ! [[ "$sender_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        log_error "Invalid sender email format: $sender_email"
        return 1
    fi
    
    log_info "Searching emails from: $sender_email with subject containing: '$subject_text'"
    
    # Use IMAP search with combined criteria
    local search_response
    search_response=$(execute_imap_command "A003 SEARCH FROM \"$sender_email\" SUBJECT \"$subject_text\"" 4)
    
    local email_ids
    email_ids=$(parse_email_ids "$search_response")
    
    if [[ -z "$email_ids" ]]; then
        log_warning "No emails found from $sender_email with subject containing '$subject_text'"
        return
    fi
    
    # Convert to array to count
    local ids_array
    read -ra ids_array <<< "$email_ids"
    local count=${#ids_array[@]}
    
    if [[ $count -eq 1 ]]; then
        # Get the first (and only) email ID
        local single_id="${ids_array[0]}"
        log_success "Found 1 email from $sender_email with matching subject (ID: $single_id)"
        echo "Auto-reading the email..."
        echo ""
        
        # Call read_email function directly
        read_email "$single_id"
        return
    fi
    
    log_success "Found $count emails with IDs: $email_ids"
    echo ""
    
    # Show details for each found email
    for email_id in "${ids_array[@]}"; do
        # Skip non-numeric IDs
        if [[ ! "$email_id" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        echo "=== Email ID: $email_id ==="
        local email_info
        email_info=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        echo "$email_info" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        echo ""
        sleep 0.5
    done
    
    echo "Use 'read <EMAIL_ID>' to read full content of any email above"
}

# Function to search emails with advanced criteria
search_advanced() {
    local criteria="$1"
    
    if [[ -z "$criteria" ]]; then
        log_error "Search criteria is required"
        log_error "Examples:"
        log_error "  'FROM \"admin@domain.com\" SUBJECT \"invoice\"'"
        log_error "  'FROM \"support@domain.com\" SINCE \"01-Jan-2024\"'"
        log_error "  'SUBJECT \"verification\" UNSEEN'"
        return 1
    fi
    
    log_info "Advanced search with criteria: $criteria"
    
    local search_response
    search_response=$(execute_imap_command "A003 SEARCH $criteria" 4)
    
    local email_ids
    email_ids=$(parse_email_ids "$search_response")
    
    if [[ -z "$email_ids" ]]; then
        log_warning "No emails found with criteria: $criteria"
        return
    fi
    
    # Convert to array to count
    local ids_array
    read -ra ids_array <<< "$email_ids"
    local count=${#ids_array[@]}
    
    log_success "Found $count emails with IDs: $email_ids"
    echo ""
    
    # Show details for each found email
    for email_id in "${ids_array[@]}"; do
        # Skip non-numeric IDs
        if [[ ! "$email_id" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        echo "=== Email ID: $email_id ==="
        local email_info
        email_info=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        echo "$email_info" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        echo ""
        sleep 0.5
    done
    
    echo "Use 'read <EMAIL_ID>' to read full content of any email above"
}

# Function to search with multiple filters (interactive approach)
search_filtered() {
    local sender="$1"
    local subject="$2"
    local since_date="$3"
    local status="$4"  # SEEN, UNSEEN, FLAGGED, etc.
    
    if [[ -z "$sender" && -z "$subject" && -z "$since_date" && -z "$status" ]]; then
        log_error "At least one filter is required"
        log_error "Usage: search-filtered [SENDER] [SUBJECT] [SINCE_DATE] [STATUS]"
        log_error "Use 'SKIP' to skip a parameter"
        log_error ""
        log_error "Examples:"
        log_error "  search-filtered 'admin@domain.com' 'invoice' 'SKIP' 'UNSEEN'"
        log_error "  search-filtered 'SKIP' 'verification' '2024-01-01' 'SKIP'"
        log_error "  search-filtered 'support@domain.com' 'SKIP' 'SKIP' 'SEEN'"
        return 1
    fi
    
    # Build IMAP search criteria
    local criteria=""
    
    if [[ -n "$sender" && "$sender" != "SKIP" ]]; then
        if [[ "$sender" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            criteria="$criteria FROM \"$sender\""
        else
            log_error "Invalid sender email format: $sender"
            return 1
        fi
    fi
    
    if [[ -n "$subject" && "$subject" != "SKIP" ]]; then
        criteria="$criteria SUBJECT \"$subject\""
    fi
    
    if [[ -n "$since_date" && "$since_date" != "SKIP" ]]; then
        # Convert YYYY-MM-DD to DD-MMM-YYYY if needed
        local formatted_date="$since_date"
        if [[ "$since_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            local year month day
            year=$(echo "$since_date" | cut -d'-' -f1)
            month=$(echo "$since_date" | cut -d'-' -f2)
            day=$(echo "$since_date" | cut -d'-' -f3)
            
            local month_names=("" "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
            local month_abbr="${month_names[$((10#$month))]}"
            formatted_date="${day}-${month_abbr}-${year}"
        fi
        criteria="$criteria SINCE \"$formatted_date\""
    fi
    
    if [[ -n "$status" && "$status" != "SKIP" ]]; then
        case "$status" in
            "SEEN"|"UNSEEN"|"FLAGGED"|"UNFLAGGED"|"ANSWERED"|"UNANSWERED"|"DELETED"|"UNDELETED"|"DRAFT"|"UNDRAFT")
                criteria="$criteria $status"
                ;;
            *)
                log_warning "Unknown status: $status. Using anyway..."
                criteria="$criteria $status"
                ;;
        esac
    fi
    
    # Trim leading whitespace
    criteria=$(echo "$criteria" | xargs)
    
    log_info "Filtered search with criteria: $criteria"
    
    local search_response
    search_response=$(execute_imap_command "A003 SEARCH $criteria" 4)
    
    local email_ids
    email_ids=$(parse_email_ids "$search_response")
    
    if [[ -z "$email_ids" ]]; then
        log_warning "No emails found with specified filters"
        return
    fi
    
    # Convert to array to count
    local ids_array
    read -ra ids_array <<< "$email_ids"
    local count=${#ids_array[@]}
    
    if [[ $count -eq 1 ]]; then
        local single_id="${ids_array[0]}"
        log_success "Found 1 email matching filters (ID: $single_id)"
        echo "Auto-reading the email..."
        echo ""
        read_email "$single_id"
        return
    fi
    
    log_success "Found $count emails with IDs: $email_ids"
    echo ""
    
    # Show details for each found email
    for email_id in "${ids_array[@]}"; do
        if [[ ! "$email_id" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        echo "=== Email ID: $email_id ==="
        local email_info
        email_info=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        echo "$email_info" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        echo ""
        sleep 0.5
    done
    
    echo "Use 'read <EMAIL_ID>' to read full content of any email above"
}

# Function to extract URLs from emails by sender with pattern matching
extract_urls_from_sender() {
    local input="$1"
    local url_pattern="$2"
    local subject_filter="$3"
    local output_file="${4:-url_extracts.csv}"
    
    if [[ -z "$input" ]]; then
        log_error "Email address or CSV file is required"
        return 1
    fi
    
    if [[ -z "$url_pattern" ]]; then
        log_error "URL pattern is required (example: https://domain.com/verify/)"
        return 1
    fi
    
    log_info "Extracting URLs with pattern: $url_pattern"
    if [[ -n "$subject_filter" ]]; then
        log_info "Subject filter: $subject_filter"
    fi
    log_info "Results will be saved to: $output_file"
    
    # Create output CSV header
    echo "email,subject,matchURL" > "$output_file"
    
    # Auto-detect if input is a file or email address
    local sender_emails=()
    
    if [[ -f "$input" ]]; then
        log_info "Processing CSV file: $input"
        
        # Validate CSV format
        local header
        header=$(head -n 1 "$input")
        if [[ "$header" != "email" ]]; then
            log_error "Invalid CSV format. Header must be: email"
            return 1
        fi
        
        # Read emails from CSV
        while IFS=',' read -r email; do
            email=$(echo "$email" | xargs)  # Trim whitespace
            if [[ -n "$email" ]]; then
                sender_emails+=("$email")
            fi
        done < <(tail -n +2 "$input")
        
    elif [[ "$input" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        log_info "Processing single email: $input"
        sender_emails=("$input")
    else
        log_error "Input must be either a valid email address or existing CSV file"
        return 1
    fi
    
    local total_processed=0
    local total_found=0
    
    # Process each sender email
    for sender_email in "${sender_emails[@]}"; do
        ((total_processed++))
        log_info "Processing emails from: $sender_email"
        
        # Search emails from this sender with subject filter if provided
        local search_response
        local email_ids
        
        if [[ -n "$subject_filter" ]]; then
            log_info "Searching with subject filter: '$subject_filter'"
            # Use combined search (sender + subject)
            search_response=$(execute_imap_command "A003 SEARCH FROM \"$sender_email\" SUBJECT \"$subject_filter\"" 4)
        else
            log_info "Searching all emails from sender"
            # Use sender-only search
            search_response=$(execute_imap_command "A003 SEARCH FROM \"$sender_email\"" 4)
        fi
        
        email_ids=$(parse_email_ids "$search_response")
        
        if [[ -z "$email_ids" ]]; then
            if [[ -n "$subject_filter" ]]; then
                log_warning "No emails found from: $sender_email with subject: '$subject_filter'"
                echo "$sender_email,\"No emails found with subject filter\",No emails found" >> "$output_file"
            else
                log_warning "No emails found from: $sender_email"
                echo "$sender_email,N/A,No emails found" >> "$output_file"
            fi
            continue
        fi
        
        local found_url=""
        local found_subject=""
        local ids_array
        read -ra ids_array <<< "$email_ids"
        
        log_info "Found ${#ids_array[@]} emails to check"
        
        # Search through emails for matching URL
        for email_id in "${ids_array[@]}"; do
            if [[ ! "$email_id" =~ ^[0-9]+$ ]]; then
                continue
            fi
            
            log_info "Checking email ID: $email_id"
            
            # Get email subject first (for CSV output)
            local email_subject
            email_subject=$(get_email_subject "$email_id")
            
            # Get email body content
            local email_body
            email_body=$(extract_email_body "$email_id")
            
            if [[ -n "$email_body" ]]; then
                # Search for URL pattern in email body using enhanced extraction
                found_url=$(extract_url_with_pattern "$email_body" "$url_pattern")
                
                if [[ -n "$found_url" ]]; then
                    found_subject="$email_subject"
                    log_success "Found matching URL in email $email_id: $found_url"
                    break
                fi
            fi
            
            sleep 0.5
        done
        
        # Add result to CSV
        if [[ -n "$found_url" ]]; then
            echo "$sender_email,\"$found_subject\",$found_url" >> "$output_file"
            ((total_found++))
        else
            if [[ -n "$subject_filter" ]]; then
                log_warning "No matching URL found for: $sender_email with subject filter: '$subject_filter'"
                echo "$sender_email,\"Subject filter applied but no URL match\",No matching URL found" >> "$output_file"
            else
                log_warning "No matching URL found for: $sender_email"
                echo "$sender_email,\"No URL match\",No matching URL found" >> "$output_file"
            fi
        fi
        
        sleep 1
    done
    
    log_success "URL extraction completed!"
    log_success "Processed: $total_processed senders"
    log_success "URLs found: $total_found"
    log_success "Results saved to: $output_file"
    
    # Show summary
    echo ""
    echo "=== EXTRACTION SUMMARY ==="
    echo "Total senders processed: $total_processed"
    echo "URLs found: $total_found"
    echo "Results file: $output_file"
    echo ""
    echo "CSV Content Preview:"
    head -10 "$output_file"
}

# Helper function to get email subject only
get_email_subject() {
    local email_id=$1
    local temp_file=$(mktemp)
    
    {
        echo "A001 LOGIN $USERNAME $PASSWORD"
        sleep 2
        echo "A002 SELECT INBOX"
        sleep 2
        echo "A003 FETCH $email_id BODY[HEADER.FIELDS (SUBJECT)]"
        sleep 3
        echo "A004 LOGOUT"
        sleep 1
    } | openssl s_client -connect $IMAP_SERVER:993 -quiet > "$temp_file" 2>&1
    
    local subject
    subject=$(grep -i "Subject:" "$temp_file" | cut -d' ' -f2- | tr -d '\r\n' | xargs)
    
    rm "$temp_file"
    echo "${subject:-No Subject}"
}

# Helper function to extract email body content only

# Helper function to extract email body content only
extract_email_body() {
    local email_id=$1
    local temp_file=$(mktemp)
    local body_content=""
    
    # Try BODY[TEXT] first
    {
        echo "A001 LOGIN $USERNAME $PASSWORD"
        sleep 2
        echo "A002 SELECT INBOX"
        sleep 2
        echo "A003 FETCH $email_id BODY[TEXT]"
        sleep 5
        echo "A004 LOGOUT"
        sleep 1
    } | openssl s_client -connect $IMAP_SERVER:993 -quiet > "$temp_file" 2>&1
    
    # Parse body content
    if grep -q "BODY\[TEXT\]" "$temp_file"; then
        # Method A: AWK parsing
        body_content=$(awk '/A003.*FETCH.*BODY\[TEXT\]/{flag=1; next} /^A004|^\)/{flag=0} flag' "$temp_file" | grep -v "^A003\|^$")
        
        if [[ -z "$body_content" ]]; then
            # Method B: Simple grep
            local raw_body
            raw_body=$(grep -A 999 "BODY\[TEXT\]" "$temp_file" | tail -n +2)
            local line_count
            line_count=$(echo "$raw_body" | wc -l)
            if [[ $line_count -gt 2 ]]; then
                body_content=$(echo "$raw_body" | head -n $((line_count - 2)))
            else
                body_content="$raw_body"
            fi
            body_content=$(echo "$body_content" | grep -v "^A004\|^)\|^$")
        fi
    fi
    
    # If BODY[TEXT] failed, try BODY[] (full email)
    if [[ -z "$body_content" ]]; then
        {
            echo "A001 LOGIN $USERNAME $PASSWORD"
            sleep 2
            echo "A002 SELECT INBOX"
            sleep 2
            echo "A003 FETCH $email_id BODY[]"
            sleep 5
            echo "A004 LOGOUT"
            sleep 1
        } | openssl s_client -connect $IMAP_SERVER:993 -quiet > "$temp_file" 2>&1
        
        if grep -q "BODY\[\]" "$temp_file"; then
            local full_content
            full_content=$(awk '/A003.*FETCH.*BODY\[\]/{flag=1; next} /^A004|^\)/{flag=0} flag' "$temp_file")
            
            # Extract body part after empty line
            local body_start_line
            body_start_line=$(echo "$full_content" | grep -n "^$" | head -1 | cut -d: -f1)
            
            if [[ -n "$body_start_line" ]]; then
                body_content=$(echo "$full_content" | tail -n +$((body_start_line + 1)))
            else
                body_content=$(echo "$full_content" | tail -n +10)
            fi
        fi
    fi
    
    rm "$temp_file"
    echo "$body_content"
}

# Enhanced function to extract URLs with quoted-printable handling
extract_url_with_pattern() {
    local email_body="$1"
    local url_pattern="$2"
    
    # Step 1: Clean up the email body by removing newlines and joining quoted-printable lines
    local cleaned_body
    cleaned_body=$(echo "$email_body" | tr '\n' ' ' | sed 's/= /=/g' | sed 's/=$//')
    
    # Step 2: Further clean quoted-printable encoding (= followed by newline)
    cleaned_body=$(echo "$cleaned_body" | sed 's/=[ \t]*$//g' | tr -d '\r')
    
    # Step 3: Extract URLs that match the pattern
    local found_url
    
    # Method 1: Try to find complete URL in angle brackets first
    found_url=$(echo "$cleaned_body" | grep -o "<${url_pattern}[^>]*>" | sed 's/^<//;s/>$//' | head -1)
    
    if [[ -z "$found_url" ]]; then
        # Method 2: Try to find URL in href attributes
        found_url=$(echo "$cleaned_body" | grep -o "href=[\"']${url_pattern}[^\"']*[\"']" | sed "s/href=[\"']//;s/[\"']$//" | head -1)
    fi
    
    if [[ -z "$found_url" ]]; then
        # Method 3: Try to find plain URL (with potential line breaks)
        found_url=$(echo "$cleaned_body" | grep -o "${url_pattern}[^[:space:]<>\"']*" | head -1)
    fi
    
    # Step 4: Clean up the found URL
    if [[ -n "$found_url" ]]; then
        # Remove any trailing = characters (quoted-printable artifacts)
        found_url=$(echo "$found_url" | sed 's/=*$//')
        
        # Fix any broken quoted-printable encoding in the URL
        found_url=$(echo "$found_url" | sed 's/=0A//g' | sed 's/=20/ /g' | sed 's/=3D/=/g')
        
        # Remove any remaining whitespace
        found_url=$(echo "$found_url" | tr -d ' \t\r\n')
    fi
    
    echo "$found_url"
}

# Function to debug email parsing
debug_email_parsing() {
    local email_id=$1
    
    if [[ -z "$email_id" ]]; then
        log_error "Email ID is required for debugging"
        return 1
    fi
    
    log_info "Debug mode for email ID: $email_id"
    
    local temp_file=$(mktemp)
    
    {
        echo "A001 LOGIN $USERNAME $PASSWORD"
        sleep 2
        echo "A002 SELECT INBOX"
        sleep 2
        echo "A003 FETCH $email_id BODY[TEXT]"
        sleep 8  # Longer delay for debugging
        echo "A004 LOGOUT" 
        sleep 1
    } | openssl s_client -connect $IMAP_SERVER:993 -quiet > "$temp_file" 2>&1
    
    echo "=== RAW IMAP RESPONSE ==="
    cat "$temp_file"
    
    echo -e "\n=== HEX DUMP ==="
    hexdump -C "$temp_file" | head -20
    
    echo -e "\n=== LINE BY LINE WITH NUMBERS ==="
    nl "$temp_file"
    
    echo -e "\n=== PARSING ATTEMPTS ==="
    
    echo "--- Method 1: Simple grep after FETCH ---"
    grep -A 999 "FETCH.*BODY\[TEXT\]" "$temp_file" | tail -n +2 | head -n -2
    
    echo -e "\n--- Method 2: AWK parsing ---"
    awk '/FETCH.*BODY\[TEXT\]/{flag=1; next} /A004|^\)/{flag=0} flag' "$temp_file"
    
    echo -e "\n--- Method 3: Sed parsing ---"
    sed -n '/FETCH.*BODY\[TEXT\]/,/A004\|^\)/p' "$temp_file" | sed '1d;$d'
    
    echo -e "\n--- Method 4: After size indicator ---" 
    if grep -q "BODY\[TEXT\].*{[0-9]*}" "$temp_file"; then
        local size=$(grep "BODY\[TEXT\]" "$temp_file" | grep -o '{[0-9]*}' | tr -d '{}')
        echo "Detected size: $size bytes"
        # Try to extract exactly that many bytes
        grep -A 999 "BODY\[TEXT\].*{[0-9]*}" "$temp_file" | tail -n +2 | head -c "$size" 2>/dev/null
    fi
    
    rm "$temp_file"
}

# Function to get latest N emails
get_latest_emails() {
    local count="$1"
    
    if [[ -z "$count" ]]; then
        count=5
    fi
    
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        log_error "Count must be a number"
        return 1
    fi
    
    log_info "Getting latest $count emails..."
    
    # Get total email count first
    local response
    response=$(execute_imap_command "A003 STATUS INBOX (MESSAGES)" 3)
    local total_count
    total_count=$(echo "$response" | grep "MESSAGES" | grep -o '[0-9]*' | tail -1)
    
    if [[ -z "$total_count" || "$total_count" -eq 0 ]]; then
        log_warning "No emails found in INBOX"
        return
    fi
    
    # Calculate start email ID
    local start_id=$((total_count - count + 1))
    if [[ $start_id -lt 1 ]]; then
        start_id=1
    fi
    
    log_info "Showing emails from ID $start_id to $total_count"
    echo ""
    
    # Show latest emails
    for i in $(seq $start_id $total_count); do
        echo "=== Email ID: $i ==="
        local email_info
        email_info=$(execute_imap_command "A003 FETCH $i BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        echo "$email_info" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        echo ""
        sleep 0.5
    done
}

# Function to read emails from specific sender (with content)
read_emails_from_sender() {
    local sender_email="$1"
    
    if [[ -z "$sender_email" ]]; then
        log_error "Sender email is required"
        return 1
    fi
    
    log_info "Reading all emails from: $sender_email"
    
    local search_response
    search_response=$(execute_imap_command "A003 SEARCH FROM \"$sender_email\"" 4)
    
    local email_ids
    email_ids=$(parse_email_ids "$search_response")
    
    if [[ -z "$email_ids" ]]; then
        log_warning "No emails found from $sender_email"
        return
    fi
    
    log_success "Found emails from $sender_email with IDs: $email_ids"
    echo ""
    
    # Read full content for each email
    for email_id in $email_ids; do
        echo "=================================="
        echo "Reading Email ID: $email_id"
        echo "=================================="
        
        # Get headers
        local headers
        headers=$(execute_imap_command "A003 FETCH $email_id BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 3)
        echo "$headers" | grep -E "(From|Subject|Date):" | sed 's/^[[:space:]]*//'
        
        echo -e "\n--- Email Body ---"
        
        # Get body with improved parsing
        local temp_file=$(mktemp)
        
        {
            echo "A001 LOGIN $USERNAME $PASSWORD"
            sleep 2
            echo "A002 SELECT INBOX"
            sleep 2
            echo "A003 FETCH $email_id BODY[TEXT]"
            sleep 5
            echo "A004 LOGOUT"
            sleep 1
        } | openssl s_client -connect $IMAP_SERVER:993 -quiet > "$temp_file" 2>&1
        
        # Try to extract body content
        if grep -q "BODY\[TEXT\]" "$temp_file"; then
            # Extract content after FETCH response
            awk '/A003.*FETCH.*BODY\[TEXT\]/{flag=1; next} /^A004/{flag=0} flag' "$temp_file" | \
            grep -v "^A003\|^)\|^$" | head -n -1
        else
            echo "Could not retrieve email body"
        fi
        
        rm "$temp_file"
        echo -e "\n"
        sleep 1
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--server)
            IMAP_SERVER="$2"
            shift 2
            ;;
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    log_error "openssl not found. Please install openssl first:"
    log_error "Ubuntu/Debian: sudo apt-get install openssl"
    log_error "CentOS/RHEL: sudo yum install openssl"
    log_error "macOS: brew install openssl"
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
        list_emails
        ;;
    count)
        count_emails
        ;;
    read)
        read_email "$1"
        ;;
    search-sender)
        search_by_sender "$1" "$2"
        ;;
    search-sender-batch)
        search_sender_batch "$1" "$2"
        ;;
    process-results)
        process_batch_results "$1" "$2" "$3"
        ;;
    search-subject)
        search_by_subject "$1"
        ;;
    search-date)
        search_by_date "$1"
        ;;
    unread)
        get_unread_emails
        ;;
    latest)
        get_latest_emails "$1"
        ;;
    read-from-sender)
        read_emails_from_sender "$1"
        ;;
    search-sender-subject)
        search_by_sender_and_subject "$1" "$2"
        ;;
    search-advanced)
        search_advanced "$1"
        ;;
    search-filtered)
        search_filtered "$1" "$2" "$3" "$4"
        ;;
    extract-urls)
        extract_urls_from_sender "$1" "$2" "$3" "$4"
        ;;
    debug-email)
        debug_email_parsing "$1"
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
