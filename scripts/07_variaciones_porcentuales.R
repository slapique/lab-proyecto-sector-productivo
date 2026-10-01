library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

# Para estudiar pass-through, vamos a utilizar cambios porcentuales y no únicamente 
# modelo con niveles. Para esto utilizamos escala logartimica, que aproximan la 
# variación porcentual mensual.
# Al estar trabajando con precios, se admite la escala logartimica, porque por definicion
# no toma valores negativos.

base <- base %>%
  arrange(periodo) %>%
  mutate(
    dlog_uy  = log(precio_import_usd_mt) - log(lag(precio_import_usd_mt)),
    dlog_int = log(urea_int_usd_mt) - log(lag(urea_int_usd_mt))
  )

# Chequeo rápido
base %>%
  select(periodo, precio_import_usd_mt, dlog_uy, urea_int_usd_mt, dlog_int) %>%
  tail(10)

# Este cambio es útil por dos motivos: 
# 1. Permite interpretar los coeficientes del modelo directamente como elasticidades 
# aproximadas (cuánto varía porcentualmente el precio local ante una variación 
# porcentual delprecio internacional)
# 2.Reduce el riesgo de encontrar una relación espuria, ya que dos series con 
# tendencia pueden mostrar una correlación alta en niveles sin que exista una 
# relación real entre sus movimientos. 

# ---- CREAR REZAGOS DE LAS VARIACIONES LOGARÍTMICAS ----
# Para la regresión con rezagos, necesitamos desplazar las 
# log-diferencias 1, 2 y 3 meses.
# Esto permite modelar si el cambio en el precio internacional del mes pasado 
# (o hace dos/tres meses) afecta el cambio en el precio local de hoy.

base <- base %>%
  mutate(
    dlog_int_lag1 = lag(dlog_int, 1),
    dlog_int_lag2 = lag(dlog_int, 2),
    dlog_int_lag3 = lag(dlog_int, 3)
  )

# Verificación
base %>%
  select(periodo, dlog_int, dlog_int_lag1, dlog_int_lag2, dlog_int_lag3) %>%
  tail(6)
