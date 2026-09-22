# ============================================================
# PASO 3 — Preparar la base mensual
# Une las cuatro fuentes en una sola tabla: una fila = un mes.
#   Y : precio de importación de urea (Comtrade + Datamyne)     -> Flor
#   X : urea internacional, gas US, gas Europa, Brent (Pink Sheet)
#   X : gas Henry Hub (EIA)  [misma serie que "gas US" del Pink Sheet]
#   X : tipo de cambio USD/UYU (BROU), promedio mensual
# Resultado: Datos/procesados/base_mensual_urea.csv
# ============================================================

library(readr)
library(readxl)
library(dplyr)
library(lubridate)
library(here)

# ---- 1. Y: precio de importación de urea ---------------------------
y <- read_csv(here("Datos", "precio_import_urea__2022enadelante.csv"),
              show_col_types = FALSE) %>%
  mutate(periodo = ym(periodo),
         flag_bajo_volumen = toneladas < 1000) %>%
  select(periodo, toneladas, precio_import_usd_mt = precio_usd_ton,
         fuente_y = fuente, flag_bajo_volumen)

# ---- 2. X del Pink Sheet (Banco Mundial) ---------------------------
# Mismo criterio que el script de Flor: 6 filas de encabezado,
# columnas por posición (1 fecha, 3 Brent, 8 gas US, 9 gas Europa, 61 urea).
crudo <- read_excel(here("Datos", "CMO-Historical-Data-Monthly.xlsx"),
                    sheet = "Monthly Prices", col_names = FALSE,
                    skip = 6, na = "…")
ps <- crudo %>%
  transmute(periodo         = ym(sub("M", "-", ...1)),
            urea_int_usd_mt = as.numeric(...61),
            brent_usd_bbl   = as.numeric(...3)) %>%
  filter(periodo >= ymd("2022-01-01"))

# ---- 3. X: gas Henry Hub (EIA) -------------------------------------
gas <- read_xls(here("Datos", "precios gas natural"),
                sheet = "Data 1", skip = 2) %>%
  rename(fecha = 1, gas_hh_eia_usd_mmbtu = 2) %>%
  mutate(periodo = floor_date(as_date(fecha), "month"),
         gas_hh_eia_usd_mmbtu = as.numeric(gas_hh_eia_usd_mmbtu)) %>%
  filter(periodo >= ymd("2022-01-01")) %>%
  select(periodo, gas_hh_eia_usd_mmbtu)

# ---- 4. X: tipo de cambio BROU, de diario a mensual ----------------
tc <- read_excel(here("Datos", "Cotización monedas.xlsx"),
                 sheet = "Fuente BROU", na = "..") %>%
  transmute(fecha  = dmy(Fecha),
            compra = as.numeric(`Dólar.USA.Compra`),
            venta  = as.numeric(`Dólar.USA.Venta`)) %>%
  filter(fecha >= ymd("2022-01-01")) %>%
  mutate(periodo = floor_date(fecha, "month")) %>%
  group_by(periodo) %>%
  summarise(tc_compra_uyu = mean(compra),
            tc_venta_uyu  = mean(venta),
            tc_dias       = n(),
            .groups = "drop")

# ---- 5. UNIR -------------------------------------------------------
# La Y llega a sep-2026 pero el Pink Sheet a ago-2026: el inner_join
# con el Pink Sheet recorta la base al último mes con todas las X.
base <- y %>%
  inner_join(ps,  by = "periodo") %>%
  left_join(gas,  by = "periodo") %>%
  left_join(tc,   by = "periodo") %>%
  arrange(periodo)

# ---- 6. CHEQUEOS ---------------------------------------------------
dim(base)                         # esperado: 56 filas x 13 columnas
c(min = format(min(base$periodo), "%Y-%m"),
  max = format(max(base$periodo), "%Y-%m"))   # esperado: 2022-01 a 2026-08
colSums(is.na(base))              # esperado: todo 0
sum(duplicated(base$periodo))     # esperado: 0
setdiff(seq(min(base$periodo), max(base$periodo), by = "month"),
        base$periodo)             # esperado: vacío (sin huecos)
glimpse(base)


# ---- 7. GUARDAR ----------------------------------------------------
dir.create(here("Datos", "procesados"), showWarnings = FALSE)
write_csv(base, here("Datos", "procesados", "base_mensual_urea.csv"))
