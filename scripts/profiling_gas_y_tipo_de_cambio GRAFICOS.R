# ============================================================
# Profiling de las dos series que faltaban perfilar
#   (a) Gas natural Henry Hub (EIA)      -> Datos/precios gas natural
#   (b) Tipo de cambio USD/UYU (BROU)    -> Datos/Cotización monedas.xlsx
# Misma estructura de 6 pasos que usó Flor en los otros scripts.
# ============================================================

library(readxl)
library(dplyr)
library(lubridate)
library(here)

# ############################################################
# (a) GAS NATURAL HENRY HUB — EIA
# ############################################################

# ---- CARGA ---------------------------------------------------------
# El archivo es un Excel viejo (.xls) que quedó guardado SIN extensión.
# read_xls() lo lee igual porque mira el contenido, no el nombre.
# Hoja "Data 1": 2 filas de título arriba, después Date / precio.
ruta_gas <- here("Datos", "precios gas natural")

gas <- read_xls(ruta_gas, sheet = "Data 1", skip = 2) %>%
  rename(fecha = 1, gas_hh_usd_mmbtu = 2) %>%
  mutate(periodo = floor_date(as_date(fecha), "month"),   # 15/1/1997 -> 1/1/1997
         gas_hh_usd_mmbtu = as.numeric(gas_hh_usd_mmbtu)) %>%
  filter(periodo >= ymd("2022-01-01")) %>%
  select(periodo, gas_hh_usd_mmbtu)

# ---- 1. ESTRUCTURA -------------------------------------------------
dim(gas)        # esperado: 56 filas x 2 columnas (ene-2022 a ago-2026)
glimpse(gas)

# ---- 2. IDENTIDAD --------------------------------------------------
gas %>% summarise(filas = n(),
                  periodo_unicos = n_distinct(periodo),
                  periodo_nulos  = sum(is.na(periodo)))
# Criterio: filas == periodo_unicos y periodo_nulos == 0 -> periodo es la clave

# ---- 3. COMPLETITUD ------------------------------------------------
colSums(is.na(gas))          # esperado: todo 0
sapply(gas, n_distinct)      # ninguna columna constante

# ---- 4. DUPLICADOS -------------------------------------------------
sum(duplicated(gas)); sum(duplicated(gas$periodo))   # esperado: 0 y 0

# ---- 5. TIPOS ------------------------------------------------------
sapply(gas, class)           # periodo = Date, precio = numeric

# ---- 6. COHERENCIA -------------------------------------------------
c(min = format(min(gas$periodo), "%Y-%m"), max = format(max(gas$periodo), "%Y-%m"))
rango_esperado <- seq(min(gas$periodo), max(gas$periodo), by = "month")
length(rango_esperado); nrow(gas)
setdiff(rango_esperado, gas$periodo)     # esperado: vacío (sin huecos)
gas %>% summarise(min = min(gas_hh_usd_mmbtu), max = max(gas_hh_usd_mmbtu),
                  no_validos = sum(gas_hh_usd_mmbtu <= 0))
# Rango plausible: entre ~2 y ~9 USD/MMBtu en este período. Sin negativos ni ceros.


# ############################################################
# (b) TIPO DE CAMBIO USD/UYU — BROU
# ############################################################

# ---- CARGA ---------------------------------------------------------
# Es una serie DIARIA (una fila por día hábil, desde 2001). Los faltantes
# vienen como "..". Nos quedamos con compra y venta del dólar y la
# pasamos a mensual promediando los días de cada mes.
ruta_tc <- here("Datos", "Cotización monedas.xlsx")

tc_diario <- read_excel(ruta_tc, sheet = "Fuente BROU", na = "..") %>%
  transmute(fecha  = dmy(Fecha),                     # "03-01-2022" -> 2022-01-03
            compra = as.numeric(`Dólar.USA.Compra`),
            venta  = as.numeric(`Dólar.USA.Venta`)) %>%
  filter(fecha >= ymd("2022-01-01"))

# ---- 1. ESTRUCTURA (diario) ----------------------------------------
dim(tc_diario)        # esperado: ~1164 filas x 3 columnas
glimpse(tc_diario)

# ---- 2. IDENTIDAD (diario) -----------------------------------------
tc_diario %>% summarise(filas = n(),
                        fecha_unicas = n_distinct(fecha),
                        fecha_nulas  = sum(is.na(fecha)))
# Acá la clave es la fecha (día), no el mes: un mes tiene ~20 filas.

# ---- 3. COMPLETITUD (diario) ---------------------------------------
colSums(is.na(tc_diario))    # esperado: 0 en 2022+ (los ".." están antes de 2022)

# ---- 4. DUPLICADOS (diario) ----------------------------------------
sum(duplicated(tc_diario)); sum(duplicated(tc_diario$fecha))   # esperado: 0 y 0

# ---- 5. TIPOS ------------------------------------------------------
sapply(tc_diario, class)     # fecha = Date, compra/venta = numeric

# ---- 6. COHERENCIA (diario) ----------------------------------------
tc_diario %>% summarise(compra_min = min(compra), compra_max = max(compra),
                        venta_min  = min(venta),  venta_max  = max(venta),
                        venta_menor_a_compra = sum(venta < compra),   # esperado: 0
                        no_validos = sum(compra <= 0 | venta <= 0))   # esperado: 0

# ---- PASO A MENSUAL ------------------------------------------------
# Para unir con las otras series (todas mensuales) necesitamos un valor
# por mes. Usamos el promedio de los días hábiles del mes y guardamos
# cuántos días entraron en cada promedio (n_dias) para detectar meses cortos.
tc <- tc_diario %>%
  mutate(periodo = floor_date(fecha, "month")) %>%
  group_by(periodo) %>%
  summarise(tc_compra = mean(compra),
            tc_venta  = mean(venta),
            tc_medio  = (tc_compra + tc_venta) / 2,
            n_dias    = n(),
            .groups = "drop")

dim(tc)                       # esperado: 57 filas (ene-2022 a sep-2026)
rango_esperado <- seq(min(tc$periodo), max(tc$periodo), by = "month")
setdiff(rango_esperado, tc$periodo)   # esperado: vacío
tc %>% filter(n_dias < 15)    # meses con pocos días: solo sep-2026 (mes incompleto)


# ############################################################
# CIERRE: cobertura de las 4 fuentes (para el paso 3, unir la base)
# ############################################################
# Urea importada (Flor):          2022-01 a 2026-09
# Pink Sheet urea/gas/Brent:      2022-01 a 2025-12   <-- OJO, es la más corta
# Gas Henry Hub (EIA):            2022-01 a 2026-08
# Tipo de cambio BROU (mensual):  2022-01 a 2026-09