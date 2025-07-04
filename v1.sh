#!/bin/bash

# --- Simple Journal CLI in Bash ---
#
# This script provides a command-line interface for managing journal entries.
# It allows users to add, list, and view their daily thoughts and notes.
#
# Features:
# - `add`: Create a new journal entry for the current date and time.
# - `list`: Display a list of all saved journal entries, sorted by date (newest first).
# - `view <date>`: Show all entries for a specific date (format: YYYY-MM-DD).
# - `view <file_path>`: Display the content of a specific journal entry file.
#
# Journal entries are stored in a structured directory within the user's home folder:
# ~/.journal_cli/entries/YYYY/MM/DD/YYYY-MM-DD_HHMMSS.txt
#
# To use:
# 1. Save this code as `journal.sh` (or any desired name).
# 2. Make it executable: `chmod +x journal.sh`.
# 3. Run commands: `./journal.sh add`, `./journal.sh list`, `./journal.sh view 2024-07-05`, etc.

# --- Configuration ---
# Base directory for the journal CLI's data.
JOURNAL_BASE_DIR="$HOME/.journal_cli"
# Directory where actual journal entry files will be stored.
JOURNAL_ENTRIES_DIR="$JOURNAL_BASE_DIR/entries"

# --- Colors for better terminal output (Optional) ---
GREEN='\033[0;32m' # Green color for success messages
YELLOW='\033[0;33m' # Yellow color for informational messages/prompts
RED='\033[0;31m'   # Red color for error messages
NC='\033[0m'       # No Color - Resets text color to default
BOLD='\033[1m'     # Bold text

# --- Function: ensure_journal_dirs ---
# Ensures that the necessary journal directories exist.
# Creates them if they don't; exits with an error if creation fails.
ensure_journal_dirs() {
  mkdir -p "$JOURNAL_ENTRIES_DIR" || {
    echo -e "${RED}Error: Could not create journal directory: $JOURNAL_ENTRIES_DIR${NC}"
    exit 1
  }
}

# --- Function: show_help ---
# Displays the usage instructions for the script, including available commands and examples.
show_help() {
  echo -e "${BOLD}Journal CLI Usage:${NC}"
  # ${0##*/} gets the script's filename (e.g., "journal.sh")
  echo "  ${0##*/} add           - Add a new journal entry for today."
  echo "  ${0##*/} list          - List all journal entries by date."
  echo "  ${0##*/} view <date>   - View entries for a specific date (YYYY-MM-DD)."
  echo "  ${0##*/} view <file>   - View a specific entry file (e.g., 2024/07/05/2024-07-05_103000.txt)."
  echo "  ${0##*/} help          - Show this help message."
  echo ""
  echo "Examples:"
  echo "  ./journal.sh add"
  echo "  ./journal.sh list"
  echo "  ./journal.sh view $(date +%Y-%m-%d)" # Shows how to view today's entries
  echo "  ./journal.sh view 2024/07/04/2024-07-04_154530.txt"
}

# --- Function: add_entry ---
# Prompts the user to input a journal entry and saves it to a new file.
# The file is timestamped and placed in a YYYY/MM/DD directory structure.
add_entry() {
  local current_date=$(date +%Y-%m-%d) # e.g., 2024-07-05
  local current_time=$(date +%H%M%S) # e.g., 103000
  local year=$(date +%Y)
  local month=$(date +%m)
  local day=$(date +%d)

  # Construct the full path for the entry's directory and file
  local entry_dir="$JOURNAL_ENTRIES_DIR/$year/$month/$day"
  local entry_filename="${current_date}_${current_time}.txt"
  local entry_filepath="$entry_dir/$entry_filename"

  echo -e "${YELLOW}Adding a new journal entry for ${BOLD}$current_date${NC}${YELLOW} at ${BOLD}$current_time${NC}"
  echo -e "${YELLOW}Type your entry. Press ${BOLD}Ctrl+D${NC}${YELLOW} when done.${NC}"
  echo "----------------------------------------------------"

  # Create the date-specific directory if it doesn't already exist.
  # Exit with an error if directory creation fails.
  mkdir -p "$entry_dir" || {
    echo -e "${RED}Error: Could not create directory $entry_dir${NC}"
    exit 1
  }

  # Read input from stdin (user's typing) until Ctrl+D is pressed (EOF)
  # and redirect it to the journal entry file.
  cat > "$entry_filepath"

  # Check the exit status of the last command (`cat`).
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Journal entry saved to: ${BOLD}$entry_filepath${NC}"
  else
    echo -e "${RED}Error: Failed to save journal entry.${NC}"
    # Clean up the partially created file if an error occurred during saving.
    rm -f "$entry_filepath"
    exit 1
  fi
}

