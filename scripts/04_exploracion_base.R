# ============================================================
# PASO 3 — Exploración de la base mensual unida --> ya hicimos una parte antes, pero esto es una exploración más exahustiva
# Describir cada variable y ver cómo se relacionan, ANTES de modelar.
# (Los gráficos van en otro script -> paso 6.)
# Entrada: Datos/procesados/base_mensual_urea.csv
# ============================================================
#install.packages(c("readr", "dplyr", "tidyr", "here", "lubridate"))

library(readr)
library(dplyr)
library(tidyr)
library(here)

base <- read_csv(here("Datos", "procesados", "base_mensual_urea.csv"),
                 show_col_types = FALSE) %>%
  mutate(periodo = as.Date(periodo)) %>%
  arrange(periodo)

glimpse(base)   # 56 filas x 13 columnas (2022-01 a 2026-08)



# ---- 1. DESCRIPTIVAS + COEFICIENTE DE VARIACIÓN --------------------
# El CV (sd/media) permite comparar la volatilidad entre variables
# de distinta escala (el gas vale ~3 y la urea ~500).

descriptivas <- base %>%
  select(toneladas, precio_import_usd_mt, urea_int_usd_mt,
         gas_hh_eia_usd_mmbtu, brent_usd_bbl, tc_venta_uyu)%>%
  pivot_longer(everything(), names_to = "variable", values_to = "valor") %>%
  group_by(variable) %>%
  summarise(media = mean(valor), mediana = median(valor), sd = sd(valor),
            minimo = min(valor), maximo = max(valor),
            CV_pct = round(sd(valor) / mean(valor) * 100, 1),
            .groups = "drop") %>%
  arrange(desc(CV_pct))
descriptivas

# Lectura: el gas y las toneladas son lo más volátil;
# el tipo de cambio es lo más estable (CV ~4%) -> en USD casi no pesa.
# otro dato interesante es ver las medianas y media
# la brecha entre precio internacional ($470) y precio de 
# importación ($512) es de ~$42/MT, o sea como 9% más caro lo 
# que pagó Uruguay.

# ---- 2. CORRELACIONES ENTRE VARIABLES ------------------------------
base %>%
  select(precio_import_usd_mt, urea_int_usd_mt, gas_hh_eia_usd_mmbtu,
         tc_venta_uyu)%>%
  cor(use = "complete.obs") %>% round(2)
# Lectura: precio local vs internacional = 0.81 (fuerte, o sea vemos que hay una fuerte transmisión del precio);
# Precio local ↔ Gas US: 0.77 (fuerte)
# → Tiene sentido: la urea se produce con gas natural, así que cuando sube el gas, sube el costo de producción
# precio local vs tipo de cambio = 0.15 (casi nada, como esperábamos en USD).

# ---- 3. PASS-THROUGH: local vs internacional con REZAGOS -----------
# La pregunta del proyecto: ¿cuánto se transmite y con qué demora?
# Comparamos el precio local con el internacional del mismo mes,
# de 1, 2 y 3 meses antes. El rezago con MAYOR correlación sugiere
# cuánto tarda en trasladarse.


cat("PASS-THROUGH CON LAGS:\n")
for (lag in 0:12) {
  if (lag == 0) {
    corr <- cor(base$precio_import_usd_mt, base$urea_int_usd_mt)
    cat("Lag 0 (contemporáneo):", round(corr, 4), "\n")
  } else {
    corr <- cor(base$precio_import_usd_mt[-(1:lag)], 
                base$urea_int_usd_mt[1:(nrow(base)-lag)])
    cat("Lag", lag, "mes(es):", round(corr, 4), "\n")
  }
}

# le extendí los lags para que vaya hasta 12 meses --> la profe nos pidió que veamos este efecto.
# podemos ver que el efecto del precio internacional dura aproximadamente 7-8 meses, después la correlación baja a menos de 0.5 y se vuelve insignificante

# lo que vemos aca es que, la correlación "lag 0" que sería el mismo mes, da 81% --> fuerte
# pero la correlación con lag 1 (1 mes desp) da 93% --> MUCHO MÁS FUERTE
# El precio internacional se transmite al precio local con ~1 mes de retraso. Cuando sube el precio internacional en enero, Uruguay ajusta sus precios de importación principalmente en febrero.


# ---- 4. MARGEN local / internacional (variable derivada) ----------

base <- base %>% mutate(ratio_local_int = precio_import_usd_mt / urea_int_usd_mt)
base %>% summarise(ratio_medio = mean(ratio_local_int),
                   ratio_min = min(ratio_local_int),
                   ratio_max = max(ratio_local_int))

# Ratio medio 1.12, eso quiere decir -->  el precio local está ~12% por encima del internacional
# (coherente con CIF + flete + márgenes).
# de todas formas, hay que también saber que hay mucha variablidad entre el máx 65% y el mín, a veces paga mucho más por encima y aveces más por debajo.


# ---- 5. CHEQUEO DEL FLAG DE BAJO VOLUMEN -----

base %>% filter(toneladas < 1000) %>%
  select(periodo, toneladas, precio_import_usd_mt, flag_bajo_volumen)
# -> recalcular la bandera:
base <- base %>% mutate(flag_bajo_volumen = toneladas < 1000)
# Verificá que quedó correcta la bandera
base %>% filter(flag_bajo_volumen == TRUE) %>%
  select(periodo, toneladas, precio_import_usd_mt, flag_bajo_volumen)


# ---- 6. COMPARACIÓN POR FUENTE (Comtrade vs Datamyne) -------------
# Chequeo de que el empalme de las dos fuentes de la Y no metió sesgo.
base %>% group_by(fuente_y) %>%
  summarise(meses = n(),
            precio_medio = mean(precio_import_usd_mt),
            ton_media = mean(toneladas))
# La diferencia de precio es por el PERÍODO (Comtrade=2022-23 caro,
# Datamyne=2024-26 más barato), no por sesgo de fuente. Las toneladas
# medias son parecidas -> empalme sano.

# ---- 7. CREAR REZAGOS DEL PRECIO INTERNACIONAL ----
# Para estudiar cuánto demora la transmisión, desplazamos 
# el precio internacional 1, 2 y 3 meses hacia atrás.

base <- base %>%
  mutate(
    precio_int_lag1 = lag(urea_int_usd_mt, 1),
    precio_int_lag2 = lag(urea_int_usd_mt, 2),
    precio_int_lag3 = lag(urea_int_usd_mt, 3)
  )

base %>% select(periodo, urea_int_usd_mt, precio_int_lag1, precio_int_lag2, precio_int_lag3) %>% head(5)