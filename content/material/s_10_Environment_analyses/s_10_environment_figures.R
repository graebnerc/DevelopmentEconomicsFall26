# ══════════════════════════════════════════════════════════════════════════════
# Session 10 — Environment: Climate vulnerability & CO₂ responsibility
# Creates five PDF figures:
#   fig_vulnerability_vs_income.pdf   ND-GAIN vulnerability vs. GDP per capita
#   fig_co2_three_framings.pdf        Annual / per-capita / cumulative CO₂ bars
#   fig_co2_ranking_flow.pdf          Bump chart: rank shifts across the three metrics
#   fig_gdp_vs_hdi.pdf                GDP per capita vs. Human Development Index
#   fig_decoupling.pdf                CO₂ vs. GDP decoupling since 1990 (6 countries)
# ══════════════════════════════════════════════════════════════════════════════
here::i_am("content/material/s_10_Environment_analyses/s_10_environment_figures.R")
library(here)
library(tidyverse)
library(WDI)
library(countrycode)
library(ggrepel)
library(patchwork)
library(scales)

DOWNLOAD_FRESH <- FALSE   # TRUE = re-download WDI from World Bank API
# FALSE = read from cached CSV (faster, works offline)

# ── Paths ──────────────────────────────────────────────────────────────────────

PATH_VULN <- here("content", "material", "s_10_Environment_analyses",
                  "ndgain_countryindex_2026", "vulnerability.csv")
PATH_CO2  <- here("content", "material", "s_10_Environment_analyses",
                  "owid-co2-data.csv")
PATH_WDI_CACHE <- here("content", "material", "s_10_Environment_analyses",
                       "wdi-gdp-data.csv")
PATH_OUT  <- here("content", "material", "s_10_Environment_analyses")

# ── Shared design (mirrors s_09) ───────────────────────────────────────────────

INCOME_COLORS <- c(
  "High income"         = "#1a6faf",
  "Upper middle income" = "#5aae61",
  "Lower middle income" = "#d9a72e",
  "Low income"          = "#c0392b"
)

INCOME_LEVELS <- c("High income", "Upper middle income",
                   "Lower middle income", "Low income")

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
      plot.subtitle    = element_text(color = "grey45", size = 12,
                                      margin = margin(b = 8)),
      plot.caption     = element_text(color = "grey55", size = 9, hjust = 0,
                                      margin = margin(t = 10)),
      plot.margin      = margin(12, 16, 10, 12)
    )
}

save_fig <- function(p, name, width = 10, height = 6.5) {
  path <- file.path(PATH_OUT, paste0(name, ".pdf"))
  ggsave(path, plot = p, width = width, height = height, device = cairo_pdf)
  message("Saved: ", path)
}

# ══════════════════════════════════════════════════════════════════════════════
# DATA PREP
# ══════════════════════════════════════════════════════════════════════════════

# ── WDI: GDP per capita PPP ────────────────────────────────────────────────────

if (DOWNLOAD_FRESH) {
  wdi_raw <- WDI(
    indicator = c(
      gdp = "NY.GDP.MKTP.PP.KD", 
      pop = "SP.POP.TOTL"),
    extra = TRUE, 
    start = 2020, 
    end = 2023
  )
  write_csv(wdi_raw, PATH_WDI_CACHE)
  message("WDI data downloaded and cached to ", PATH_WDI_CACHE)
} else {
  wdi_raw <- read_csv(PATH_WDI_CACHE, show_col_types = FALSE)
  message("WDI data loaded from cache.")
}

