# ============================================================
# PASO 5 (generar información) — Primera aproximación al modelo
# Regresión en NIVELES del precio de importación contra las X.
# Es un primer modelo para ver si las relaciones tienen sentido;
# el modelo definitivo (en variaciones porcentuales) va en 10 y 11.
# Entrada: Datos/procesados/base_mensual_urea.csv
# ============================================================
#
# CORRECCIÓN (oct-2026): la versión anterior usaba tc_dias como
# tipo de cambio. tc_dias es la cantidad de días con cotización en
# el mes (15 a 22), no el tipo de cambio. La variable correcta es
# tc_venta_uyu. También usaba gas_us_usd_mmbtu, que no existe en la
# base: la serie de gas es gas_hh_eia_usd_mmbtu (Henry Hub, EIA).
# Los comentarios de abajo están actualizados con los resultados
# del modelo corregido.

library(readr)
library(dplyr)
library(here)

base <- read_csv(here("Datos", "procesados", "base_mensual_urea.csv"),
                 show_col_types = FALSE) %>%
  mutate(periodo = as.Date(periodo)) %>%
  arrange(periodo)

# ---- 1. Modelo en niveles -------------------------------------------
# precio de importación (USD/ton) explicado por el precio internacional,
# el gas natural y el tipo de cambio, todos del mismo mes.

modelo_nivel <- lm(precio_import_usd_mt ~ urea_int_usd_mt + gas_hh_eia_usd_mmbtu
                   + tc_venta_uyu, data = base)
summary(modelo_nivel)

# Lectura (valores esperados):
# * Precio internacional: 0,57 -> por cada USD que sube la urea
#   internacional, el precio de importación sube 0,57 USD/ton (p < 0,001).
# * Gas Henry Hub: 40 -> por cada USD/mmbtu que sube el gas, el precio
#   de importación sube ~40 USD/ton (p < 0,001).
# * Tipo de cambio: -18 (p = 0,007). Signo negativo: meses con dólar
#   más alto en pesos se asocian a un precio de importación en USD más
#   bajo. No es el foco del trabajo y en correlación simple la relación
#   era casi nula (0,15); se vuelve a probar en el modelo final en
#   variaciones (script 11), donde no resulta significativo.
# * R² = 0,816: el modelo explica el 81,6% de la variación del precio.

# ---- 2. Modelo log-log ----------------------------------------------
# Tomamos logaritmos de todas las variables (son precios, siempre
# positivos). Los coeficientes se leen como elasticidades: cuánto %
# cambia la Y cuando la X cambia 1%.

modelo_log <- lm(log(precio_import_usd_mt) ~ log(urea_int_usd_mt)
                 + log(gas_hh_eia_usd_mmbtu) + log(tc_venta_uyu), data = base)
summary(modelo_log)

# Lectura (valores esperados):
# * 1% más de precio internacional -> 0,58% más de precio de importación.
# * 1% más de gas -> 0,25% más.
# * 1% más de tipo de cambio -> -1,6% (mismo signo que arriba).
# * R² = 0,820.
#
# OJO: el R² de este modelo NO se puede comparar con el del modelo en
# niveles, porque la variable que explican es distinta (precio vs. log
# del precio). La versión anterior de este script los comparaba; eso
# se saca. Elegimos el log-log por interpretación (elasticidades),
# no por ajuste.

# ---- 3. Problema de los modelos en niveles: residuos autocorrelacionados
# Si los residuos de un mes se parecen a los del mes anterior, el modelo
# está dejando afuera la dinámica temporal y los p-valores son
# demasiado optimistas. Lo vemos con la función de autocorrelación.

dir.create(here("figuras"), showWarnings = FALSE)
png(here("figuras", "06_acf_residuos_modelo_niveles.png"), width = 800, height = 500)
acf(resid(modelo_log), main = "Autocorrelación de los residuos — modelo log-log en niveles")
dev.off()
acf(resid(modelo_log), main = "Autocorrelación de los residuos — modelo log-log en niveles")

# La barra del rezago 1 queda muy por encima de la banda azul: los
# residuos están autocorrelacionados. Por eso el análisis sigue en
# VARIACIONES porcentuales (diferencias de logaritmos), que elimina la
# tendencia común de las series y es la forma estándar de estimar
# pass-through. Eso se hace en los scripts 07, 10 y 11.