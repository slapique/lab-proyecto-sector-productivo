# ============================================================
# PASO 6 — Gráficos de relaciones entre variables
# Visualizamos lo que el paso 4 encontró en números:
#   - Relación precio local vs. internacional (actual y con rezago)
#   - Relación precio local vs. gas natural y petróleo
#   - Mapa de calor de correlaciones
# Entrada: Datos/procesados/base_mensual_urea.csv
# ============================================================

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

base <- read_csv(here("Datos", "procesados", "base_mensual_urea.csv"),
                 show_col_types = FALSE) %>%
  mutate(periodo = as.Date(periodo)) %>%
  arrange(periodo)

# ---- 1. Precio local vs. internacional (mismo mes) ------------------
# Correlación de referencia (04): 0.81

ggplot(base, aes(x = urea_int_usd_mt, y = precio_import_usd_mt)) +
  geom_point(size = 2.5, color = "blue") +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(
    title = "Precio local vs. precio internacional de la urea (mismo mes)",
    subtitle = "Correlación ≈ 0.81",
    x = "Precio internacional (USD/MT)",
    y = "Precio de importación Uruguay (USD/MT)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5))

# ---- 2. Precio local vs. internacional CON 1 MES DE REZAGO ----------
# Correlación ≈ 0.93

base_lag <- base %>%
  mutate(urea_int_lag1 = lag(urea_int_usd_mt, 1))

ggplot(base_lag %>% filter(!is.na(urea_int_lag1)),
       aes(x = urea_int_lag1, y = precio_import_usd_mt)) +
  geom_point(size = 2.5, color = "blue") +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(
    title = "Precio local vs. precio internacional (rezagado 1 mes)",
    subtitle = "Correlación ≈ 0.93 — el ajuste más fuerte de todos los rezagos probados",
    x = "Precio internacional, mes anterior (USD/MT)",
    y = "Precio de importación Uruguay (USD/MT)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5))

# ---- 3. Ambas series en el tiempo, superpuestas ----------------------
# Vemos el precio internacional y el precio local, con 1 mes de rezago, de forma superpuesta

base_largo <- base %>%
  select(periodo, precio_import_usd_mt, urea_int_usd_mt) %>%
  pivot_longer(-periodo, names_to = "serie", values_to = "precio") %>%
  mutate(serie = recode(serie,
                        precio_import_usd_mt = "Precio local (Uruguay)",
                        urea_int_usd_mt = "Precio internacional"))

ggplot(base_largo, aes(x = periodo, y = precio, color = serie)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  labs(
    title = "Precio local vs. internacional de la urea en el tiempo",
    x = "Fecha", y = "Precio (USD/MT)", color = NULL
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5), legend.position = "bottom")

# ---- 4. Precio local vs. gas natural y petróleo ----------------------
# Correlaciones de referencia (04): gas US 0.77, gas EU 0.69, Brent 0.70

vars_costos <- base %>%
  select(precio_import_usd_mt, gas_us_usd_mmbtu, gas_eu_usd_mmbtu, brent_usd_bbl) %>%
  pivot_longer(-precio_import_usd_mt, names_to = "variable", values_to = "valor") %>%
  mutate(variable = recode(variable,
                           gas_us_usd_mmbtu = "Gas natural US (USD/MMBtu)",
                           gas_eu_usd_mmbtu = "Gas natural Europa (USD/MMBtu)",
                           brent_usd_bbl = "Petróleo Brent (USD/barril)"))

ggplot(vars_costos, aes(x = valor, y = precio_import_usd_mt)) +
  geom_point(color = "blue", alpha = 0.7) +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  facet_wrap(~ variable, scales = "free_x") +
  labs(
    title = "Precio local de la urea vs. costos de producción",
    x = NULL, y = "Precio de importación Uruguay (USD/MT)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5))

# ---- 5. Precio local vs. tipo de cambio ------------------------------
# Correlación de referencia (04): 0.15 (casi nula, como esperado en USD)

ggplot(base, aes(x = tc_venta_uyu, y = precio_import_usd_mt)) +
  geom_point(size = 2.5, color = "blue") +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(
    title = "Precio local de la urea vs. tipo de cambio USD/UYU",
    subtitle = "Correlación ≈ 0.15 — esperable: ambas series están en USD",
    x = "Tipo de cambio (venta, UYU/USD)",
    y = "Precio de importación Uruguay (USD/MT)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5))

# ---- 6. Mapa de calor de correlaciones -------------------------------
# Versión visual de la matriz de correlación que ya calculó 04_exploracion_base.R

matriz_cor <- base %>%
  select(precio_import_usd_mt, urea_int_usd_mt, gas_us_usd_mmbtu,
         gas_eu_usd_mmbtu, brent_usd_bbl, tc_venta_uyu) %>%
  rename(
    `Precio local` = precio_import_usd_mt,
    `Precio internacional` = urea_int_usd_mt,
    `Gas US` = gas_us_usd_mmbtu,
    `Gas Europa` = gas_eu_usd_mmbtu,
    `Petróleo Brent` = brent_usd_bbl,
    `Tipo de cambio` = tc_venta_uyu
  ) %>%
  cor(use = "complete.obs")

cor_largo <- as.data.frame(matriz_cor) %>%
  mutate(var1 = rownames(matriz_cor)) %>%
  pivot_longer(-var1, names_to = "var2", values_to = "correlacion")

ggplot(cor_largo, aes(x = var1, y = var2, fill = correlacion)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(correlacion, 2)), size = 3.5) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red",
                       midpoint = 0, limits = c(-1, 1)) +
  labs(title = "Mapa de calor de correlaciones", x = NULL, y = NULL, fill = "r") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5),
        axis.text.x = element_text(angle = 45, hjust = 1))