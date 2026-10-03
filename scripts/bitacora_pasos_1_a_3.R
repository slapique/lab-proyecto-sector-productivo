# ============================================================
# PASS-THROUGH DE LA UREA EN URUGUAY
# Bitácora de los pasos 1 a 3: recolección, perfilado y base mensual
# ============================================================
#
# OBJETIVO DEL TRABAJO
# Determinar cuánto del precio internacional de la urea se traslada al
# precio de importación en Uruguay y con qué demora (pass-through).
#
# Para eso necesitamos:
#   Y  = precio de importación de la urea en Uruguay (lo que queremos explicar)
#   X  = precio internacional de la urea, gas natural (principal insumo
#        para fabricarla), petróleo y tipo de cambio (lo que podría explicarlo)
#
# Este script cubre los tres primeros pasos del plan: recolectar las
# series, perfilarlas una por una y unirlas en una base mensual. Deja
# los gráficos en la carpeta "figuras". Los pasos siguientes (explorar,
# rezagos, modelo, conclusiones) van en scripts aparte.
# ============================================================

library(readr)
library(readxl)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(here)

dir.create(here("figuras"), showWarnings = FALSE)


# ############################################################
# PASO 1. RECOLECCIÓN
# ############################################################
#
# Todas las fuentes son públicas y gratuitas. Quedaron en la carpeta Datos:
#
#   VARIABLE                          ARCHIVO                                   FUENTE               FRECUENCIA
#   Precio de importación urea (Y)    precio_import_urea__2022enadelante.csv    Comtrade + Datamyne  mensual
#   Urea internacional, gas US,       CMO-Historical-Data-Monthly.xlsx          Banco Mundial        mensual
#     gas Europa, Brent                                                          (Pink Sheet set-2026)
#   Gas natural Henry Hub             precios gas natural                       EIA (EE.UU.)         mensual
#   Tipo de cambio USD/UYU            Cotización monedas.xlsx                   BROU                 diaria
#
# La Y se construyó a partir de las importaciones uruguayas de urea
# (partida HS 310210): para cada mes, valor CIF en dólares / toneladas
# importadas = precio implícito por tonelada. Comtrade solo tenía datos
# hasta 2023; 2024 en adelante se completó con Datamyne, que además
# informa la cantidad de operaciones del mes.
#
# El Pink Sheet se actualizó a la edición de setiembre de 2026, que trae
# datos hasta agosto de 2026 (la versión anterior llegaba a diciembre de
# 2025). Comparadas las dos ediciones, la estructura del archivo es
# idéntica y las únicas diferencias en los valores son de redondeo.


# ############################################################
# PASO 2. PERFILADO
# ############################################################
#
# Antes de usar un dataset hay que revisarlo. A cada fuente le aplicamos
# los mismos seis chequeos:
#   1. Estructura   - filas, columnas, qué representa cada fila
#   2. Identidad    - cuál es la clave (acá el mes), única y sin nulos
#   3. Completitud  - nulos, falsos nulos, columnas constantes
#   4. Duplicados   - filas o meses repetidos
#   5. Tipos        - fechas como fechas, números como números
#   6. Coherencia   - rangos plausibles, sin huecos, relaciones internas
#
# El detalle línea por línea está en los scripts de perfilado
# (profiling_precio_importación_urea.R, ProfilingDatos_x_worldbank.R y
# profiling_gas_y_tipo_de_cambio.R). Acá se resume qué se encontró.

# ---- 2a. Precio de importación de urea (Y) --------------------------
# 57 meses, ene-2022 a set-2026, sin huecos ni duplicados. El precio por
# tonelada coincide exactamente con valor / toneladas en todas las filas.
# "n_ops" tiene nulos en 2022-2023 porque Comtrade no informa cantidad
# de operaciones: es un nulo estructural, no un dato perdido.

y <- read_csv(here("Datos", "precio_import_urea__2022enadelante.csv"),
              show_col_types = FALSE) %>%
  mutate(periodo = ym(periodo),
         flag_bajo_volumen = flag_bajo_volumen == "True")

dim(y)                                  # 57 x 9
setdiff(seq(min(y$periodo), max(y$periodo), by = "month"), y$periodo)  # sin huecos

# Tres meses quedaron marcados como de bajo volumen: importaciones muy
# chicas donde el precio implícito es poco confiable porque se calcula
# sobre casi nada. Se conservan en la base pero hay que tenerlos en
# cuenta al modelar.
y %>% filter(flag_bajo_volumen) %>%
  select(periodo, toneladas, precio_usd_ton, fuente)

# ---- 2b. Variables del Pink Sheet ----------------------------------
# El archivo tiene 6 filas de encabezado y marca faltantes con "…".
# Se leen las columnas por posición: 1 fecha, 3 Brent, 8 gas US,
# 9 gas Europa, 61 urea. Recortado a 2022 en adelante: 56 meses,
# sin nulos, sin huecos, sin duplicados, todos los valores positivos.

