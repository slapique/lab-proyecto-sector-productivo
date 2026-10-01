
base <- read.csv(
  "Datos/procesados/base_mensual_urea.csv",
  stringsAsFactors = FALSE
)

# Como mi compu bloquea los prog de readr, dplyr, etc pruebo si me funciona sin asi
head(base)
names(base)

modelo_con <- lm(
  precio_import_usd_mt ~ tc_dias + gas_hh_eia_usd_mmbtu + urea_int_usd_mt,
  data = base
)

summary(modelo_con)

# MODELO SIN DATOS ATIPICOS
base_sin <- base[base$flag_bajo_volumen == FALSE, ]

modelo_sin <- lm(
  precio_import_usd_mt ~ tc_dias + gas_hh_eia_usd_mmbtu + urea_int_usd_mt,
  data = base_sin
)

summary(modelo_sin)

#LO PRIMERO QUE NOTAMOS ES QUE EL MODELO PASA DE EXPLICAR APROXIMADAMENTE (SE MIDE CON R2)
#79,2% A 82% DE LA VAR. DEL PRECIO DE IMPORTACION.ADEMAS QEU EL VALOR RESIDUAL BAJE SIGNIFICA
#QUE LAS PREDICCIONES Q NOS VA A DAR VAN A QUEDAR MAS CERCA DE LOS VALORES OBSERVADOS.

#COMPARACION DE AMBOS MODELOS (CON Y SIN)
coef(modelo_con)
coef(modelo_sin)

#COEF SE MANTIENEN RELATIVAMENTE ESTABLES Y CONSERVAN SIGNOS.