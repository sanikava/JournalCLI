#!/bin/bash

# --- Simple Journal CLI in Bash ---
#
# This script allows you to:
# - Add new journal entries for the current day.
# - List all existing journal entries, organized by date.
# - View the content of a specific journal entry or all entries for a given date.
#
# Journal entries are stored in a hidden directory in your home folder: ~/.journal_cli/entries/
# Each entry is saved as a text file within a Year/Month/Day directory structure.

# --- Configuration ---
JOURNAL_BASE_DIR="$HOME/.journal_cli"
JOURNAL_ENTRIES_DIR="$JOURNAL_BASE_DIR/entries"

# --- Colors for better output (Optional) ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Ensure Journal Directory Exists ---
# This function creates the base directory and the entries directory if they don't exist.
# It exits with an error message if directory creation fails.
ensure_journal_dirs() {
  mkdir -p "$JOURNAL_ENTRIES_DIR" || { echo -e "${RED}Error: Could not create journal directory: $JOURNAL_ENTRIES_DIR${NC}"; exit 1; }
}

# --- Help Function ---
# Displays the usage instructions for the script.
show_help() {
  echo -e "${BOLD}Journal CLI Usage:${NC}"
  echo "  ${0##*/} add           - Add a new journal entry for today."
  echo "  ${0##*/} list          - List all journal entries by date."
  echo "  ${0##*/} view <date>   - View entries for a specific date (YYYY-MM-DD)."
  echo "  ${0##*/} view <file>   - View a specific entry file (e.g., 2024/07/05/2024-07-05_103000.txt)."
  echo "  ${0##*/} help          - Show this help message."
  echo ""
  echo "Examples:"
  echo "  ./journal.sh add"
  echo "  ./journal.sh list"
  echo "  ./journal.sh view $(date +%Y-%m-%d)"
  echo "  ./journal.sh view 2024/07/04/2024-07-04_154530.txt"
}

# --- Add Entry Function ---
# Prompts the user to type a new journal entry and saves it to a file.
# The file is named with the current date and timestamp, and stored in a
# Year/Month/Day directory structure.
add_entry() {
  local current_date=$(date +%Y-%m-%d)
  local current_time=$(date +%H%M%S)
  local year=$(date +%Y)
  local month=$(date +%m)
  local day=$(date +%d)

  local entry_dir="$JOURNAL_ENTRIES_DIR/$year/$month/$day"
  local entry_filename="${current_date}_${current_time}.txt"
  local entry_filepath="$entry_dir/$entry_filename"

  echo -e "${YELLOW}Adding a new journal entry for ${BOLD}$current_date${NC}${YELLOW} at ${BOLD}$current_time${NC}"
  echo -e "${YELLOW}Type your entry. Press ${BOLD}Ctrl+D${NC}${YELLOW} when done.${NC}"
  echo "----------------------------------------------------"

  # Create date-specific directory if it doesn't exist
  mkdir -p "$entry_dir" || { echo -e "${RED}Error: Could not create directory $entry_dir${NC}"; exit 1; }

  # Read input until EOF (Ctrl+D) and save to file
  cat > "$entry_filepath"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Journal entry saved to: ${BOLD}$entry_filepath${NC}"
  else
    echo -e "${RED}Error: Failed to save journal entry.${NC}"
    rm -f "$entry_filepath" # Clean up partially created file if error occurred
    exit 1
  fi
}

# --- List Entries Function ---
# Finds and lists all journal entries (.txt files) in the journal directory.
# Entries are listed by their relative path from the base journal directory.
list_entries() {
  echo -e "${BOLD}--- Your Journal Entries ---${NC}"

  # Find all .txt files in the journal directory
  # Use -print0 and read -r -d $'\0' for robustness with filenames containing spaces/newlines
  local entries_found=0
  while IFS= read -r -d $'\0' filepath; do
    local relative_path="${filepath#$JOURNAL_ENTRIES_DIR/}"
    echo "  ${GREEN}$relative_path${NC}"
    entries_found=1
  done < <(find "$JOURNAL_ENTRIES_DIR" -type f -name "*.txt" -print0 | sort -z -r) # Sort newest first

  if [ "$entries_found" -eq 0 ]; then
    echo -e "${YELLOW}No journal entries found.${NC}"
  fi
  echo "----------------------------"
}

# --- View Entry Function ---
# Displays the content of journal entries based on the provided argument.
# It can view entries for a specific date (YYYY-MM-DD) or a full entry file path.
view_entry() {
  if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide a date (YYYY-MM-DD) or a full entry file path to view.${NC}"
    show_help
    exit 1
  }

  local search_term="$1"
  local found_entries=()

  # Check if the input looks like a full file path (e.g., 2024/07/05/2024-07-05_103000.txt)
  if [[ "$search_term" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}\.txt$ ]]; then
    local full_path="$JOURNAL_ENTRIES_DIR/$search_term"
    if [ -f "$full_path" ]; then
      found_entries+=("$full_path")
    fi
  # Check if the input looks like a date (YYYY-MM-DD)
  elif [[ "$search_term" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    local year="${search_term:0:4}"
    local month="${search_term:5:2}"
    local day="${search_term:8:2}"
    local date_dir="$JOURNAL_ENTRIES_DIR/$year/$month/$day"

    if [ -d "$date_dir" ]; then
      # Find all .txt files in that specific date directory
      while IFS= read -r -d $'\0'\ filepath; do
        found_entries+=("$filepath")
      done < <(find "$date_dir" -maxdepth 1 -type f -name "*.txt" -print0 | sort -z) # Sort oldest first for a given day
    fi
  else
    echo -e "${RED}Error: Invalid format for view. Use YYYY-MM-DD or a full entry file path.${NC}"
    show_help
    exit 1
  fi

  if [ ${#found_entries[@]} -eq 0 ]; then
    echo -e "${YELLOW}No entries found for '$search_term'.${NC}"
    exit 0
  fi

  for entry_path in "${found_entries[@]}"; do
    local relative_path="${entry_path#$JOURNAL_ENTRIES_DIR/}"
    echo -e "${BOLD}--- Entry: $relative_path ---${NC}"
    cat "$entry_path"
    echo -e "${BOLD}----------------------------------------------------${NC}"
    echo ""
  done
}

# --- Main Script Logic ---
# This is the entry point of the script. It parses the first argument
# to determine which function to call.
main() {
  ensure_journal_dirs # Make sure directories are ready before any operations

  case "$1" in
    "add")
      add_entry
      ;;
    "list")
      list_entries
      ;;
    "view")
      shift # Remove 'view' from arguments so view_entry gets the date/file
      view_entry "$@"
      ;;
    "help")
      show_help
      ;;
    *)
      # If no arguments or an unknown command is given, show help
      echo -e "${RED}Error: Unknown command or no command provided.${NC}"
      show_help
      exit 1
      ;;
  esac
}

# Call the main function with all command-line arguments
main "$@"
