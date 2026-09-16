#!/bin/bash
# Update.command
#
# Double-click this file to bring the live course website up to date.
#
# It checks whether any source file (a .qmd page, a slide PDF, data, the
# stylesheets, the bibliography, _quarto.yml, ...) has changed since the last
# successful deployment. If so, it renders the site and pushes it straight to
# Netlify with `quarto publish netlify`.
#
# The time of the last successful deployment is remembered in the file
# .last-publish (git-ignored). Delete that file to force a full redeployment.

cd "$(dirname "$0")" || exit 1

# Finder does not necessarily pass on a complete PATH
export PATH="/usr/local/bin:/opt/homebrew/bin:/Applications/quarto/bin:$PATH"

STAMP=".last-publish"
bold=$(tput bold 2>/dev/null); normal=$(tput sgr0 2>/dev/null)

finish() {
  echo
  echo "Press [Enter] to close this window."
  read -r _
  exit "${1:-0}"
}

echo
echo "${bold}Update the course website (Netlify)${normal}"
echo

if [ ! -f "_quarto.yml" ]; then
  echo "ERROR: _quarto.yml not found. Keep this script in the root of the course repository."
  finish 1
fi

if ! command -v quarto >/dev/null 2>&1; then
  echo "ERROR: 'quarto' was not found. Install Quarto from https://quarto.org/docs/get-started/"
  finish 1
fi

# --- 1. what has changed? ---------------------------------------------------

# Everything that ends up on the website counts as a source file: pages, slide
# decks, data, images, styles and the configuration. Build artefacts, the
# Keynote originals and the working folders are ignored.
find_sources() {
  find . \
    \( -name .git -o -name _site -o -name _freeze -o -name .quarto \
       -o -name renv -o -name .Rproj.user -o -name INBOX -o -name NOTES \
       -o -name node_modules -o -name "_keynote" \) -prune -o \
    -type f \( -name "*.qmd" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" \
       -o -name "*.pdf" -o -name "*.csv" -o -name "*.xlsx" -o -name "*.xls" \
       -o -name "*.dta" -o -name "*.rds" -o -name "*.bib" -o -name "*.csl" \
       -o -name "*.css" -o -name "*.scss" -o -name "*.R" -o -name "*.r" \
       -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \
       -o -name "*.svg" -o -name "*.ico" -o -name "*.ipynb" \) \
    "$@" -print
}

if [ -f "$STAMP" ]; then
  CHANGED=$(find_sources -newer "$STAMP")
  LAST=$(date -r "$STAMP" "+%d.%m.%Y %H:%M")
  echo "Last deployment: $LAST"
else
  CHANGED=$(find_sources)
  echo "No record of an earlier deployment ($STAMP is missing) — treating everything as new."
fi

N=$(printf '%s' "$CHANGED" | grep -c . )

echo
if [ "$N" -eq 0 ]; then
  echo "No page, slide deck or other source file has changed since the last deployment."
  echo
  printf "Publish anyway? [y/N] "
  read -r ANSWER
  case "$ANSWER" in
    [yY]*) ;;
    *) echo "Nothing to do."; finish 0 ;;
  esac
else
  echo "${bold}$N file(s) changed since the last deployment:${normal}"
  printf '%s\n' "$CHANGED" | sed 's|^\./|  |' | head -25
  [ "$N" -gt 25 ] && echo "  … and $((N - 25)) more"
  echo
  printf "Render and publish these changes to Netlify? [Y/n] "
  read -r ANSWER
  case "$ANSWER" in
    [nN]*) echo "Cancelled — nothing was published."; finish 0 ;;
  esac
fi

# --- 2. render --------------------------------------------------------------

echo
echo "${bold}[1/2] Rendering the site …${normal}"
echo
if ! quarto render; then
  echo
  echo "${bold}✗ The render failed — nothing was published.${normal}"
  echo "  Fix the errors reported above and run this script again."
  finish 1
fi

# --- 3. publish -------------------------------------------------------------

echo
echo "${bold}[2/2] Publishing to Netlify …${normal}"
echo

PUBLISH_ARGS="--no-render --no-browser"
# Once _publish.yml holds the Netlify site id, no questions need to be asked.
if grep -qE "^ *- *id: *[A-Za-z0-9]" _publish.yml 2>/dev/null; then
  PUBLISH_ARGS="$PUBLISH_ARGS --no-prompt"
else
  echo "Note: _publish.yml has no Netlify site id yet, so Quarto will ask which"
  echo "      site to publish to (and, the first time, for an access token)."
  echo
fi

# shellcheck disable=SC2086
if quarto publish netlify $PUBLISH_ARGS; then
  touch "$STAMP"
  echo
  echo "${bold}✓ The website is up to date.${normal}"
  URL=$(sed -n "s/.*url: *'\{0,1\}\([^']*\)'\{0,1\}.*/\1/p" _publish.yml | head -1)
  [ -n "$URL" ] && echo "  $URL"
  echo
  echo "Remember to commit and push the changed source files to GitHub:"
  echo "    git add -A && git commit -m \"update website\" && git push"
else
  echo
  echo "${bold}✗ Publishing failed — the live site is unchanged.${normal}"
  finish 1
fi

finish 0
