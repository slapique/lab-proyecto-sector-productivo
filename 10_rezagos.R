
install.packages("here")
library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

base <- read_csv(here("Datos", "procesados", "base_mensual_urea.csv"),
                 show_col_types = FALSE) %>%
  mutate(periodo = as.Date(periodo)) %>%
  arrange(periodo)

base


# Var ln PRECIO IMP = ln(Pt) - ln(Pt-1), cuanto varia % en el mes anterior
base <- base %>%
  mutate(
    dlog_uy = log(precio_import_usd_mt) - lag(log(precio_import_usd_mt)),
    
# Var ln PRECIO INTERNACIONAL
dlog_int = log(urea_int_usd_mt) - lag(log(urea_int_usd_mt))
  )

#rezagos
base <- base %>%
  mutate(
    dlog_int_lag1 = lag(dlog_int, 1),
    dlog_int_lag2 = lag(dlog_int, 2),
    dlog_int_lag3 = lag(dlog_int, 3)
  )

#todos los modelos utilicen los mismos meses
base_rezagos <- base %>%
  drop_na(
    dlog_uy,
    dlog_int,
    dlog_int_lag1,
    dlog_int_lag2,
    dlog_int_lag3
  )

# probamos varios modelos porque no sabemos donde se va a producir el cambio 
# Mod 1 - efecto en el mismo mes
modelo_1 <- lm(
  dlog_uy ~ dlog_int,
  data = base_rezagos
)

# Mod 2 - efecto el mes + el siguiente
modelo_2 <- lm(
  dlog_uy ~ dlog_int + dlog_int_lag1,
  data = base_rezagos
)

# Mod 3 - efecto agregando 2 meses de demora
modelo_3 <- lm(
  dlog_uy ~ dlog_int + dlog_int_lag1 + dlog_int_lag2,
  data = base_rezagos
)

# Mod 4 - efecto agregando 3 meses de demora
modelo_4 <- lm(
  dlog_uy ~ dlog_int + dlog_int_lag1 + dlog_int_lag2 + dlog_int_lag3,
  data = base_rezagos
)

summary(modelo_1)
summary(modelo_2)
summary(modelo_3)
summary(modelo_4)

#miramos los dlog_int - ahi nos damos cuenta de cuando varia el precio de importacion si el precio internacional varia un 1%
#miramos pvalor - cuanto mas chico, mas evidencia tenemos de que el coeficiente es distinto de 0

#modelo 1 = muestra coeficiente de 0,288%, cuando el precio int varia un 1% el precio de imp sube un 0,288%
# el p valor es < 0,05 (valor estandar), entonces hay evidencia estadistica que el efecto es distinto de cero
# modelo 2 = vemos que en el mes actual sube un 0,17% el precio de imp cuando el precio int varia un 1%, controlado por lo que paso el mes anterior. pero se ve que una suba del precio int en un 1% el mes ANTERIOR se asocia a una suba de 0,38% ESTE MES
# el pvalor da evidencia de que el efecto mucho mas fuerte, 0,0004, una parte importante de la transicion puede ocurrir con un mes de retraso.
# modelo 3 = una suba del 1% en el precio internacional HACE 2 MESES se asocia con una suba de 0,35% en el mes ACTUAL
# el p valor es el que muestra eivdencia mas fuerte de los 3, siendo de 0,00028.
# calculamos el pass-through porque los efectos se distribuyen en el tiempo, y nos da 0,85, o sea que la transmision del precio no ocurre de golpe, se va transmitiendo durante varios meses. Un aumento de un 1% en el precio int se asocia con una suba ACUMULADA de 0,85% en el precio de imp a lo largo de dos meses.
# modelo 4 = da valor negativo, etnonces concluimos que no hay evidencia de que el cambio en el precio int de hace 3 meses tenga que ver con el precio de imp hoy.

