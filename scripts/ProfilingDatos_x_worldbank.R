# ============================================================
# Profiling de las variables X del World Bank (Pink Sheet)
# Fuente: Datos/CMO-Historical-Data-Monthly.xlsx, hoja "Monthly Prices"
# Extrae: urea y petróleo Brent, mensual, 2022+
# ============================================================

install.packages("ggplot2")
library(readxl)
library(dplyr)
library(lubridate)
library(here)
library(ggplot2)

ruta <- here("Datos", "CMO-Historical-Data-Monthly.xlsx")

# ---- CARGA + LIMPIEZA ESTRUCTURAL ----------------------------------
# El archivo tiene 6 filas de encabezado y marca los faltantes con "…".
#   - skip = 6      --> salta títulos, nombres y unidades; empieza en los datos
#   - col_names = F --> las columnas quedan como ...1, ...2, ...
#   - na = "…"      --> convierte los puntos suspensivos en NA (falso nulo)
crudo <- read_excel(ruta, sheet = "Monthly Prices",
                    col_names = FALSE, skip = 6, na = "…")

# Columnas por posición (1-based en R):
#   1 = fecha - 3 = Brent - 8 = gas US - 9 = gas Europa - 61 = Urea
x <- crudo %>%
  transmute(
    periodo_txt            = ...1,
    urea_usd_mt            = as.numeric(...61),
    petroleo_brent_usd_bbl = as.numeric(...3)
  ) %>%
  mutate(periodo = ym(sub("M", "-", periodo_txt))) %>%   # "2022M01" --> 2022-01-01
  filter(periodo >= ymd("2022-01-01")) %>%               # recorte para matchear la Y
  select(periodo, urea_usd_mt, petroleo_brent_usd_bbl)

# ---- 1. ESTRUCTURA -------------------------------------------------
dim(x)
glimpse(x)
#48 filas y 5 columnas --> "periodo, urea_usd_mt, gas_us_usd_mmbtu, gas_eu_usd_mmbtu, petroleo_brent_usd_bbl"

# ---- 2. IDENTIDAD --------------------------------------------------
x %>% summarise(filas = n(),
                periodo_unicos = n_distinct(periodo),
                periodo_nulos  = sum(is.na(periodo)))

# ---- 3. COMPLETITUD ------------------------------------------------
colSums(is.na(x)) #nos dice todo = 0, o sea no hay nulos
sapply(x, n_distinct)   #no hay columnas constantes, sin embargo "urea_usd_mt" da 47 y no 48 (dos meses tienen exactamente el mismo precio de urea internacional)

# ---- 4. DUPLICADOS -------------------------------------------------
sum(duplicated(x)); sum(duplicated(x$periodo))

# ---- 5. TIPOS ------------------------------------------------------
# periodo ya es Date; las 4 series son numéricas ya
sapply(x, class)

# ---- 6. COHERENCIA -------------------------------------------------
# rango y huecos
c(min = format(min(x$periodo), "%Y-%m"), max = format(max(x$periodo), "%Y-%m"))
rango_esperado <- seq(min(x$periodo), max(x$periodo), by = "month") 
#el período que estamos analizando nosotoros pero OJO pq solo llega hasta 
#el 12 del 25

length(rango_esperado); nrow(x)
setdiff(rango_esperado, x$periodo)          # debería dar vacío
# rangos plausibles (sin negativos ni ceros)
x %>% summarise(across(-periodo,
                       list(min = ~min(.), max = ~max(.),
                            no_validos = ~sum(. <= 0, na.rm = TRUE))))

# ---- 7. GRÁFICO: PRECIO INTERNACIONAL DE LA UREA -------------------


ggplot(x, aes(x = periodo, y = urea_usd_mt)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  labs(
    title = "Precio internacional de la urea, 2022-2025",
    x = "Fecha",
    y = "Precio (USD/MT)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5),
    panel.grid.minor = element_blank()
  )

