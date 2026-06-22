# ══════════════════════════════════════════════════════════════════════════════
# Session 9 — Technology Gap: Korea vs. Brazil
# Creates three PDF figures for Keynote:
#   fig_01_gdppc.pdf          GDP per capita (PWT 11.0, already in repo)
#   fig_02_manufacturing.pdf  Manufacturing % of GDP (World Bank WDI)
#   fig_03_eci.pdf            Economic Complexity Index (Harvard Growth Lab)
#
# ECI data — download before running:
#   1. Go to https://intl-atlas-downloads.s3.amazonaws.com/index.html
#   2. Download "country_sitcproductsection_year.zip"
#   3. Place it at the path defined by PATH_ECI_RAW below
#   Expected columns: country_id (ISO3), year (int), eci (numeric)
#   — adjust the select() call in the ECI section if column names differ
# ══════════════════════════════════════════════════════════════════════════════
here::i_am("content/material/s_09_Technology_analyses/fig_s09_techgap.R")
library(here)
library(tidyverse)
library(haven)
library(WDI)
library(here)
library(scales)

# ── Settings ──────────────────────────────────────────────────────────────────

DOWNLOAD_FRESH <- TRUE   # TRUE = re-download WDI from World Bank API
                          # FALSE = read from cached CSV (faster, works offline)

YEAR_MIN <- 1960
YEAR_MAX <- 2024

# ── Paths (relative to project root via here::here()) ─────────────────────────

PATH_PWT       <- here("content", "material", "pwt110.dta")
PATH_WDI_CACHE <- here("content", "material", "s_09_Technology_analyses", "wdi_manufacturing.csv")
PATH_ECI_RAW   <- here("content", "material", "s_09_Technology_analyses", "country_sitcproductsection_year.csv")
PATH_OUT       <- here("content", "material", "s_09_Technology_analyses")

# ── Shared design ─────────────────────────────────────────────────────────────

COLORS <- c("South Korea" = "#1a6faf", "Brazil" = "#c0392b")

theme_session <- function() {
  theme_minimal(base_size = 14) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey92"),
      axis.line        = element_line(color = "grey60", linewidth = 0.4),
      axis.ticks       = element_line(color = "grey60", linewidth = 0.4),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      legend.key.width = unit(1.8, "cm"),
      plot.title       = element_text(face = "bold", size = 16),
      plot.subtitle    = element_text(color = "grey45", size = 12, margin = margin(b = 8)),
      plot.caption     = element_text(color = "grey55", size = 9, hjust = 0,
                                      margin = margin(t = 10)),
      plot.margin      = margin(12, 16, 10, 12)
    )
}

debt_crisis_annotation <- function(y_pos) {
  list(
    geom_vline(xintercept = 1980, linetype = "dashed",
               color = "grey65", linewidth = 0.5),
    annotate("text", x = 1981, y = y_pos,
             label = "debt crisis", hjust = 0, vjust = 1,
             color = "grey55", size = 3.5)
  )
}

save_fig <- function(p, name, width = 9, height = 5.5) {
  path <- file.path(PATH_OUT, paste0(name, ".pdf"))
  ggsave(path, plot = p, width = width, height = height, device = cairo_pdf)
  message("Saved: ", path)
}

# ── Figure 1: GDP per capita (PWT 11.0) ───────────────────────────────────────

pwt <- read_dta(PATH_PWT) |>
  filter(countrycode %in% c("KOR", "BRA"),
         year >= YEAR_MIN, year <= YEAR_MAX) |>
  mutate(
    gdppc   = rgdpo / pop           # rgdpo in mil. 2017 USD; pop in millions → USD per capita
  ) |>
  select(country, year, gdppc) |> 
  mutate(
    country = case_match(country, "Republic of Korea" ~ "South Korea", .default = country)
  )

p1 <- ggplot(pwt, aes(x = year, y = gdppc, color = country)) +
  #debt_crisis_annotation(y_pos = max(pwt$gdppc) * 0.98) +
  geom_line(linewidth = 1.3) +
  geom_point(size = 2.2) +
  scale_color_manual(values = COLORS) +
  scale_y_continuous(labels = label_dollar(suffix = "k", scale = 1e-3)) +
  scale_x_continuous(breaks = seq(1960, 2000, 10), expand = expansion(add = 1)) +
  labs(
    title    = "GDP per Capita, 1960–2000",
    subtitle = "Output-side real GDP at chained PPPs (2017 USD)",
    x        = NULL,
    y        = "GDP per capita",
    caption  = "Source: Penn World Tables 11.0 (Feenstra, Inklaar & Timmer 2015). Variable: rgdpo / pop."
  ) +
  theme_session()