wdi <- wdi_raw |>
  filter(!is.na(gdp), !is.na(pop), !is.na(iso3c), region != "Aggregates") |>
  mutate(gdp_pc = gdp / pop) |>
  group_by(iso3c) |>
  slice_max(year, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(iso3c, country, year_wdi = year, gdp_pc, income)

# ── ND-GAIN vulnerability (2023, the most recent year) ─────────────────────────

VULN_YEAR <- "2023"

vuln <- read_csv(PATH_VULN, show_col_types = FALSE) |>
  select(iso3 = ISO3, name = Name, vulnerability = all_of(VULN_YEAR)) |>
  filter(!is.na(vulnerability))

# ── Merge: vulnerability + WDI ─────────────────────────────────────────────────

fig1_data <- vuln |>
  inner_join(wdi, by = c("iso3" = "iso3c")) |>
  filter(!is.na(gdp_pc), income %in% INCOME_LEVELS) |>
  mutate(income = factor(income, levels = INCOME_LEVELS))

message(
  "\n── Figure 1 data summary ─────────────────────────",
  "\n  Countries merged:  ", nrow(fig1_data),
  "\n  ND-GAIN year:      ", VULN_YEAR,
  "\n  WDI years present: ", paste(sort(unique(fig1_data$year_wdi)), collapse = ", "),
  "\n  Income group n:    ",
  paste(names(table(fig1_data$income)), table(fig1_data$income), sep = " = ", collapse = "; "),
  "\n──────────────────────────────────────────────────\n"
)

# ── OWID CO₂ data ──────────────────────────────────────────────────────────────

CO2_YEAR <- 2022

CO2_ISOS <- c("USA", "CHN", "IND", "DEU", "GBR", "FRA", "BRA", "ZAF",
               "NGA", "BGD", "ETH", "AUS", "CAN", "SAU", "IDN")

income_lkp <- wdi |> distinct(iso3c, income)

co2_raw <- read_csv(PATH_CO2, show_col_types = FALSE)

co2_sel <- co2_raw |>
  filter(iso_code %in% CO2_ISOS, year == CO2_YEAR) |>
  select(iso_code, year, co2, co2_per_capita, cumulative_co2) |>
  mutate(
    country = countrycode(iso_code, "iso3c", "country.name"),
    # Short labels for readability in bars
    country = case_match(
      iso_code,
      "USA" ~ "United States",
      "GBR" ~ "United Kingdom",
      "ZAF" ~ "South Africa",
      "SAU" ~ "Saudi Arabia",
      .default = country
    )
  ) |>
  left_join(income_lkp, by = c("iso_code" = "iso3c")) |>
  filter(!is.na(co2), !is.na(co2_per_capita), !is.na(cumulative_co2),
         income %in% INCOME_LEVELS) |>
  mutate(income = factor(income, levels = INCOME_LEVELS))

message(
  "\n── Figure 2 data summary ─────────────────────────",
  "\n  Year:      ", CO2_YEAR,
  "\n  Countries: ", nrow(co2_sel), " of ", length(CO2_ISOS), " requested",
  "\n  Present:   ", paste(sort(co2_sel$country), collapse = ", "),
  "\n──────────────────────────────────────────────────\n"
)

# ══════════════════════════════════════════════════════════════════════════════
# FIGURE 1 — Climate vulnerability vs. income per capita
# ══════════════════════════════════════════════════════════════════════════════

LABEL_ISOS <- c("TCD", "NER", "BGD", "ETH", "IND", "BRA", "CHN",
                "ZAF", "MEX", "DEU", "NOR", "USA", "AUS")

fig1_labels <- fig1_data |> filter(iso3 %in% LABEL_ISOS)

# log10 x-axis break positions and matching dollar labels
x_breaks <- log10(c(500, 1000, 2000, 5000, 10000, 20000, 50000, 100000))
x_labels <- c("$500", "$1k", "$2k", "$5k", "$10k", "$20k", "$50k", "$100k")

p1 <- ggplot(fig1_data, aes(x = log10(gdp_pc), y = vulnerability, color = income)) +
  geom_smooth(
    aes(group = 1), method = "lm", se = TRUE,
    color = "grey40", fill = "grey85", linewidth = 0.8, alpha = 0.45,
    show.legend = FALSE
  ) +
  geom_point(alpha = 0.75, size = 2.2) +
  geom_text_repel(
    data        = fig1_labels,
    aes(label   = name),
    size        = 3.2,
    max.overlaps = 5,
    seed        = 42,
    box.padding  = 0.45,
    point.padding = 0.2,
    show.legend = FALSE
  ) +
  scale_color_manual(
    values = INCOME_COLORS,
    guide  = guide_legend(nrow = 1, override.aes = list(size = 3.5, alpha = 1))
  ) +
  scale_x_continuous(
    breaks = x_breaks,
    labels = x_labels
  ) +
  scale_y_continuous(limits = c(NA, NA)) +
  labs(
    x       = "GDP per capita (PPP, log scale, constant 2017 int. $)",
    y       = "Climate vulnerability\n (ND-GAIN, higher = more vulnerable)",
    title   = "Poorer countries face greater climate vulnerability",
    subtitle = "Each point is a country; OLS trend line across all countries",
    caption  = paste0(
      "Sources: ND-GAIN Country Index vulnerability score (", VULN_YEAR, " edition); ",
      "World Bank WDI, GDP per capita PPP (NY.GDP.MKTP.PP.KD), most recent year 2020–2023."
    )
  ) +
  theme_session() +
  theme(legend.key.width = unit(0.8, "cm"))

save_fig(p1, "fig_vulnerability_vs_income")

# ══════════════════════════════════════════════════════════════════════════════
# FIGURE 2 — Three framings of CO₂ responsibility (bar charts)
# ══════════════════════════════════════════════════════════════════════════════

fill_scale <- scale_fill_manual(
  values = INCOME_COLORS,
  drop   = FALSE,
  guide  = guide_legend(nrow = 1)
)

panel_theme <- theme_session() +
  theme(
    legend.position = "bottom",
    plot.title      = element_text(face = "bold", size = 13),
    axis.text.y     = element_text(size = 10)
  )

pA <- ggplot(
  co2_sel |> mutate(country = fct_reorder(country, co2)),
  aes(x = country, y = co2, fill = income)
) +
  geom_col(width = 0.72) +
  fill_scale +
  scale_y_continuous(labels = label_number(scale_cut = cut_short_scale(),
                                            suffix = " Mt")) +
  coord_flip() +
  labs(title = "A — Annual total CO₂", x = NULL, y = NULL) +
  panel_theme

pB <- ggplot(
  co2_sel |> mutate(country = fct_reorder(country, co2_per_capita)),
  aes(x = country, y = co2_per_capita, fill = income)
) +
  geom_col(width = 0.72) +
  fill_scale +
  scale_y_continuous(labels = label_number(accuracy = 0.1, suffix = " t")) +
  coord_flip() +
  labs(title = "B — CO₂ per capita", x = NULL, y = NULL) +
  panel_theme

pC <- ggplot(
  co2_sel |> mutate(country = fct_reorder(country, cumulative_co2)),
  aes(x = country, y = cumulative_co2, fill = income)
) +
  geom_col(width = 0.72) +
  fill_scale +
  scale_y_continuous(labels = label_number(scale_cut = cut_short_scale(),
                                            suffix = " Mt")) +
  coord_flip() +
  labs(title = "C — Cumulative CO₂ since 1750", x = NULL, y = NULL) +
  panel_theme

p2 <- (pA | pB | pC) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title   = paste0("The same emissions, three measures (", CO2_YEAR, ")"),
    caption = paste0(
      "Source: Global Carbon Project via Our World in Data (owid-co2-data.csv), year ",
      CO2_YEAR, ". Income groups: World Bank WDI."
    ),
    theme = theme_session() + theme(
      legend.position = "bottom",
      plot.title      = element_text(face = "bold", size = 16)
    )
  ) &
  theme(legend.position = "bottom")

