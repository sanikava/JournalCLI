# --- Function: list_entries ---
# Finds and lists all journal entry files, with optional pagination.
# Displays entries in a paginated table format.
# Arguments: $1 = page number (optional, defaults to 1)
#            $2 = entries per page (optional, defaults to 10, max 10)
list_entries() {
  local page_num=${1:-1} # Default to page 1 if not provided
  local per_page=${2:-10} # Default to 10 per page if not provided

  # Validate per_page: must be between 1 and 10
  if (( per_page < 1 || per_page > 10 )); then
    echo -e "${RED}Error: Entries per page must be between 1 and 10.${NC}"
    show_help
    exit 1
  fi

  # Find all .txt files and store them in an array, sorted by date (newest first)
  # Using mapfile (Bash 4+) for efficiency to load all paths into an array.
  # If mapfile is not available (older Bash), a while loop with array push can be used.
  local all_entries=()
  while IFS= read -r -d $'\0'\ filepath; do
    all_entries+=("$filepath")
  done < <(find "$JOURNAL_ENTRIES_DIR" -type f -name "*.txt" -print0 | sort -z -r)

  local total_entries=${#all_entries[@]}
  if [ "$total_entries" -eq 0 ]; then
    echo -e "${YELLOW}No journal entries found.${NC}"
    return 0 # Exit function gracefully
  fi

  # Calculate total pages
  local total_pages=$(( (total_entries + per_page - 1) / per_page ))

  # Validate page number
  if (( page_num < 1 || page_num > total_pages )); then
    echo -e "${RED}Error: Page number $page_num is out of range. Total pages: $total_pages.${NC}"
    return 1
  fi

  local start_index=$(( (page_num - 1) * per_page ))
  local end_index=$(( start_index + per_page - 1 ))

  echo -e "${BOLD}--- Your Journal Entries (Page $page_num of $total_pages) ---${NC}"
  # Use %b to interpret backslash escapes in printf
  printf "%-5b %-20b %-10b %b\n" "${BOLD}ID${NC}" "${BOLD}Date${NC}" "${BOLD}Time${NC}" "${BOLD}Path (Partial)${NC}"
  echo "--------------------------------------------------------------------------------"

  local current_id=0
  for (( i=start_index; i<=end_index && i<total_entries; i++ )); do
    local filepath="${all_entries[$i]}"
    local relative_path="${filepath#$JOURNAL_ENTRIES_DIR/}"

    # Extract date and time from the filename (e.g., 2024-07-05_031628.txt)
    local filename=$(basename "$filepath")
    local entry_date=$(echo "$filename" | cut -d'_' -f1) # YYYY-MM-DD
    local entry_time_raw=$(echo "$filename" | cut -d'_' -f2 | cut -d'.' -f1) # HHMMSS
    local entry_time="${entry_time_raw:0:2}:${entry_time_raw:2:2}:${entry_time_raw:4:2}" # HH:MM:SS

    # Print the entry details. %s for strings, no special interpretation needed here.
    printf "%-5s %-20s %-10s %s\n" "$((i + 1))" "$entry_date" "$entry_time" "$relative_path"
  done
  echo "--------------------------------------------------------------------------------"
  echo -e "${YELLOW}Total entries: $total_entries.${NC}"
}