save_fig(p1, "fig_01_gdppc", width = 6, height = 6)

# ── Figure 2: Manufacturing value added % of GDP (World Bank WDI) ─────────────

if (DOWNLOAD_FRESH) {
  wdi_raw <- WDI(
    country   = c("KR", "BR"),
    indicator = "NV.IND.MANF.ZS",
    start     = YEAR_MIN,
    end       = YEAR_MAX,
    extra     = FALSE
  )
  write_csv(wdi_raw, PATH_WDI_CACHE)
  message("WDI data downloaded and cached to ", PATH_WDI_CACHE)
} else {
  wdi_raw <- read_csv(PATH_WDI_CACHE, show_col_types = FALSE)
  message("WDI data loaded from cache.")
}

mfg <- wdi_raw |>
  rename(mfg_share = `NV.IND.MANF.ZS`) |>
  mutate(country = case_match(iso2c, "KR" ~ "South Korea", "BR" ~ "Brazil")) |>
  filter(!is.na(country), !is.na(mfg_share),
         year >= YEAR_MIN, year <= 2024, 
         !(country=="Brazil" & year <= 1980))

p2 <- ggplot(mfg, aes(x = year, y = mfg_share, color = country)) +
  # debt_crisis_annotation(y_pos = max(mfg$mfg_share, na.rm = TRUE) * 0.99) +
  geom_line(linewidth = 1.3) +
  geom_point(size = 2.2) +
  scale_color_manual(values = COLORS) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 1),
                     limits = c(0, NA)) +
  scale_x_continuous(breaks = seq(1960, 2025, 10), expand = expansion(add = 1)) +
  labs(
    title    = "Manufacturing Value Added, 1960–2000",
    subtitle = "Share of GDP (%)",
    x        = NULL,
    y        = "Manufacturing (% of GDP)",
    caption  = "Source: World Bank World Development Indicators. Indicator: NV.IND.MANF.ZS."
  ) +
  theme_session()

save_fig(p2, "fig_02_manufacturing", width = 6, height = 6)

# ── Figure 3: Economic Complexity Index (Harvard Growth Lab) ──────────────────
#
# Download from: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/XTAQMC
# File: country_rankings.csv
#
# Typical columns: country_id, country_name, year, eci, eci_rank
# If your file uses different names, adjust the select() call below.

if (!file.exists(PATH_ECI_RAW)) {
  stop(
    "ECI file not found at:\n  ", PATH_ECI_RAW,
    "\nDownload country_rankings.csv from:\n",
    "  https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/XTAQMC\n",
    "and place it at the path above."
  )
}

eci_raw <- read_csv(PATH_ECI_RAW, show_col_types = FALSE)

# Adjust column names here if needed:
eci <- eci_raw |>
  select(
    iso3    = location_code,   # ← rename if your file uses a different column name
    year    = year,
    eci     = sitc_eci
  ) |>
  filter(iso3 %in% c("KOR", "BRA"),
         year >= YEAR_MIN, year <= YEAR_MAX) |>
  mutate(country = case_match(iso3, "KOR" ~ "South Korea", "BRA" ~ "Brazil"))

p3 <- ggplot(eci, aes(x = year, y = eci, color = country)) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "grey70", linewidth = 0.4) +
  debt_crisis_annotation(y_pos = max(eci$eci, na.rm = TRUE) * 0.98) +
  geom_line(linewidth = 1.3) +
  geom_point(size = 2.2) +
  scale_color_manual(values = COLORS) +
  scale_x_continuous(breaks = seq(1960, 2025, 10), expand = expansion(add = 1)) +
  labs(
    title    = "Economic Complexity Index, 1964–2000",
    subtitle = "Higher values = more diversified, knowledge-intensive export basket",
    x        = NULL,
    y        = "ECI (standardised)",
    caption  = "Source: Harvard Growth Lab Atlas of Economic Complexity (Hausmann et al. 2011)."
  ) +
  theme_session()

save_fig(p3, "fig_03_eci")

message("\nAll figures saved to: ", PATH_OUT)