save_fig(p2, "fig_co2_three_framings", width = 14, height = 6.5)

# ══════════════════════════════════════════════════════════════════════════════
# FIGURE 3 — Ranking flow: how position changes across the three metrics
# ══════════════════════════════════════════════════════════════════════════════

# x positions spread at 1 / 3 / 5 so the three columns have breathing room
co2_ranks <- co2_sel |>
  mutate(
    rank_total      = rank(-co2,            ties.method = "first"),
    rank_per_capita = rank(-co2_per_capita, ties.method = "first"),
    rank_cumulative = rank(-cumulative_co2, ties.method = "first")
  ) |>
  select(country, income, rank_total, rank_per_capita, rank_cumulative) |>
  pivot_longer(
    cols      = starts_with("rank_"),
    names_to  = "metric",
    values_to = "rank"
  ) |>
  mutate(
    x_pos = case_when(
      metric == "rank_total"      ~ 1L,
      metric == "rank_per_capita" ~ 3L,
      metric == "rank_cumulative" ~ 5L
    )
  )

n_ctry <- nrow(co2_sel)

labels_left  <- co2_ranks |> filter(x_pos == 1)
labels_right <- co2_ranks |> filter(x_pos == 5)

p3 <- ggplot(co2_ranks,
             aes(x = x_pos, y = rank, group = country, color = income)) +
  geom_line(linewidth = 1.3, alpha = 0.85) +
  geom_point(size = 2.5) +
  geom_text(
    data = labels_left,
    aes(label = country, x = x_pos - 0.3),
    hjust = 1, size = 3.1, show.legend = FALSE
  ) +
  geom_text(
    data = labels_right,
    aes(label = country, x = x_pos + 0.3),
    hjust = 0, size = 3.1, show.legend = FALSE
  ) +
  scale_y_reverse(breaks = seq_len(n_ctry), minor_breaks = NULL) +
  scale_x_continuous(
    breaks = c(1, 3, 5),
    labels = c("Annual\ntotal CO₂\n(Mt)", "Per capita\nCO₂\n(t/person)",
               "Cumulative\nCO₂\nsince 1750 (Mt)"),
    expand = expansion(add = c(3.2, 3.2))
  ) +
  scale_color_manual(
    values = INCOME_COLORS,
    guide  = guide_legend(nrow = 1,
                          override.aes = list(size = 3, linewidth = 1.5))
  ) +
  labs(
    title   = paste0("Rankings shift dramatically depending on the CO₂ measure (",
                     CO2_YEAR, ")"),
    x       = NULL,
    y       = "Rank (1 = highest emitter in the set)",
    caption = paste0(
      "Source: Global Carbon Project via Our World in Data (owid-co2-data.csv), year ",
      CO2_YEAR, ". Income groups: World Bank WDI."
    )
  ) +
  theme_session() +
  theme(
    legend.key.width   = unit(1.2, "cm"),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(color = "grey90", linewidth = 0.3),
    axis.text.x        = element_text(size = 12, face = "bold", lineheight = 1.1),
    axis.text.y        = element_text(size = 9, color = "grey55"),
    panel.grid = element_blank()
  )

