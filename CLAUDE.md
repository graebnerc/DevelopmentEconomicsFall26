# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [Quarto](https://quarto.org) website for the university course "Development Economics" (taught by Claudius Gräbner-Radkowitsch, EUF/JKU). The site is rendered to static HTML in `_site/` and published to Netlify. R is used for the executable code in some pages (managed via `renv`).

This repo started from a generic academic-course template (see `README.md` for what to change when reusing it). It now targets the **Fall 2026** edition. Note that `references/references.bib`, the OWID datasets under `content/tutorials/`, and in-text citations legitimately contain `2025` (publication/retrieval years, the "2025 Nobel Prize", etc.) — these are real data, not edition labels, and must not be bumped. The authoritative course schedule lives in the table in `content/material/SeminarDescription.qmd`; session pages are numbered to match it.

## Commands

```bash
quarto preview        # Live-reloading local preview (use during editing)
quarto render         # Build the full site into _site/
quarto render content/material/s_07_Marxism.qmd   # Render a single page
quarto publish netlify   # Publish to Netlify (target in _publish.yml)
```

Deployment is **CLI-driven, not GitHub-driven**: Netlify is not connected to the
repository, and `_site/` is gitignored. Two double-clickable wrapper scripts sit
in the repo root:

- `Update.command` — detects changed sources (compared against the `.last-publish`
  stamp), then runs `quarto render` and `quarto publish netlify --no-render`.
- `PublishSlides.command` — toggles the slide download link on a session page.

There is no test suite or linter — "building" means rendering with Quarto. Renders execute embedded R, so an R toolchain with the `renv` library restored (`R -e 'renv::restore()'`) is required for pages that contain `{r}` code chunks.

## Architecture

- **`_quarto.yml`** is the control center: it defines the website type, the navbar/sidebar navigation, the theme, the bibliography/CSL, and — critically — the `render:` glob list. **A new `.qmd` page will not be built unless its path matches an entry under `project.render`**, and it will not appear in navigation unless added to `website.sidebar.contents`.
- **`index.qmd`** (root) is the landing page; **`content/index.qmd`** is the "Getting Started" page.
- **`content/material/`** holds the per-session lecture pages, named **`s_NN_Slug.qmd`** where `NN` is the schedule session number and `Slug` a one-to-two-word topic (e.g. `s_03_HumanDev.qmd`). A session typically fans out into several companion files sharing the number, e.g. for session 7: `s_07_Marxism.qmd` (main page), `s_07_Script.qmd`, `s_07_Exercise1.qmd` / `s_07_Solution1.qmd`. `template/session00.qmd` is the starting point for a new session. Cross-links between pages use the rendered `.html` name (same basename), not `.qmd`.
- **`content/material/slides/`** holds the lecture PDFs (`DevEconYY_LNN_*.pdf`). They are **not** linked from the session pages by default: each session page carries a marker line `<!-- slides: pending -->` followed by a placeholder sentence, which `PublishSlides.command` swaps for `<!-- slides: <file>.pdf -->` plus a download link once the lecture has been given. Edit that pair of lines through the script, not by hand, and keep the marker intact when creating new session pages.
- **`content/tutorials/`** is a Quarto **listing** page (`content/tutorials.qmd` lists the subfolders). Each tutorial is a subdirectory with its own `index.qmd` plus its data files (CSV/XLSX/DTA). `content/tutorials/_metadata.yml` sets shared options for all tutorials (theme, `freeze`, `code-fold`, also an HTML+PDF format) and applies to every page in that tree.
- **`references/`** — `references.bib` (cited via `@key`) and `jepp.csl` (citation style).
- **`css/custom.scss`** overrides the bootstrap `journal` theme (brand colors in `scss:defaults`); `css/custom_style.css` adds extra rules.
- **`figures/`** for site/icon assets; large datasets (`pwt110.dta`, etc.) live next to the pages that consume them.

## Conventions worth knowing

- **`execute: freeze: auto`** (root) means pages with code are *not* re-executed during render unless their source changed; frozen output is cached in `_freeze/` (gitignored). Tutorials override this with `freeze: false`. If R output looks stale, that's why.
- Front matter `date` strings drive each session's displayed date; `date-modified: last-modified` auto-updates.
- `_site/`, `_freeze/`, `.quarto/`, `renv/`, and `.Rproj.user/` are build/tooling artifacts and are gitignored — don't hand-edit `_site/`. (`_site/` was tracked until the move to CLI deployment in September 2026; it no longer is.)
- The site is multilingual-friendly in tone but authored in English; content is academic prose with Quarto callouts (`::: {.callout-note}`), `mermaid` diagrams, and LaTeX math.
