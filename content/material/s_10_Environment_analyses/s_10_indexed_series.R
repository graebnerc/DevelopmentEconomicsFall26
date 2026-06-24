# ══════════════════════════════════════════════════════════════════════════════
# Session 10 — Indexed global series: GHG, material footprint, GDP (1970–)
# Creates one PDF figure:
#   fig_indexed_gdp_ghg_material.pdf
#
# Material indicator: RMC (Raw Material Consumption, consumption-based),
# sourced from UNEP IRP mfa4_RMC.csv. The file is World-only (4 rows, one per
# material category: Biomass, Fossil fuels, Metal ores, Non-metallic minerals).
# The global total is the sum across all four categories.
# OWID 'gdp' (Maddison) has only ~21 decadal data points → WDI NY.GDP.MKTP.KD
# (constant 2015 USD) is used instead for continuous annual coverage.
# ══════════════════════════════════════════════════════════════════════════════
here::i_am("content/material/s_10_Environment_analyses/s_10_indexed_series.R")
library(here)
library(tidyverse)
library(WDI)
library(ggrepel)
library(scales)

DOWNLOAD_FRESH <- FALSE   # set FALSE after first run to use cached WDI data

# ── Paths ──────────────────────────────────────────────────────────────────────

PATH_RMC     <- here("content", "material", "s_10_Environment_analyses", "mfa4_RMC.csv")
PATH_CO2     <- here("content", "material", "s_10_Environment_analyses", "owid-co2-data.csv")
PATH_WDI_GDP <- here("content", "material", "s_10_Environment_analyses", "wdi_world_gdp.csv")
PATH_OUT     <- here("content", "material", "s_10_Environment_analyses")

# ── Shared design ──────────────────────────────────────────────────────────────

SERIES_COLORS <- c(
  "Global GHG emissions"     = "#c0392b",
  "Material footprint (RMC)" = "#d9a72e",
  "Global GDP"               = "#1a6faf"
)

theme_session <- function() {
  theme_minimal(base_size = 14) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey92"),
      axis.line        = element_line(color = "grey60", linewidth = 0.4),
      axis.ticks       = element_line(color = "grey60", linewidth = 0.4),
      legend.position  = "none",
      plot.title       = element_text(face = "bold", size = 16),
      plot.subtitle    = element_text(color = "grey45", size = 12,
                                      margin = margin(b = 8)),
      plot.caption     = element_text(color = "grey55", size = 9, hjust = 0,
                                      margin = margin(t = 10)),
      plot.margin      = margin(12, 16, 10, 12)
    )
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 0 — Inspect and load MFA / RMC
# ══════════════════════════════════════════════════════════════════════════════

rmc_raw <- read_csv(PATH_RMC, show_col_types = FALSE)

message("\n── RMC file structure ───────────────────────────")
glimpse(rmc_raw)
message("  Unique Country values: ", paste(unique(rmc_raw$Country), collapse = ", "))
message("  Categories: ", paste(rmc_raw$Category, collapse = " | "))

# Wide format: metadata cols + one numeric col per year (1970–2024).
# Summing all 4 category rows gives the global material footprint total.
rmc_total <- rmc_raw |>
  filter(Country == "World") |>
  select(where(is.numeric)) |>
  summarise(across(everything(), sum, na.rm = TRUE)) |>
  pivot_longer(everything(), names_to = "year", values_to = "material") |>
  mutate(year = as.integer(year)) |>
  arrange(year)

message("  Material footprint (summed): ",
        min(rmc_total$year), "–", max(rmc_total$year),
        " | n = ", nrow(rmc_total))

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — Global GHG emissions (OWID total_ghg, includes land-use change)
# ══════════════════════════════════════════════════════════════════════════════

owid <- read_csv(PATH_CO2, show_col_types = FALSE)

ghg_total <- owid |>
  filter(country == "World", year >= 1970, !is.na(total_ghg)) |>
  select(year, ghg = total_ghg) |>
  arrange(year)

message("\n── GHG series ───────────────────────────────────")
message("  total_ghg (World): ",
        min(ghg_total$year), "–", max(ghg_total$year),
        " | n = ", nrow(ghg_total))

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — Global GDP (WDI, NY.GDP.MKTP.KD — constant 2015 USD)
# Note: OWID 'gdp' (Maddison Project) has only ~21 decadal points → use WDI.
# ══════════════════════════════════════════════════════════════════════════════

message("\n── GDP series ───────────────────────────────────")