crudo <- read_excel(here("Datos", "CMO-Historical-Data-Monthly.xlsx"),
                    sheet = "Monthly Prices", col_names = FALSE,
                    skip = 6, na = "…")
ps <- crudo %>%
  transmute(periodo          = ym(sub("M", "-", ...1)),
            urea_int_usd_mt  = as.numeric(...61),
            gas_us_usd_mmbtu = as.numeric(...8),
            gas_eu_usd_mmbtu = as.numeric(...9),
            brent_usd_bbl    = as.numeric(...3)) %>%
  filter(periodo >= ymd("2022-01-01"))

dim(ps)                                 # 56 x 5
colSums(is.na(ps))                      # todo 0
c(desde = format(min(ps$periodo), "%Y-%m"), hasta = format(max(ps$periodo), "%Y-%m"))

# ---- 2c. Gas natural Henry Hub (EIA) -------------------------------
# Excel antiguo (.xls) con 2 filas de título. Las fechas vienen al día 15
# de cada mes y se llevan al día 1 para poder unirlas con el resto.
# 56 meses hasta ago-2026, sin nulos ni huecos.

gas <- read_xls(here("Datos", "precios gas natural"),
                sheet = "Data 1", skip = 2) %>%
  rename(fecha = 1, gas_hh_eia_usd_mmbtu = 2) %>%
  mutate(periodo = floor_date(as_date(fecha), "month"),
         gas_hh_eia_usd_mmbtu = as.numeric(gas_hh_eia_usd_mmbtu)) %>%
  filter(periodo >= ymd("2022-01-01")) %>%
  select(periodo, gas_hh_eia_usd_mmbtu)

dim(gas)                                # 56 x 2
summary(gas$gas_hh_eia_usd_mmbtu)       # entre ~2 y ~9 USD/MMBtu, sin negativos

# ---- 2d. Tipo de cambio BROU ---------------------------------------
# Es la única serie DIARIA: una fila por día hábil desde 2001, faltantes
# marcados como "..". Nos quedamos con compra y venta del dólar desde 2022.
# En ese tramo: sin nulos, sin fechas repetidas, y la venta siempre mayor
# que la compra.

tc_diario <- read_excel(here("Datos", "Cotización monedas.xlsx"),
                        sheet = "Fuente BROU", na = "..") %>%
  transmute(fecha  = dmy(Fecha),
            compra = as.numeric(`Dólar.USA.Compra`),
            venta  = as.numeric(`Dólar.USA.Venta`)) %>%
  filter(fecha >= ymd("2022-01-01"))

tc_diario %>% summarise(dias = n(),
                        fechas_repetidas = sum(duplicated(fecha)),
                        nulos = sum(is.na(compra) | is.na(venta)),
                        venta_menor_a_compra = sum(venta < compra))   # 1164, 0, 0, 0

# Como todas las demás series son mensuales, el tipo de cambio se pasa a
# mensual promediando los días hábiles de cada mes. Se guarda cuántos
# días entraron en cada promedio (tc_dias) para detectar meses cortos.
tc <- tc_diario %>%
  mutate(periodo = floor_date(fecha, "month")) %>%
  group_by(periodo) %>%
  summarise(tc_compra_uyu = mean(compra),
            tc_venta_uyu  = mean(venta),
            tc_dias       = n(),
            .groups = "drop")

tc %>% filter(tc_dias < 15)
# Abril-2023 tiene 14 días por la Semana de Turismo y feriados;
# set-2026 tiene 8 porque el mes no había terminado al bajar los datos.

# ---- 2e. Cobertura de las cuatro fuentes ---------------------------
tibble(fuente = c("Urea importada (Y)", "Pink Sheet", "Gas Henry Hub (EIA)", "Tipo de cambio BROU"),
       desde  = c(min(y$periodo), min(ps$periodo), min(gas$periodo), min(tc$periodo)),
       hasta  = c(max(y$periodo), max(ps$periodo), max(gas$periodo), max(tc$periodo)))
# La Y y el TC llegan a set-2026; el Pink Sheet y EIA, a ago-2026.


# ############################################################
# PASO 3. BASE MENSUAL
# ############################################################
#
# Objetivo: una sola tabla con una fila por mes y una columna por
# variable. Se une todo por la columna "periodo".
#
# La Y llega a set-2026 pero el Pink Sheet a ago-2026. Como el precio
# internacional de la urea es la variable central del trabajo, la base
# se recorta al último mes con todas las variables disponibles:
# 56 meses, ene-2022 a ago-2026. Set-2026 se incorpora cuando salga la
# próxima edición del Pink Sheet (2 de octubre).

base <- y %>%
  select(periodo, toneladas, precio_import_usd_mt = precio_usd_ton,
         fuente_y = fuente, flag_bajo_volumen) %>%
  inner_join(ps,  by = "periodo") %>%     # inner: recorta a lo que tiene Pink Sheet
  left_join(gas,  by = "periodo") %>%
  left_join(tc,   by = "periodo") %>%
  arrange(periodo)

