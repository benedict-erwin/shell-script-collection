#!/bin/bash

# Astronomical Email Generator Script
# Usage: ./email_generator.sh [number_of_emails] [domain] [output_file]

# Default values
DEFAULT_COUNT=200
DEFAULT_DOMAIN="your-email-domain.com"
DEFAULT_OUTPUT="astronomical_emails.csv"

# Help function
show_help() {
    echo "Astronomical Email Generator"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --count NUMBER    Number of emails to generate (default: $DEFAULT_COUNT)"
    echo "  -d, --domain DOMAIN   Email domain (default: $DEFAULT_DOMAIN)"
    echo "  -o, --output FILE     Output CSV file (default: $DEFAULT_OUTPUT)"
    echo "  -g, --group NUMBER    Emails per constellation group (default: 50)"
    echo "  -u, --unique          Force unique emails using sort & uniq (removes duplicates)"
    echo "  -s, --sort            Sort output by constellation groups"
    echo "  -p, --pattern NUMBER  Email pattern (1-8, default: 1)"
    echo "                        1: celestial_constellation (default)"
    echo "                        2: constellation_celestial (reverse)"  
    echo "                        3: celestial.constellation (dot)"
    echo "                        4: celestial-constellation (hyphen)"
    echo "                        5: celestialconstellation (no separator)"
    echo "                        6: constellation.celestial (reverse dot)"
    echo "                        7: constellation-celestial (reverse hyphen)"
    echo "                        8: constellationcelestial (reverse no separator)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -n 1000 -d mydomain.com -o my_emails.csv"
    echo "  $0 --count 500 --group 25"
    echo "  $0 -n 5000 --unique   # Force unique for large counts"
    echo "  $0 -n 1000 --sort     # Sort by constellation groups"
    echo "  $0 -n 2000 -p 2       # Use reverse pattern: constellation_celestial"
    echo "  $0 -n 8000 -p 3 --unique --sort  # Dot pattern, unique, sorted"
}

# Arrays for astronomical objects
declare -a PLANETS=(
    "mercury" "venus" "earth" "mars" 
    "jupiter" "saturn" "uranus" "neptune"
)

declare -a STARS=(
    "sirius" "vega" "altair" "rigel" "betelgeuse"
    "arcturus" "capella" "aldebaran" "spica" "antares"
    "pollux" "regulus" "deneb" "canopus" "procyon"
    "achernar" "hadar" "fomalhaut" "bellatrix" "elnath"
    "alnilam" "alnitak" "mintaka" "saiph" "adhara"
    "shaula" "castor" "mizar" "alkaid" "dubhe"
    "merak" "phecda" "megrez" "alioth" "thuban"
    "kochab" "pherkad" "polaris" "schedar" "caph"
    "gamma" "ruchbah"
)

# Constellations ordered by popularity/recognition
declare -a CONSTELLATIONS=(
    "orion"
    "cassiopeia" 
    "ursa.major"
    "ursa.minor"
    "canis.major"
    "canis.minor"
    "corona.borealis"
    "coma.berenices"
    "piscis.austrinus"
    "leo.minor"
    "serpens.caput"
    "serpens.cauda"
    "corona.australis"
    "triangulum.australe"
    "ara"
    "lynx"
    "crater"
    "volans"
    "draco"
    "cygnus"
    "lyra"
    "aquila"
    "perseus"
    "andromeda"
    "pegasus"
    "hercules"
    "bootes"
    "gemini"
    "leo"
    "virgo"
    "libra"
    "scorpius"
    "sagittarius"
    "capricorn"
    "aquarius"
    "pisces"
    "aries"
    "taurus"
    "cancer"
    "ophiuchus"
    "centaurus"
    "crux"
    "eridanus"
    "hydra"
    "fornax"
    "sculptor"
    "phoenix"
    "grus"
    "tucana"
    "indus"
    "pavo"
    "apus"
    "chamaeleon"
    "musca"
    "triangulum"
    "lacerta"
    "delphinus"
    "equuleus"
    "sagitta"
    "vulpecula"
    "scutum"
    "sextans"
    "corvus"
    "hydrus"
    "dorado"
    "pictor"
    "columba"
    "lepus"
    "monoceros"
    "puppis"
    "pyxis"
    "antlia"
    "vela"
    "carina"
    "reticulum"
    "horologium"
    "caelum"
    "mensa"
    "octans"
    "telescopium"
    "microscopium"
    "norma"
    "lupus"
    "circinus"
    "camelopardalis"
)

# Parse command line arguments
COUNT=$DEFAULT_COUNT
DOMAIN=$DEFAULT_DOMAIN
OUTPUT=$DEFAULT_OUTPUT
GROUP_SIZE=50
FORCE_UNIQUE=false
SORT_BY_CONSTELLATION=false
EMAIL_PATTERN=1

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--count)
            COUNT="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -g|--group)
            GROUP_SIZE="$2"
            shift 2
            ;;
        -u|--unique)
            FORCE_UNIQUE=true
            shift
            ;;
        -s|--sort)
            SORT_BY_CONSTELLATION=true
            shift
            ;;
        -p|--pattern)
            EMAIL_PATTERN="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate inputs
