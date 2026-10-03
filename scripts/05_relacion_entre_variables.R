# ============================================================
# PASO 6 (visualizar) — Gráficos de relaciones entre variables
# Visualizamos lo que el paso 4 encontró en números:
#   - precio local vs. internacional (mismo mes y con 1 mes de rezago)
#   - las dos series superpuestas en el tiempo
#   - precio local vs. gas natural y petróleo
#   - precio local vs. tipo de cambio
#   - mapa de calor de correlaciones
# Entrada: Datos/procesados/base_mensual_urea.csv
# Salida:  figuras/05_*.png
# ============================================================
#
# CORRECCIÓN (oct-2026): la versión anterior usaba gas_us_usd_mmbtu y
# gas_eu_usd_mmbtu, que no existen en la base guardada, y por eso las
# secciones 4 y 6 no corrían. Decisión del grupo: la única serie de gas
# del proyecto es Henry Hub (gas_hh_eia_usd_mmbtu). Además, ahora cada
# gráfico se guarda en la carpeta figuras/ (antes solo se mostraba).

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

base <- read_csv(here("Datos", "procesados", "base_mensual_urea.csv"),
                 show_col_types = FALSE) %>%
  mutate(periodo = as.Date(periodo)) %>%
  arrange(periodo)

dir.create(here("figuras"), showWarnings = FALSE)

# ---- 1. Precio local vs. internacional (mismo mes) ------------------
# Correlación de referencia (04): 0,81

g1 <- ggplot(base, aes(x = urea_int_usd_mt, y = precio_import_usd_mt)) +
  geom_point(size = 2.5, color = "steelblue") +
  geom_smooth(method = "lm", se = FALSE, color = "firebrick") +
  labs(title = "Precio local vs. precio internacional de la urea (mismo mes)",
       subtitle = "Correlación = 0,81",
       x = "Precio internacional (USD/ton)",
       y = "Precio de importación Uruguay (USD/ton)") +
  theme_minimal()
g1
ggsave(here("figuras", "05a_local_vs_internacional_mismo_mes.png"), g1,
       width = 8, height = 5, dpi = 150)

# ---- 2. Precio local vs. internacional CON 1 MES DE REZAGO ----------
# Correlación de referencia (04): 0,93, la más alta de todos los rezagos

base_lag <- base %>% mutate(urea_int_lag1 = lag(urea_int_usd_mt, 1))

g2 <- ggplot(filter(base_lag, !is.na(urea_int_lag1)),
             aes(x = urea_int_lag1, y = precio_import_usd_mt)) +
  geom_point(size = 2.5, color = "steelblue") +
  geom_smooth(method = "lm", se = FALSE, color = "firebrick") +
  labs(title = "Precio local vs. precio internacional del mes anterior",
       subtitle = "Correlación = 0,93 — los puntos se pegan mucho más a la recta que sin rezago",
       x = "Precio internacional, mes anterior (USD/ton)",
       y = "Precio de importación Uruguay (USD/ton)") +
  theme_minimal()
g2
ggsave(here("figuras", "05b_local_vs_internacional_rezago1.png"), g2,
       width = 8, height = 5, dpi = 150)

# ---- 3. Ambas series en el tiempo, superpuestas ----------------------

base_largo <- base %>%
  select(periodo, precio_import_usd_mt, urea_int_usd_mt) %>%
  pivot_longer(-periodo, names_to = "serie", values_to = "precio") %>%
  mutate(serie = recode(serie,
                        precio_import_usd_mt = "Precio de importación (Uruguay)",
                        urea_int_usd_mt      = "Precio internacional"))

