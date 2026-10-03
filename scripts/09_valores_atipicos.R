# ============================================================
# PASO 5 (generar información) — Robustez: modelo con y sin meses atípicos
# La profesora pidió correr la regresión con y sin los datos atípicos
# para ver si las conclusiones cambian. Los atípicos son los 3 meses
# de bajo volumen (menos de 1.000 toneladas importadas): ene-2022,
# mar-2025 y ene-2026, marcados con flag_bajo_volumen en la base.
# Entrada: Datos/procesados/base_mensual_urea.csv
# ============================================================
#
# CORRECCIÓN (oct-2026): la versión anterior usaba tc_dias (cantidad de
# días con cotización en el mes) en lugar del tipo de cambio. Se
# reemplaza por tc_venta_uyu y se actualizan los comentarios con los
# resultados corregidos.
#
# Nota: este script usa solo R base (sin readr/dplyr) porque en una de
# las computadoras del grupo esos paquetes no se pueden instalar.
# Funciona igual: hay que tener el proyecto abierto (.Rproj) para que
# la ruta relativa a Datos/ sea la correcta.

base <- read.csv("Datos/procesados/base_mensual_urea.csv",
                 stringsAsFactors = FALSE)

# ---- 1. Los tres meses atípicos ---------------------------------------
base[base$flag_bajo_volumen == TRUE,
     c("periodo", "toneladas", "precio_import_usd_mt")]

# ---- 2. Modelo con todos los meses (56) ---------------------------------
modelo_con <- lm(precio_import_usd_mt ~ urea_int_usd_mt + gas_hh_eia_usd_mmbtu
                 + tc_venta_uyu, data = base)
summary(modelo_con)

# ---- 3. Modelo sin los meses atípicos (53) -----------------------------
base_sin <- base[base$flag_bajo_volumen == FALSE, ]
nrow(base_sin)   # esperado: 53

modelo_sin <- lm(precio_import_usd_mt ~ urea_int_usd_mt + gas_hh_eia_usd_mmbtu
                 + tc_venta_uyu, data = base_sin)
summary(modelo_sin)

# ---- 4. Comparación lado a lado -----------------------------------------
comparacion <- data.frame(
  con_atipicos = round(coef(modelo_con), 3),
  sin_atipicos = round(coef(modelo_sin), 3)
)
comparacion
c(R2_con = round(summary(modelo_con)$r.squared, 3),
  R2_sin = round(summary(modelo_sin)$r.squared, 3))

# Lectura (valores esperados):
#                        con     sin
#   urea internacional  0,574   0,597
#   gas Henry Hub       40,1    40,1
#   tipo de cambio     -18,4   -13,9
#   R²                  0,815   0,836
#
# * Los coeficientes mantienen el signo y un tamaño muy parecido. El del
#   precio internacional se mueve de 0,57 a 0,60; el del gas no cambia.
# * El R² sube un poco (de 0,82 a 0,84) y el error estándar residual baja:
#   sin los meses ruidosos el modelo ajusta mejor, como era de esperar.
# * El tipo de cambio es el que más se mueve (de -18 a -14) y pierde
#   fuerza estadística (p pasa de 0,007 a 0,048): es el coeficiente
#   menos estable de los tres, otra razón para no apoyarse en él.
#
# Conclusión: las tres observaciones de bajo volumen no cambian las
# relaciones que encuentra el modelo. Se mantienen en la base (no se
# borran), y la misma prueba se repite sobre el modelo definitivo en
# variaciones porcentuales en el script 11.