# --- Function: list_entries ---
# Finds and lists all journal entry files.
# It displays their relative paths from the journal entries directory.
list_entries() {
  echo -e "${BOLD}--- Your Journal Entries ---${NC}"

  local entries_found=0 # Flag to check if any entries are found

  # Use `find` to locate all .txt files within the journal entries directory.
  # `-type f`: only files. `-name "*.txt"`: files ending with .txt.
  # `-print0`: prints filenames separated by null characters, safe for special characters.
  # `sort -z -r`: sorts null-separated input in reverse (newest first).
  # `while IFS= read -r -d $'\0'`: reads null-separated lines safely.
  while IFS= read -r -d $'\0' filepath; do
    # Extract the path relative to JOURNAL_ENTRIES_DIR for cleaner display.
    local relative_path="${filepath#$JOURNAL_ENTRIES_DIR/}"
    echo "  ${GREEN}$relative_path${NC}"
    entries_found=1 # Set flag to indicate entries were found
  done < <(find "$JOURNAL_ENTRIES_DIR" -type f -name "*.txt" -print0 | sort -z -r)

  # If no entries were found, display a message.
  if [ "$entries_found" -eq 0 ]; then
    echo -e "${YELLOW}No journal entries found.${NC}"
  fi
  echo "----------------------------"
}

# --- Function: view_entry ---
# Displays the content of journal entries.
# Can take a specific date (YYYY-MM-DD) or a full entry file path as input.
view_entry() {
  # Check if an argument was provided.
  if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide a date (YYYY-MM-DD) or a full entry file path to view.${NC}"
    show_help
    exit 1
  fi

  local search_term="$1"
  local found_entries=() # Array to store paths of entries to display

  # Check if the input matches the pattern of a full file path
  # (e.g., 2024/07/05/2024-07-05_103000.txt)
  if [[ "$search_term" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}\.txt$ ]]; then
    local full_path="$JOURNAL_ENTRIES_DIR/$search_term"
    if [ -f "$full_path" ]; then # Check if the file actually exists
      found_entries+=("$full_path")
    fi
  # Check if the input matches the pattern of a date (YYYY-MM-DD)
  elif [[ "$search_term" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    local year="${search_term:0:4}" # Extract year from date string
    local month="${search_term:5:2}" # Extract month
    local day="${search_term:8:2}"   # Extract day
    local date_dir="$JOURNAL_ENTRIES_DIR/$year/$month/$day"

    if [ -d "$date_dir" ]; then # Check if the date directory exists
      # Find all .txt files directly within that specific date directory.
      # `maxdepth 1` ensures it doesn't go into subdirectories if any were accidentally created.
      while IFS= read -r -d $'\0' filepath; do
        found_entries+=("$filepath")
      done < <(find "$date_dir" -maxdepth 1 -type f -name "*.txt" -print0 | sort -z) # Sort oldest first for a given day
    fi
  else
    # If the input format is neither a file path nor a date, show an error.
    echo -e "${RED}Error: Invalid format for view. Use YYYY-MM-DD or a full entry file path.${NC}"
    show_help
    exit 1
  fi

  # If no entries were found after the search, inform the user and exit.
  if [ ${#found_entries[@]} -eq 0 ]; then
    echo -e "${YELLOW}No entries found for '$search_term'.${NC}"
    exit 0
  fi

  # Loop through the found entries and display their content.
  for entry_path in "${found_entries[@]}"; do
    local relative_path="${entry_path#$JOURNAL_ENTRIES_DIR/}" # Get path relative to base dir
    echo -e "${BOLD}--- Entry: $relative_path ---${NC}"
    cat "$entry_path" # Display the file content
    echo -e "${BOLD}----------------------------------------------------${NC}"
    echo "" # Add a newline for separation between entries
  done
}

# --- Main Script Logic ---
# This is the primary control flow of the script.
# It ensures directories are set up and then dispatches to the appropriate function
# based on the first command-line argument.
main() {
  ensure_journal_dirs # Always ensure directories are present at the start

  # Use a case statement to handle different commands.
  case "$1" in
    "add")
      add_entry
      ;;
    "list")
      list_entries
      ;;
    "view")
      shift # Remove the "view" command itself from the arguments list
             # so that `view_entry` receives only the date/file path.
      view_entry "$@" # Pass all remaining arguments to view_entry
      ;;
    "help")
      show_help
      ;;
    *)
      # If no arguments are provided or an unknown command is given,
      # display an error and the help message.
      echo -e "${RED}Error: Unknown command or no command provided.${NC}"
      show_help
      exit 1
      ;;
  esac
}

# Call the main function with all command-line arguments.
# "$@" ensures that all arguments are passed correctly, even if they contain spaces.
main "$@"