save_fig(p3, "fig_co2_ranking_flow")

# ══════════════════════════════════════════════════════════════════════════════
# FIGURE 4 — GDP per capita vs. Human Development Index
# ══════════════════════════════════════════════════════════════════════════════

PATH_GDP_HDI <- here("INBOX", "gdp-vs-hdi.csv")

REGION_COLORS <- c(
  "Africa"        = "#c05040",
  "Asia"          = "#d4963a",
  "Europe"        = "#3a7fbf",
  "North America" = "#5ba05b",
  "Oceania"       = "#7b9cb8",
  "South America" = "#9370b0"
)

gdp_hdi <- read_csv(PATH_GDP_HDI, show_col_types = FALSE) |>
  rename(
    hdi    = `Human Development Index`,
    gdp_pc = `GDP per capita`,
    region = `World region according to OWID`
  ) |>
  filter(!is.na(hdi), !is.na(gdp_pc))

germany <- gdp_hdi |> filter(Code == "DEU")

message(
  "\n── Figure 4 data summary ─────────────────────────",
  "\n  Countries: ", nrow(gdp_hdi),
  "\n  Year:      ", unique(gdp_hdi$Year),
  "\n  Regions:   ", paste(names(table(gdp_hdi$region)), collapse = ", "),
  "\n──────────────────────────────────────────────────\n"
)

x_hdi_breaks <- log10(c(1000, 2000, 5000, 10000, 20000, 50000, 100000))
x_hdi_labels <- c("$1k", "$2k", "$5k", "$10k", "$20k", "$50k", "$100k")

p4 <- ggplot(gdp_hdi, aes(x = log10(gdp_pc), y = hdi, color = region)) +
  geom_smooth(
    aes(group = 1), method = "loess", se = TRUE,
    color = "black", fill = "grey80", linewidth = 0.9, alpha = 0.35,
    show.legend = FALSE
  ) +
  geom_point(alpha = 0.75, size = 2.2) +
  geom_point(
    data = germany, color = "black", shape = 21, size = 3.8, stroke = 1.3,
    fill = REGION_COLORS["Europe"], show.legend = FALSE
  ) +
  geom_text_repel(
    data = germany, aes(label = Entity),
    color = "black", fontface = "bold", size = 3.8,
    nudge_x = 0.1, nudge_y = + 0.03, seed = 42,
    show.legend = FALSE
  ) +
  scale_color_manual(
    values = REGION_COLORS,
    guide  = guide_legend(nrow = 2, override.aes = list(size = 3.5, alpha = 1))
  ) +
  scale_x_continuous(breaks = x_hdi_breaks, labels = x_hdi_labels) +
  scale_y_continuous(limits = c(0.4, 1.0), breaks = seq(0.4, 1.0, 0.1)) +
  labs(
    x       = "GDP per capita (PPP, log scale)",
    y       = "Human Development Index (0–1)",
    title   = "GDP and human development correlate strongly",
    caption  = "Source: Our World in Data (2023); UNDP Human Development Report."
  ) +
  theme_session() +
  theme(legend.key.width = unit(0.8, "cm"))

