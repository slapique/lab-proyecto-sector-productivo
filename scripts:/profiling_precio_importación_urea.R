# ============================================================
# Data profiling de la base mensual de urea
# ============================================================

library(readr)
library(dplyr)
library(lubridate)
library(here)

# ---- CARGA ---------------------------------------------------------
# ESTO LO TENGO QUE CAMBIAR CUANDO ME ACEPTE SOFI LO QUE SUBI DE LOS DATOS UNIDOS
#df <- read_csv(here("data", "processed", "base_urea_precio_mensual.csv"),
#               show_col_types = FALSE)
df <- read_csv(
  here("Datos", "precio_import_urea__2022enadelante.csv"),
  col_types = cols(
    periodo           = col_character(),
    anio              = col_integer(),
    mes               = col_integer(),
    toneladas         = col_double(),
    valor_cif_usd     = col_double(),
    precio_usd_ton    = col_double(),
    fuente            = col_character(),
    n_ops             = col_double(),
    flag_bajo_volumen = col_character()
  )
) %>%
  mutate(flag_bajo_volumen = flag_bajo_volumen == "True")

# ---- 1. ESTRUCTURA -------------------------------------------------
dim(df)          # filas x columnas--> 57 filas, unidad meses (desde el 22 hasta set-26)
glimpse(df)      # tipos que infirió el lector + vistazo
#de aca sacamos mucha info:
# 1."período" --> aparece con comillas, lo lee como texto, no como fecha
# 2."fuente" --> "Comtrade" nos confirma que la tabla esta ordenada cronológicamente
# 3. "n_ops" --> valores nulos para las primeras filas que las trajimos de "comtrade" --> los datos que obtuvimos de ahí no tienen conteo de operaciones


# ---- 2. IDENTIDAD (clave primaria / unidad de observación) ---------
# Criterio de clase: n_únicos == n_filas  Y  n_nulos == 0
df %>% summarise(
  filas          = n(),
  periodo_unicos = n_distinct(periodo),
  periodo_nulos  = sum(is.na(periodo))
)
# 'anio' y 'mes' NO son clave: se repiten (varios meses por año, etc.). 
n_distinct(df$anio)   # te da 5  (2022 a 2026)
n_distinct(df$mes)    # te da 12 (enero a diciembre)


# ---- 3. COMPLETITUD (nulos por columna) ----------------------------
colSums(is.na(df))
# Ojo: distinguir "falta el dato" de "no corresponde" (NA estructural)
#la única columna que tiene NA es "n_ops" como ya vimos--> ¿ese nulo es un dato perdido o es que no corresponde? --> NA estructural, no corresponde
df %>% group_by(fuente) %>% summarise(n_ops_nulos = sum(is.na(n_ops)), filas = n())
# --- Falsos nulos: vacíos disfrazados de texto ("", "N/A", "-") --> no hay
sapply(df, function(x) if (is.character(x)) sum(x %in% c("", "N/A", "NA", "-")) else 0)
# --- Columnas constantes: un solo valor = varianza cero = no informa --> no hay
sapply(df, n_distinct)   # cualquier columna que dé 1 es constante


# ---- 4. DUPLICADOS -------------------------------------------------
sum(duplicated(df))            # filas idénticas --> no hay 
sum(duplicated(df$periodo))    # meses repetidos --> no hay


# ---- 5. TIPOS ------------------------------------------------------
class(df$periodo)   # viene como texto "YYYY-MM" -> conviene pasarlo a fecha
df <- df %>% mutate(periodo = ym(periodo))   # lo pasamos a formato fehca --> ahora ordena y grafica bien
class(df$periodo) #confirmamos que quedo OK


# ---- 6. COHERENCIA -------------------------------------------------
# 6a. Identidad interna: precio == valor / toneladas --> chequear que tiene sentido cómo esta calculado el precio
df %>% mutate(chequeo = valor_cif_usd / toneladas) %>%
  summarise(coincide = all(abs(chequeo - precio_usd_ton) < 1e-6))

# 6b. Rangos plausibles (valores sin negativos ni ceros)
df %>% summarise(
  precio_min = min(precio_usd_ton), precio_max = max(precio_usd_ton),
  ton_min = min(toneladas),         ton_max = max(toneladas),
  no_validos = sum(precio_usd_ton <= 0 | toneladas <= 0)
) #todo OK



# 6c. Serie mensual COMPLETA y sin huecos (clave para los rezagos)
rango_esperado <- seq(min(df$periodo), max(df$periodo), by = "month")
length(rango_esperado)   # meses esperados
nrow(df)                 # meses presentes
setdiff(rango_esperado, df$periodo)   # huecos (da 0 como buscabamos)

# 6d. Meses de bajo volumen (precio unitario ruidoso) --> a tener en cuenta, son 3 datos atípicos en dónde la importación fue muy bajita
df %>% filter(flag_bajo_volumen) %>%
  select(periodo, toneladas, precio_usd_ton, fuente)