g3 <- ggplot(base_largo, aes(x = periodo, y = precio, color = serie)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  labs(title = "Precio local e internacional de la urea en el tiempo",
       subtitle = "Los picos del precio local llegan uno o dos meses después que los del internacional",
       x = NULL, y = "USD por tonelada", color = NULL) +
  theme_minimal() +
  theme(legend.position = "bottom")
g3
ggsave(here("figuras", "05c_series_en_el_tiempo.png"), g3,
       width = 9, height = 5, dpi = 150)

# ---- 4. Precio local vs. gas natural y petróleo ----------------------
# Correlaciones de referencia (04): gas Henry Hub 0,77 — Brent 0,70

vars_costos <- base %>%
  select(precio_import_usd_mt, gas_hh_eia_usd_mmbtu, brent_usd_bbl) %>%
  pivot_longer(-precio_import_usd_mt, names_to = "variable", values_to = "valor") %>%
  mutate(variable = recode(variable,
                           gas_hh_eia_usd_mmbtu = "Gas natural Henry Hub (USD/MMBtu)",
                           brent_usd_bbl        = "Petróleo Brent (USD/barril)"))

g4 <- ggplot(vars_costos, aes(x = valor, y = precio_import_usd_mt)) +
  geom_point(color = "steelblue", alpha = 0.7) +
  geom_smooth(method = "lm", se = FALSE, color = "firebrick") +
  facet_wrap(~ variable, scales = "free_x") +
  labs(title = "Precio local de la urea vs. costos de la energía",
       subtitle = "Gas: correlación 0,77 — Brent: 0,70",
       x = NULL, y = "Precio de importación Uruguay (USD/ton)") +
  theme_minimal()
g4
ggsave(here("figuras", "05d_local_vs_gas_y_brent.png"), g4,
       width = 9, height = 4.5, dpi = 150)

# ---- 5. Precio local vs. tipo de cambio ------------------------------
# Correlación de referencia (04): 0,15 (casi nula, esperable: la Y está en USD)

g5 <- ggplot(base, aes(x = tc_venta_uyu, y = precio_import_usd_mt)) +
  geom_point(size = 2.5, color = "steelblue") +
  geom_smooth(method = "lm", se = FALSE, color = "firebrick") +
  labs(title = "Precio local de la urea vs. tipo de cambio",
       subtitle = "Correlación = 0,15 — sin relación visible",
       x = "Tipo de cambio venta (UYU por USD)",
       y = "Precio de importación Uruguay (USD/ton)") +
  theme_minimal()
g5
ggsave(here("figuras", "05e_local_vs_tipo_de_cambio.png"), g5,
       width = 8, height = 5, dpi = 150)

# ---- 6. Mapa de calor de correlaciones -------------------------------
# Versión visual de la matriz de correlación del script 04

matriz_cor <- base %>%
  select(`Precio local`         = precio_import_usd_mt,
         `Precio internacional` = urea_int_usd_mt,
         `Gas Henry Hub`        = gas_hh_eia_usd_mmbtu,
         `Petróleo Brent`       = brent_usd_bbl,
         `Tipo de cambio`       = tc_venta_uyu) %>%
  cor()

cor_largo <- as.data.frame(matriz_cor) %>%
  mutate(var1 = rownames(matriz_cor)) %>%
  pivot_longer(-var1, names_to = "var2", values_to = "correlacion")

g6 <- ggplot(cor_largo, aes(x = var1, y = var2, fill = correlacion)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.2f", correlacion)), size = 3.5) +
  scale_fill_gradient2(low = "steelblue", mid = "white", high = "firebrick",
                       midpoint = 0, limits = c(-1, 1)) +
  labs(title = "Mapa de calor de correlaciones", x = NULL, y = NULL, fill = "r") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
g6
ggsave(here("figuras", "05f_mapa_calor_correlaciones.png"), g6,
       width = 7, height = 6, dpi = 150)

# Lectura general: el precio internacional (sobre todo el del mes
# anterior) es la variable que más acompaña al precio local; el gas y el
# Brent acompañan menos y con más dispersión; el tipo de cambio no
# muestra relación. Esto motiva el modelo con rezagos de los scripts 10 y 11.