# Chequeo de la base unida
dim(base)                               # 56 x 13
colSums(is.na(base))                    # todo 0
sum(duplicated(base$periodo))           # 0
setdiff(seq(min(base$periodo), max(base$periodo), by = "month"), base$periodo)  # vacío
glimpse(base)

# La base queda guardada en Datos/procesados/base_mensual_urea.csv
# (la genera el script 03_preparar_base_mensual.R) y es el insumo de
# todos los pasos siguientes.

# ---- Una decisión: gas del Pink Sheet o gas de EIA ------------------
# Teníamos dos series de gas natural de EE.UU. Comparadas mes a mes,
# son la misma serie (Henry Hub) con diferencias de redondeo:
cor(base$gas_us_usd_mmbtu, base$gas_hh_eia_usd_mmbtu)          # 0.9999
max(abs(base$gas_us_usd_mmbtu - base$gas_hh_eia_usd_mmbtu))    # 0.17
# Para el modelo se usa una sola: la del Pink Sheet, porque viene de la
# misma fuente y con el mismo criterio que el precio internacional de la
# urea. La de EIA queda en la base solo como control.


# ############################################################
# CÓMO SE VE LA BASE (gráficos, se guardan en figuras/)
# ############################################################

# ---- Figura 1: precio de la urea, importación vs internacional -------
fig1 <- base %>%
  select(periodo,
         `Importación Uruguay`      = precio_import_usd_mt,
         `Internacional (Pink Sheet)` = urea_int_usd_mt) %>%
  pivot_longer(-periodo, names_to = "serie", values_to = "usd_mt") %>%
  ggplot(aes(periodo, usd_mt, colour = serie)) +
  geom_line(linewidth = 0.9) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %y") +
  labs(title = "Precio de la urea: importación en Uruguay vs. internacional",
       subtitle = "Enero 2022 a agosto 2026",
       x = NULL, y = "USD por tonelada", colour = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "top")

fig1
ggsave(here("figuras", "01_urea_importacion_vs_internacional.png"),
       fig1, width = 9, height = 4.5, dpi = 150, bg = "white")

# Lectura: las dos series se mueven juntas y el precio de importación
# parece reaccionar con algo de demora a los movimientos del
# internacional. Eso es exactamente lo que se mide en los pasos 4 a 6.

# ---- Figura 2: variables explicativas ------------------------------
fig2 <- base %>%
  select(periodo,
         `Gas natural US (USD/MMBtu)`     = gas_us_usd_mmbtu,
         `Gas natural Europa (USD/MMBtu)` = gas_eu_usd_mmbtu,
         `Petróleo Brent (USD/barril)`    = brent_usd_bbl,
         `Tipo de cambio venta (UYU/USD)` = tc_venta_uyu) %>%
  pivot_longer(-periodo, names_to = "serie", values_to = "valor") %>%
  ggplot(aes(periodo, valor)) +
  geom_line(linewidth = 0.8, colour = "#0B1623") +
  facet_wrap(~ serie, scales = "free_y", ncol = 2) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(title = "Variables explicativas", subtitle = "Enero 2022 a agosto 2026",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 12)

fig2
ggsave(here("figuras", "02_variables_explicativas.png"),
       fig2, width = 9, height = 6, dpi = 150, bg = "white")

# ---- Figura 3: toneladas importadas por mes ------------------------
# Muestra cómo se distribuye la importación a lo largo del año y dónde
# caen los tres meses de bajo volumen.
fig3 <- base %>%
  ggplot(aes(periodo, toneladas / 1000, fill = flag_bajo_volumen)) +
  geom_col() +
  scale_fill_manual(values = c(`FALSE` = "#0B1623", `TRUE` = "#B6A173"),
                    labels = c("Normal", "Bajo volumen"), name = NULL) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %y") +
  labs(title = "Toneladas de urea importadas por mes",
       subtitle = "Enero 2022 a agosto 2026",
       x = NULL, y = "Miles de toneladas") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "top")

fig3
ggsave(here("figuras", "03_toneladas_importadas.png"),
       fig3, width = 9, height = 4.5, dpi = 150, bg = "white")


# ############################################################
# QUÉ SIGUE
# ############################################################
# Paso 4, explorar:  series en variaciones porcentuales y correlación
#                    del precio local con el internacional del mismo mes
#                    y de 1, 2 y 3 meses atrás.
# Paso 5, rezagos:   definir cuántos meses de demora incluir.
# Paso 6, modelo:    regresión del precio de importación sobre el
#                    internacional (con rezagos), el gas y el tipo de
#                    cambio. La suma de los coeficientes de los rezagos
#                    es el pass-through acumulado.
# Paso 7:            responder cuánto se transmite, cuánto demora y qué
#                    variables influyen.