if (DOWNLOAD_FRESH) {
  wdi_gdp_raw <- WDI(
    indicator = c(gdp_wdi = "NY.GDP.MKTP.KD"),
    country   = "WLD",
    start     = 1970,
    end       = 2024
  )
  write_csv(wdi_gdp_raw, PATH_WDI_GDP)
  message("  WDI world GDP downloaded and cached to ", PATH_WDI_GDP)
} else {
  wdi_gdp_raw <- read_csv(PATH_WDI_GDP, show_col_types = FALSE)
  message("  WDI world GDP loaded from cache.")
}

gdp_total <- wdi_gdp_raw |>
  filter(!is.na(gdp_wdi)) |>
  select(year, gdp = gdp_wdi) |>
  arrange(year)

message("  GDP (WDI NY.GDP.MKTP.KD, constant 2015 USD): ",
        min(gdp_total$year), "–", max(gdp_total$year),
        " | n = ", nrow(gdp_total))

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — Merge and index to base year 1990
# ══════════════════════════════════════════════════════════════════════════════

BASE_YEAR <- 1990

df_merged <- rmc_total |>
  inner_join(ghg_total, by = "year") |>
  inner_join(gdp_total, by = "year") |>
  filter(year >= 1970)

# Check base year; fall back to earliest complete year if needed
if (!BASE_YEAR %in% df_merged$year) {
  BASE_YEAR <- min(df_merged$year)
  message("\n  Base year 1990 not in merged data; using ", BASE_YEAR, " instead.")
} else {
  message("\n  Base year: ", BASE_YEAR, " (all three series present)")
}

df_plot <- df_merged |>
  mutate(
    ghg_idx      = ghg      / ghg[year      == BASE_YEAR],
    material_idx = material / material[year == BASE_YEAR],
    gdp_idx      = gdp      / gdp[year      == BASE_YEAR]
  )

LAST_YEAR <- max(df_plot$year)
message("  Final range: ", min(df_plot$year), "–", LAST_YEAR,
        " | rows: ", nrow(df_plot))

message("\n── Spot-check (indexed values) ──────────────────")
print(df_plot |> select(year, ghg_idx, material_idx, gdp_idx))

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — Plot
# ══════════════════════════════════════════════════════════════════════════════

df_long <- df_plot |>
  select(
    year,
    "Global GHG emissions"     = ghg_idx,
    "Material footprint (RMC)" = material_idx,
    "Global GDP"               = gdp_idx
  ) |>
  pivot_longer(-year, names_to = "series", values_to = "index") |>
  mutate(series = factor(series, levels = names(SERIES_COLORS)))

# Anchor inline labels at the last data point per series
label_data <- df_long |>
  group_by(series) |>
  slice_max(year, n = 1, with_ties = FALSE) |>
  ungroup() |> 
  mutate(
    series_label = ifelse(
      series == "Material footprint (RMC)",  "Material footprint", as.character(series))
  )
y_min <- floor(min(df_long$index, na.rm = TRUE) * 10) / 10 - 0.05
y_max <- ceiling(max(df_long$index, na.rm = TRUE) * 10) / 10 + 0.1

p <- ggplot(df_long, aes(x = year, y = index, color = series)) +
  geom_hline(yintercept = 1, linetype = "dotted",
             color = "grey55", linewidth = 0.4) +
  geom_line(linewidth = 1.3) +
  geom_text_repel(
    data          = label_data,
    aes(label     = series_label),
    hjust         = 0,
    nudge_x       = 1.2,
    direction     = "y",
    size          = 3.6,
    segment.size  = 0.3,
    segment.color = "grey60",
    show.legend   = FALSE
  ) +
  scale_color_manual(values = SERIES_COLORS) +
  scale_x_continuous(
    breaks = c(seq(1970, LAST_YEAR, by = 5), 2024),
    expand = expansion(add = c(0.5, 10))
  ) +
  scale_y_continuous(
    name   = paste0("Index (base year = ", BASE_YEAR, ")"),
    limits = c(y_min, y_max),
    labels = scales::label_percent()
  ) +
  labs(
    x       = NULL,
    title   = "Strong correlation between GDP and resource use",
    caption = paste0(
      "Sources: Global Carbon Project / Jones et al. via Our World in Data (GHG, total_ghg incl. LUC); ",
      "UNEP IRP Global Material Flows Database (material footprint, RMC); ",
      "World Bank WDI, NY.GDP.MKTP.KD constant 2015 USD (GDP). ",
      "Base year: ", BASE_YEAR, ". Final year: ", LAST_YEAR, "."
    )
  ) +
  theme_session()

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4 — Save
# ══════════════════════════════════════════════════════════════════════════════

ggsave(
  file.path(PATH_OUT, "fig_indexed_gdp_ghg_material.pdf"),
  plot   = p,
  width  = 10,
  height = 6.5,
  device = cairo_pdf
)
message("\nSaved: ", file.path(PATH_OUT, "fig_indexed_gdp_ghg_material.pdf"))