if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -le 0 ]; then
    echo "Error: Count must be a positive integer"
    exit 1
fi

if ! [[ "$GROUP_SIZE" =~ ^[0-9]+$ ]] || [ "$GROUP_SIZE" -le 0 ]; then
    echo "Error: Group size must be a positive integer"
    exit 1
fi

if ! [[ "$EMAIL_PATTERN" =~ ^[1-8]$ ]]; then
    echo "Error: Pattern must be between 1-8"
    echo "Use --help to see available patterns"
    exit 1
fi

# Function to generate email based on pattern
generate_email_by_pattern() {
    local celestial_obj=$1
    local constellation=$2
    local domain=$3
    local pattern=$4
    
    case $pattern in
        1)
            echo "${celestial_obj}_${constellation}@${domain}"
            ;;
        2)
            echo "${constellation}_${celestial_obj}@${domain}"
            ;;
        3)
            echo "${celestial_obj}.${constellation}@${domain}"
            ;;
        4)
            echo "${celestial_obj}-${constellation}@${domain}"
            ;;
        5)
            echo "${celestial_obj}${constellation}@${domain}"
            ;;
        6)
            echo "${constellation}.${celestial_obj}@${domain}"
            ;;
        7)
            echo "${constellation}-${celestial_obj}@${domain}"
            ;;
        8)
            echo "${constellation}${celestial_obj}@${domain}"
            ;;
        *)
            echo "${celestial_obj}_${constellation}@${domain}"
            ;;
    esac
}