save_fig(p4, "fig_gdp_vs_hdi")

# ══════════════════════════════════════════════════════════════════════════════
# FIGURE 5 — Decoupling of CO₂ emissions from GDP growth since 1990
# ══════════════════════════════════════════════════════════════════════════════

PATH_DECOUPLE <- here("INBOX", "co2-emissions-and-gdp-per-capita.csv")

DECOUPLE_COUNTRIES <- c("Germany", "United States", "World",
                        "China",   "India",         "Switzerland")

LINE_COLORS <- c(
  "GDP per capita"         = "#1a6faf",
  "CO₂ per capita"         = "#3d9e5e",
  "Consumption-based CO₂"  = "#d17a28"
)

label_signed_pct <- function(x) {
  paste0(ifelse(x > 0, "+", ""), round(x), "%")
}

co2_gdp <- read_csv(PATH_DECOUPLE, show_col_types = FALSE) |>
  rename(
    gdp_pc   = `GDP per capita`,
    co2_pc   = `CO₂ emissions per capita`,
    cons_co2 = `Consumption-based CO₂ emissions per capita`
  ) |>
  filter(Entity %in% DECOUPLE_COUNTRIES, Year >= 1990) |>
  group_by(Entity) |>
  mutate(
    gdp_idx  = (gdp_pc   / gdp_pc[Year   == 1990] - 1) * 100,
    co2_idx  = (co2_pc   / co2_pc[Year   == 1990] - 1) * 100,
    cons_idx = (cons_co2 / cons_co2[Year == 1990] - 1) * 100
  ) |>
  ungroup() |>
  select(country = Entity, year = Year, gdp_idx, co2_idx, cons_idx) |>
  pivot_longer(
    cols      = c(gdp_idx, co2_idx, cons_idx),
    names_to  = "series",
    values_to = "pct_change"
  ) |>
  mutate(
    series  = factor(series,
      levels = c("gdp_idx", "co2_idx", "cons_idx"),
      labels = c("GDP per capita", "CO₂ per capita", "Consumption-based CO₂")
    ),
    country = factor(country, levels = DECOUPLE_COUNTRIES)
  )

message(
  "\n── Figure 5 data summary ─────────────────────────",
  "\n  Countries: ", paste(DECOUPLE_COUNTRIES, collapse = ", "),
  "\n  Year range: 1990–", max(co2_gdp$year, na.rm = TRUE),
  "\n──────────────────────────────────────────────────\n"
)

p5 <- ggplot(co2_gdp, aes(x = year, y = pct_change, color = series)) +
  geom_hline(yintercept = 0, linetype = "dashed",
             color = "grey55", linewidth = 0.4) +
  geom_line(linewidth = 1.1, na.rm = TRUE) +
  facet_wrap(~ country, ncol = 3, scales = "free_y") +
  scale_color_manual(values = LINE_COLORS) +
  scale_x_continuous(breaks = c(1990, 2000, 2010, 2020)) +
  scale_y_continuous(labels = label_signed_pct) +
  labs(
    title   = "Decoupling of CO₂ emissions from GDP growth since 1990",
    subtitle = "Cumulative % change since 1990 (base year = 0%)",
    x       = NULL,
    y       = "Cumulative change since 1990",
    caption  = "Source: Our World in Data; Global Carbon Project (2023)."
  ) +
  theme_session() +
  theme(
    legend.key.width = unit(1.2, "cm"),
    strip.text       = element_text(face = "bold", size = 12)
  )

save_fig(p5, "fig_decoupling", width = 12, height = 7)

message("\nAll figures saved to: ", PATH_OUT)
