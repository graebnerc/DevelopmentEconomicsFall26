#!/bin/bash
# PublishSlides.command
#
# Double-click this file to publish (or hide again) the download link to the
# lecture slides on the session pages of the course website.
#
# Each session page contains a placeholder of the form
#
#   <!-- slides: pending -->
#   *The slides will be made available here after the lecture.*
#
# Publishing replaces it with
#
#   <!-- slides: DevEcon26_L07_Marxism.pdf -->
#   Click [here](slides/DevEcon26_L07_Marxism.pdf) to download the slides.
#
# The PDF itself is looked up in content/material/slides/ by its lecture
# number (e.g. "07" matches DevEcon26_L07_Marxism.pdf).
#
# After running this script, re-render and publish the site:
#   quarto render && quarto publish netlify

cd "$(dirname "$0")" || exit 1

MATERIAL="content/material"
SLIDES="$MATERIAL/slides"
PLACEHOLDER_TEXT='*The slides will be made available here after the lecture.*'

bold=$(tput bold 2>/dev/null); normal=$(tput sgr0 2>/dev/null)

finish() {
  echo
  echo "Press [Enter] to close this window."
  read -r _
  exit "${1:-0}"
}

if [ ! -d "$MATERIAL" ]; then
  echo "ERROR: $MATERIAL not found. Keep this script in the root of the course repository."
  finish 1
fi

# --- helpers ----------------------------------------------------------------

# page_for <NN> -> path of the session page carrying the slides marker
page_for() {
  local nn="$1" f
  for f in "$MATERIAL"/s_"$nn"_*.qmd; do
    [ -e "$f" ] || continue
    if grep -q '^<!-- slides: .* -->$' "$f"; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

# pdf_for <NN> -> file name (without path) of the slide deck of that session
pdf_for() {
  local nn="$1" hits f
  hits=()
  for f in "$SLIDES"/*L"$nn"*.pdf; do
    [ -e "$f" ] || continue
    hits+=("$(basename "$f")")
  done
  [ "${#hits[@]}" -eq 1 ] || { printf '%s\n' "${hits[@]}"; return 1; }
  echo "${hits[0]}"
}

# current_state <page> -> "pending" or the published pdf name
current_state() {
  sed -n 's/^<!-- slides: \(.*\) -->$/\1/p' "$1" | head -1
}

# set_marker <page> <pdf|pending>
set_marker() {
  local page="$1" what="$2" tmp
  tmp="$page.tmp.$$"
  awk -v what="$what" -v ph="$PLACEHOLDER_TEXT" '
    /^<!-- slides: .* -->$/ && !done {
      print "<!-- slides: " what " -->"
      if (what == "pending") {
        print ph
      } else {
        print "Click [here](slides/" what ") to download the slides."
      }
      done = 1
      drop = 1
      next
    }
    drop == 1 {
      drop = 0
      if ($0 ~ /^\*The slides will be made available/) next
      if ($0 ~ /^Click \[here\]\(slides\//) next
    }
    { print }
  ' "$page" > "$tmp" && mv "$tmp" "$page"
}

# --- overview ---------------------------------------------------------------

echo
echo "${bold}Publish lecture slides — Development Economics${normal}"
echo

printf "%-10s %-38s %s\n" "SESSION" "PAGE" "SLIDES"
for page in "$MATERIAL"/s_*.qmd; do
  grep -q '^<!-- slides: .* -->$' "$page" || continue
  nn=$(basename "$page" | sed -n 's/^s_\([0-9][0-9]\)_.*/\1/p')
  state=$(current_state "$page")
  if [ "$state" = "pending" ]; then
    avail=$(pdf_for "$nn") || avail=""
    if [ -n "$avail" ]; then
      state="hidden (PDF ready: $avail)"
    else
      state="hidden (no PDF found)"
    fi
  else
    state="ONLINE: $state"
  fi
  printf "%-10s %-38s %s\n" "$nn" "$(basename "$page")" "$state"
done

echo
echo "Enter the session numbers whose slides should go online (e.g.: 01 04 07)."
echo "Prefix a number with a minus to take its slides offline again (e.g.: -07)."
echo
printf "Sessions: "
read -r INPUT

if [ -z "$INPUT" ]; then
  echo "Nothing entered — no changes made."
  finish 0
fi

# --- act --------------------------------------------------------------------

echo
changed=0
for token in $INPUT; do
  mode="publish"
  case "$token" in
    -*) mode="hide"; token="${token#-}" ;;
  esac
  case "$token" in
    [0-9]|[0-9][0-9]) nn=$(printf '%02d' "$((10#$token))") ;;
    *) echo "  ✗ '$token' is not a session number (use 01, 02, ...)"; continue ;;
  esac

  page=$(page_for "$nn")
  if [ -z "$page" ]; then
    echo "  ✗ Session $nn: no session page with a slides placeholder found."
    continue
  fi

  if [ "$mode" = "hide" ]; then
    set_marker "$page" "pending"
    echo "  ✓ Session $nn: slides taken offline ($(basename "$page"))"
    changed=1
    continue
  fi

  pdf=$(pdf_for "$nn")
  if [ -z "$pdf" ]; then
    echo "  ✗ Session $nn: no PDF matching '*L${nn}*.pdf' in $SLIDES"
    continue
  fi
  if [ "$(printf '%s' "$pdf" | wc -l)" -gt 0 ]; then
    echo "  ✗ Session $nn: several PDFs match '*L${nn}*.pdf':"
    printf '        %s\n' $pdf
    echo "        Please clean up $SLIDES so that only one deck matches."
    continue
  fi

  set_marker "$page" "$pdf"
  echo "  ✓ Session $nn: slides online → $pdf ($(basename "$page"))"
  changed=1
done

if [ "$changed" -eq 1 ]; then
  echo
  echo "${bold}Done.${normal} Now build and publish the site:"
  echo "    quarto render && quarto publish netlify"
  echo "…and commit the changed .qmd files."
fi

finish 0