# Function to get pattern name
get_pattern_name() {
    local pattern=$1
    case $pattern in
        1) echo "celestial_constellation (default)" ;;
        2) echo "constellation_celestial (reverse)" ;;
        3) echo "celestial.constellation (dot)" ;;
        4) echo "celestial-constellation (hyphen)" ;;
        5) echo "celestialconstellation (no separator)" ;;
        6) echo "constellation.celestial (reverse dot)" ;;
        7) echo "constellation-celestial (reverse hyphen)" ;;
        8) echo "constellationcelestial (reverse no separator)" ;;
        *) echo "unknown pattern" ;;
    esac
}
get_celestial_object() {
    local index=$1
    local total_objects=$((${#PLANETS[@]} + ${#STARS[@]}))
    local obj_index=$((index % total_objects))
    
    if [ $obj_index -lt ${#PLANETS[@]} ]; then
        echo "${PLANETS[$obj_index]}"
    else
        local star_index=$((obj_index - ${#PLANETS[@]}))
        echo "${STARS[$star_index]}"
    fi
}

# Function to get constellation
get_constellation() {
    local group_num=$1
    local const_index=$((group_num % ${#CONSTELLATIONS[@]}))
    echo "${CONSTELLATIONS[$const_index]}"
}

# Generate emails
generate_emails() {
    local count=$1
    local domain=$2
    local output=$3
    local group_size=$4
    local force_unique=$5
    local sort_by_constellation=$6
    local email_pattern=$7
    
    echo "Generating $count astronomical emails..."
    echo "Domain: $domain"
    echo "Output file: $output"
    echo "Emails per constellation: $group_size"
    echo "Email pattern: $(get_pattern_name $email_pattern)"
    if [ "$force_unique" = true ]; then
        echo "Force unique: ENABLED (will remove duplicates)"
    fi
    if [ "$sort_by_constellation" = true ]; then
        echo "Sort by constellation: ENABLED"
    fi
    echo ""
    
    # Create temporary file for generation
    local temp_file=$(mktemp)
    
    # Create CSV header
    echo "email" > "$temp_file"
    
    local email_count=0
    local group_num=0
    
    while [ $email_count -lt $count ]; do
        local constellation=$(get_constellation $group_num)
        local emails_in_group=0
        
        echo "Generating group $((group_num + 1)): $constellation constellation..."
        
        while [ $emails_in_group -lt $group_size ] && [ $email_count -lt $count ]; do
            local celestial_obj=$(get_celestial_object $email_count)
            local email=$(generate_email_by_pattern "$celestial_obj" "$constellation" "$domain" "$email_pattern")
            
            echo "$email" >> "$temp_file"
            
            ((email_count++))
            ((emails_in_group++))
        done
        
        ((group_num++))
    done
    
    # Process uniqueness if requested
    if [ "$force_unique" = true ]; then
        echo ""
        echo "🔄 Processing uniqueness..."
        
        # Count original emails (excluding header)
        local original_count=$(( $(wc -l < "$temp_file") - 1 ))
        
        # Create temp file for unique processing
        local unique_temp=$(mktemp)
        
        # Extract header
        head -n 1 "$temp_file" > "$unique_temp"
        
        # Sort and remove duplicates from the email body (skip header)
        tail -n +2 "$temp_file" | sort | uniq >> "$unique_temp"
        
        # Replace temp file with unique version
        mv "$unique_temp" "$temp_file"
        
        # Count final unique emails
        local final_count=$(( $(wc -l < "$temp_file") - 1 ))
        local duplicates_removed=$((original_count - final_count))
        
        echo "📊 Uniqueness processing completed:"
        echo "   Original emails: $original_count"
        echo "   Final unique emails: $final_count"
        echo "   Duplicates removed: $duplicates_removed"
        
        if [ $duplicates_removed -gt 0 ]; then
            echo "⚠️  Warning: $duplicates_removed duplicate emails were found and removed"
            echo "💡 Consider using a smaller count (≤4300) or different group size to avoid duplicates"
        else
            echo "✅ No duplicates found - all emails were already unique!"
        fi
        
        email_count=$final_count
    fi
    
    # Process sorting if requested
    if [ "$sort_by_constellation" = true ]; then
        echo ""
        echo "🔄 Sorting by constellation groups..."
        
        # Create temp file for sorting
        local sort_temp=$(mktemp)
        
        # Extract header
        head -n 1 "$temp_file" > "$sort_temp"
        
        # Sort emails by constellation first, then by celestial object
        # This needs to handle different patterns differently
        case $email_pattern in
            1|3|4|5)
                # Pattern: celestial_constellation or celestial.constellation etc
                # Use awk to extract constellation (after separator) and celestial (before separator)
                tail -n +2 "$temp_file" | awk -F'[@_.-]' '{
                    if (NF >= 3) print $2 "\t" $1 "\t" $0
                    else print $1 "\t" $1 "\t" $0
                }' | sort -k1,1 -k2,2 | cut -f3 >> "$sort_temp"
                ;;
            2|6|7|8)
                # Pattern: constellation_celestial or constellation.celestial etc  
                # Use awk to extract constellation (before separator) and celestial (after separator)
                tail -n +2 "$temp_file" | awk -F'[@_.-]' '{
                    if (NF >= 3) print $1 "\t" $2 "\t" $0
                    else print $1 "\t" $1 "\t" $0
                }' | sort -k1,1 -k2,2 | cut -f3 >> "$sort_temp"
                ;;
        esac
        
        # Replace temp file with sorted version
        mv "$sort_temp" "$temp_file"
        
        echo "✅ Emails sorted by constellation groups (constellation first, then celestial object)"
    fi
    
    # Copy final result to output
    cp "$temp_file" "$output"
    
    # Clean up temp file
    rm "$temp_file"
    
    echo ""
    echo "✅ Successfully generated $email_count emails!"
    echo "📁 Output saved to: $output"
    
    # Show statistics
    echo ""
    echo "📊 Generation Statistics:"
    echo "   Total emails: $email_count"
    echo "   Constellations used: $((group_num))"
    echo "   Email pattern: $(get_pattern_name $email_pattern)"
    echo "   Planets available: ${#PLANETS[@]}"
    echo "   Stars available: ${#STARS[@]}"
    echo "   Total celestial objects: $((${#PLANETS[@]} + ${#STARS[@]}))"
    echo "   Possible combinations: $((( ${#PLANETS[@]} + ${#STARS[@]} ) * ${#CONSTELLATIONS[@]}))"
    
    # Warning for potential duplicates
    if [ "$force_unique" = false ] && [ $count -gt 4250 ]; then
        echo ""
        echo "⚠️  WARNING: You requested $count emails, but only 4,250 unique combinations exist for this pattern."
        echo "💡 Use --unique flag to automatically remove duplicates:"
        echo "   $0 -n $count -p $email_pattern --unique"
    fi
}

# Function to preview sample emails
preview_emails() {
    echo "🔍 Sample emails preview:"
    head -10 "$OUTPUT" | tail -9
    echo "..."
    echo ""
}

# Main execution
echo "🌟 Astronomical Email Generator Started"
echo "======================================"

# Check if output file already exists
if [ -f "$OUTPUT" ]; then
    echo "⚠️  Output file '$OUTPUT' already exists."
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Generate emails
generate_emails "$COUNT" "$DOMAIN" "$OUTPUT" "$GROUP_SIZE" "$FORCE_UNIQUE" "$SORT_BY_CONSTELLATION" "$EMAIL_PATTERN"

# Preview generated emails
preview_emails

echo "🎉 Email generation completed successfully!"
echo ""
echo "💡 Tips:"
echo "   - Use different domains with -d flag"
echo "   - Adjust group size with -g flag"
echo "   - Generate more emails with -n flag"
echo "   - Use --unique flag for large counts (>4300) to remove duplicates"
echo "   - Use --sort flag to group emails by constellation"
echo "   - Try different patterns with -p flag (1-8 patterns available)"
echo "   - Combine flags: $0 -n 5000 --unique --sort -p 2"
echo "   - Each pattern can generate up to 4,300 unique emails"
echo "   - Run '$0 --help' for more options"
echo ""
