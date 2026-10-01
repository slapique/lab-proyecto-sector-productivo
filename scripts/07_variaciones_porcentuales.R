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