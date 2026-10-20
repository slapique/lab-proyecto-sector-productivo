# ============================================================
# PASO 5 (generar información) — Modelo final de pass-through
#
# Responde las tres preguntas que pidió la profesora el 29/9:
#   A. ¿Hasta qué rezago dura el efecto del precio internacional?
#   B. ¿Cambian las conclusiones si se sacan los meses atípicos?
#   C. ¿El modelo está bien especificado? (AIC/BIC, residuos,
#      autocorrelación) y ¿aportan algo las variables de energía
#      y el tipo de cambio?
#
# Parte del modelo en variaciones porcentuales del script 10:
#   dlog_uy_t = a + b0*dlog_int_t + b1*dlog_int_{t-1} + ... + e_t
# donde dlog = diferencia de logaritmos = variación % mensual, y
# el pass-through acumulado es la suma de los b.
#
# Entrada: Datos/procesados/base_mensual_urea.csv
# Salida:  figuras/11a a 11d
#
# Escrito solo con R base (sin readr/dplyr/ggplot2) para que corra
# en cualquier computadora del grupo. Hay que tener el proyecto
# abierto (.Rproj) para que las rutas relativas funcionen.
# ============================================================

base <- read.csv("Datos/procesados/base_mensual_urea.csv", stringsAsFactors = FALSE)
base$periodo <- as.Date(base$periodo)
base <- base[order(base$periodo), ]
dir.create("figuras", showWarnings = FALSE)
library(sandwich)   # errores estándar Newey-West (HAC)
library(lmtest)     # tests de Durbin-Watson y Breusch-Pagan
# ---- 0. Variaciones porcentuales y rezagos (igual que en 07 y 10) -------
rezago <- function(x, k) c(rep(NA, k), head(x, -k))

base$dlog_uy  <- c(NA, diff(log(base$precio_import_usd_mt)))
base$dlog_int <- c(NA, diff(log(base$urea_int_usd_mt)))
for (k in 1:6) base[[paste0("dlog_int_lag", k)]] <- rezago(base$dlog_int, k)

# Variaciones de las otras X (para la sección C3)
base$dlog_gas   <- c(NA, diff(log(base$gas_hh_eia_usd_mmbtu)))
base$dlog_brent <- c(NA, diff(log(base$brent_usd_bbl)))
base$dlog_tc    <- c(NA, diff(log(base$tc_venta_uyu)))

# ============================================================
# A. ¿HASTA QUÉ REZAGO DURA EL EFECTO?
# ============================================================
# Estimamos 7 modelos, con 0 a 6 rezagos, todos sobre la MISMA muestra
# (los 49 meses que tienen los 6 rezagos disponibles), para que el
# AIC/BIC y los R² sean comparables entre sí.

base_6 <- base[complete.cases(base[, c("dlog_uy", paste0("dlog_int_lag", 1:6))]), ]
nrow(base_6)   # esperado: 49

modelos <- list()
tabla_A <- data.frame()
for (p in 0:6) {
  xs <- c("dlog_int", if (p > 0) paste0("dlog_int_lag", 1:p))
  f  <- as.formula(paste("dlog_uy ~", paste(xs, collapse = " + ")))
  m  <- lm(f, data = base_6)
  modelos[[p + 1]] <- m
  s  <- summary(m)
  ultimo <- tail(xs, 1)
  tabla_A <- rbind(tabla_A, data.frame(
    rezagos          = p,
    coef_ultimo      = round(coef(m)[ultimo], 3),
    p_ultimo         = round(s$coefficients[ultimo, 4], 4),
    pass_through     = round(sum(coef(m)[xs]), 3),
    R2_ajustado      = round(s$adj.r.squared, 3),
    AIC              = round(AIC(m), 1),
    BIC              = round(BIC(m), 1)
  ))
}
rownames(tabla_A) <- NULL
tabla_A

# Lectura (valores esperados):
#  rezagos coef_ultimo p_ultimo pass_through R2_aj    AIC    BIC
#     0       0.287     0.016      0.287     0.098   -72.8  -67.1
#     1       0.418     0.0003     0.563     0.313   -85.2  -77.6
#     2       0.331     0.0016     0.831     0.438   -94.1  -84.7
#     3      -0.048     0.68       0.781     0.428   -92.3  -81.0
#     4      -0.028     0.81       0.752     0.415   -90.4  -77.2
#     5       0.083     0.50       0.850     0.408   -88.9  -73.8
#     6       0.162     0.21       1.011     0.417   -88.9  -71.8
#
# * Los rezagos 0, 1 y 2 son significativos. Del rezago 3 en adelante
#   ningún coeficiente es distinto de cero (p entre 0,21 y 0,81), y el
#   pass-through acumulado deja de crecer.
# * El AIC y el BIC son mínimos con 2 rezagos: agregar más rezagos no
#   mejora el modelo, solo le suma ruido.
# * Respuesta: el efecto del precio internacional se reparte entre el
#   mes del cambio y los dos siguientes, y al tercer mes ya terminó.

# Figura 11a: coeficiente de cada rezago en el modelo con 6 rezagos,
# con su intervalo de confianza al 95%
m6 <- modelos[[7]]
ci <- confint(m6)[-1, ]
est <- coef(m6)[-1]
png("figuras/11a_coeficientes_por_rezago.png", width = 900, height = 550)
plot(0:6, est, pch = 19, ylim = range(c(ci, 0)), xaxt = "n",
     xlab = "Rezago (meses desde el cambio en el precio internacional)",
     ylab = "Coeficiente (elasticidad)",
     main = "Efecto del precio internacional sobre el precio de importación, por rezago",
     sub  = "Puntos: coeficiente estimado. Barras: intervalo de confianza al 95%. Modelo con 6 rezagos, n = 49")
axis(1, at = 0:6)
arrows(0:6, ci[, 1], 0:6, ci[, 2], angle = 90, code = 3, length = 0.05)
abline(h = 0, lty = 2, col = "grey40")
dev.off()

# ============================================================
# B. MODELO FINAL: 2 REZAGOS (el mismo "modelo 3" del script 10)
# ============================================================
# Se reestima sobre la muestra del script 10 (52 meses, los que tienen
# hasta 3 rezagos) para que los números coincidan con los ya informados.

base_f <- base[complete.cases(base[, c("dlog_uy", paste0("dlog_int_lag", 1:3))]), ]
nrow(base_f)   # esperado: 52

modelo_final <- lm(dlog_uy ~ dlog_int + dlog_int_lag1 + dlog_int_lag2, data = base_f)
summary(modelo_final)

# Pass-through acumulado = b0 + b1 + b2, con su intervalo de confianza.
# (La varianza de una suma de coeficientes sale de la matriz de
# varianzas-covarianzas del modelo.)
pass_through <- function(m, vars) {
  b  <- coef(m)[vars]
  V  <- vcov(m)[vars, vars]
  pt <- sum(b)
  se <- sqrt(sum(V))
  c(pass_through = round(pt, 3),
    IC_inf = round(pt - 1.96 * se, 3),
    IC_sup = round(pt + 1.96 * se, 3))
}
vars_f <- c("dlog_int", "dlog_int_lag1", "dlog_int_lag2")
pass_through(modelo_final, vars_f)

# Lectura (valores esperados):
#   b0 = 0,24 (p = 0,010), b1 = 0,25 (p = 0,010), b2 = 0,35 (p = 0,0003)
#   R² = 0,49 ; pass-through acumulado = 0,85, IC 95% [0,60 ; 1,10]
#
# * Un aumento de 1% en el precio internacional se traslada, en total,
#   en un 0,85% al precio de importación: 0,24 puntos el mismo mes,
#   0,25 al mes siguiente y 0,35 dos meses después.
# * El intervalo de confianza incluye el 1: con estos datos no se puede
#   descartar que la transmisión sea completa (100%). Lo que sí se puede
#   afirmar es que es alta (claramente mayor que 0,5) y que tarda tres
#   meses en completarse.

# Figura 11b: pass-through acumulado mes a mes
acum <- cumsum(coef(modelo_final)[vars_f])
png("figuras/11b_pass_through_acumulado.png", width = 800, height = 500)
plot(0:2, acum, type = "b", pch = 19, lwd = 2, ylim = c(0, 1), xaxt = "n",
     xlab = "Meses desde el cambio en el precio internacional",
     ylab = "Pass-through acumulado",
     main = "Cuánto del cambio en el precio internacional ya se trasladó al precio local")
axis(1, at = 0:2, labels = c("mismo mes", "1 mes después", "2 meses después"))
abline(h = 1, lty = 2, col = "grey40")
text(0:2, acum, labels = sprintf("%.2f", acum), pos = 3)
dev.off()

# ============================================================
# C1. ROBUSTEZ: EL MODELO FINAL SIN LOS MESES ATÍPICOS
# ============================================================
# Los 3 meses de bajo volumen (ene-22, mar-25, ene-26) tienen un precio
# unitario ruidoso. Como dlog_uy compara cada mes con el anterior, un
# precio raro contamina DOS variaciones: la de ese mes y la del
# siguiente. Por eso se sacan ambas.

meses_raros <- base$periodo[base$flag_bajo_volumen == TRUE]
mes_siguiente <- as.Date(sapply(meses_raros, function(d) seq(d, by = "month", length.out = 2)[2]))
excluir <- c(meses_raros, mes_siguiente)
format(excluir, "%Y-%m")

base_sin <- base_f[!(base_f$periodo %in% excluir), ]
nrow(base_sin)   # esperado: 48 (ene-22 y feb-22 ya no estaban en base_f)

modelo_sin <- lm(dlog_uy ~ dlog_int + dlog_int_lag1 + dlog_int_lag2, data = base_sin)
summary(modelo_sin)

comparacion <- data.frame(
  con_atipicos = round(coef(modelo_final), 3),
  sin_atipicos = round(coef(modelo_sin), 3)
)
comparacion
rbind(con = pass_through(modelo_final, vars_f),
      sin = pass_through(modelo_sin, vars_f))
c(R2_con = round(summary(modelo_final)$r.squared, 3),
  R2_sin = round(summary(modelo_sin)$r.squared, 3))

# Lectura (valores esperados):
#   con atípicos: 0,24 / 0,25 / 0,35 -> PT 0,85, R² 0,49
#   sin atípicos: 0,24 / 0,31 / 0,32 -> PT 0,87, R² 0,71
# * Los coeficientes casi no cambian y el pass-through pasa de 0,85 a
#   0,87. Las conclusiones no dependen de esos meses.
# * El R² salta de 0,49 a 0,71: los meses de bajo volumen son la
#   principal fuente de ruido del modelo, pero no sesgan el resultado.
# * El IC del pass-through sin atípicos es [0,70 ; 1,04]: más angosto.

# ============================================================
# C2. DIAGNÓSTICO DEL MODELO FINAL
# ============================================================

# (a) Autocorrelación de los residuos.
#     CORRECCIÓN (oct-2026): la versión anterior corría el test de
#     Ljung-Box solo a 6 rezagos (p = 0,12) y concluía que no había
#     autocorrelación. A 1 rezago sí la hay, y es NEGATIVA: la figura
#     11c lo mostraba y el texto decía lo contrario. Se corrige el
#     diagnóstico y se agregan errores estándar robustos (Newey-West).
Box.test(resid(modelo_final), lag = 1, type = "Ljung-Box")   # esperado: p = 0,005
Box.test(resid(modelo_final), lag = 6, type = "Ljung-Box")   # esperado: p = 0,12
acf(resid(modelo_final), plot = FALSE)$acf[2]                 # esperado: -0,38
dwtest(modelo_final, alternative = "two.sided")               # esperado: DW = 2,75, p = 0,007

# Lectura: hay autocorrelación negativa de primer orden (DW > 2, ACF
# negativa en el rezago 1). Es el patrón típico del ruido de medición
# en una serie que se diferencia: el precio de importación es un precio
# implícito (valor / toneladas) y un mes de poco volumen da un precio
# raro, que produce una variación demasiado alta seguida de una
# demasiado baja. No es dinámica que el modelo deje afuera (los rezagos
# 3 a 6 no aportan, sección A). La prueba: sin los meses de bajo
# volumen la autocorrelación casi desaparece.
Box.test(resid(modelo_sin), lag = 1, type = "Ljung-Box")     # esperado: p = 0,11
acf(resid(modelo_sin), plot = FALSE)$acf[2]                   # esperado: -0,22

# Consecuencia: los coeficientes siguen siendo insesgados, pero los
# errores estándar de mínimos cuadrados no son confiables. Se
# recalculan con Newey-West (HAC), que corrige por autocorrelación y
# heterocedasticidad. Con 3 rezagos de ventana (uno más que el modelo).
V_nw <- NeweyWest(modelo_final, lag = 3, prewhite = FALSE, adjust = TRUE)
coeftest(modelo_final, vcov. = V_nw)
# esperado: b0 = 0,24 (p = 0,0003), b1 = 0,25 (p = 0,0004), b2 = 0,35 (p < 0,0001)

# Pass-through con el intervalo Newey-West (misma función de la
# sección B, pasándole la matriz robusta)
pass_through_nw <- function(m, vars, V) {
  b  <- coef(m)[vars]
  pt <- sum(b)
  se <- sqrt(sum(V[vars, vars]))
  c(pass_through = round(pt, 3),
    IC_inf = round(pt - 1.96 * se, 3),
    IC_sup = round(pt + 1.96 * se, 3))
}
rbind(minimos_cuadrados = pass_through(modelo_final, vars_f),
      newey_west        = pass_through_nw(modelo_final, vars_f, V_nw))
# esperado: 0,85 [0,60 ; 1,10] con mínimos cuadrados
#           0,85 [0,74 ; 0,96] con Newey-West
# Lectura: los tres coeficientes siguen siendo significativos y el
# intervalo se angosta (con autocorrelación negativa, mínimos cuadrados
# sobreestima la incertidumbre). El resultado se sostiene y queda más
# firme: la transmisión es alta, y con Newey-West el 1 queda afuera del
# intervalo, o sea que no sería completa. Sin atípicos: 0,87 [0,76 ; 0,97].

png("figuras/11c_diagnostico_residuos.png", width = 1000, height = 450)
par(mfrow = c(1, 2))
acf(resid(modelo_final), main = "Autocorrelación de los residuos (modelo final)")
qqnorm(resid(modelo_final), main = "Residuos vs. distribución normal"); qqline(resid(modelo_final))
dev.off()
par(mfrow = c(1, 1))

# (b) Normalidad de los residuos
shapiro.test(resid(modelo_final))
# esperado: p < 0,001 -> los residuos no son normales. Se ve en el
# gráfico Q-Q: unas pocas observaciones muy alejadas (los meses de bajo
# volumen). No invalida los coeficientes (la estimación por mínimos
# cuadrados no necesita normalidad para ser insesgada), pero es otra
# razón para mostrar la versión sin atípicos.

# (b2) Heterocedasticidad. Test de Breusch-Pagan: la hipótesis nula es
#      que la varianza de los residuos es constante.
bptest(modelo_final)
# esperado: BP = 0,80, p = 0,85 -> no se rechaza; la varianza de los
# residuos es constante. Los errores estándar Newey-West de (a) cubren
# de todos modos autocorrelación y heterocedasticidad a la vez.

# (c) Residuos en el tiempo
base_f$residuo <- resid(modelo_final)
base_f[abs(base_f$residuo) > 2 * sd(base_f$residuo), c("periodo", "toneladas", "residuo")]
# esperado: solo dos residuos superan 2 desvíos, ene-2026 (+0,31) y
# feb-2026 (-0,31): el mes de menor volumen de toda la serie (48 ton) y
# el siguiente. Es exactamente el patrón de "un precio raro contamina dos
# variaciones" descrito en C1.

# ============================================================
# C2b. ¿EL EMPALME DE FUENTES SESGA EL RESULTADO?
# ============================================================
# Agregado (oct-2026). La Y viene de dos fuentes: Comtrade (2022-23) y
# Datamyne (2024-26). Se agrega al modelo final una variable 0/1 que
# vale 1 en los meses de Datamyne. Si su coeficiente no es distinto de
# cero, el cambio de fuente no desplaza las variaciones del precio ni
# altera los coeficientes de la urea internacional.
base_f$fuente_datamyne <- as.integer(base_f$fuente_y == "Datamyne")
table(base_f$fuente_y)   # esperado: Comtrade 20, Datamyne 32

modelo_fuente <- lm(dlog_uy ~ dlog_int + dlog_int_lag1 + dlog_int_lag2
                    + fuente_datamyne, data = base_f)
summary(modelo_fuente)
pass_through(modelo_fuente, vars_f)

# Lectura (valores esperados):
#   fuente_datamyne = 0,016 (p = 0,52): no es distinto de cero.
#   Los coeficientes de la urea quedan en 0,23 / 0,25 / 0,35 (contra
#   0,24 / 0,25 / 0,35 sin la dummy) y el pass-through en 0,83
#   [0,57 ; 1,09], dentro del intervalo del modelo final.
#   Conclusión: el empalme Comtrade -> Datamyne no sesga el resultado.
#   La dummy no se incorpora al modelo final porque no aporta.s

# ============================================================
# C3. ¿APORTAN ALGO EL GAS, EL BRENT Y EL TIPO DE CAMBIO?
# ============================================================
# Se agregan las variaciones porcentuales de las otras X al modelo final.

modelo_ampliado <- lm(dlog_uy ~ dlog_int + dlog_int_lag1 + dlog_int_lag2
                      + dlog_gas + dlog_brent + dlog_tc, data = base_f)
summary(modelo_ampliado)
pass_through(modelo_ampliado, vars_f)
c(AIC_final = round(AIC(modelo_final), 1), AIC_ampliado = round(AIC(modelo_ampliado), 1))

# Lectura (valores esperados):
# * Gas Henry Hub: 0,19 (p = 0,0002). Sí aporta: una suba de 1% en el gas
#   se asocia a 0,19% más en el precio de importación, además de lo que
#   ya explica la urea internacional.
# * Brent: 0,23 (p = 0,13) y tipo de cambio: -0,55 (p = 0,43). No son
#   significativos: no agregan información.
# * Los rezagos 1 y 2 de la urea internacional se mantienen (0,30 y 0,29);
#   el contemporáneo baja a 0,16 y pierde significación (p = 0,11) porque
#   parte de su efecto lo absorbe el gas del mismo mes. PT 0,75
#   [0,50 ; 1,00]. El AIC mejora (-102,8 -> -114,5) por el gas.
# * Conclusión: el modelo final se queda con los 2 rezagos de la urea
#   internacional. El gas es un complemento válido para explicar el
#   precio local, pero no cambia la medición del pass-through, que es la
#   pregunta del trabajo. Brent y tipo de cambio quedan afuera.

# ============================================================
# D. FIGURA: OBSERVADO VS. AJUSTADO
# ============================================================
png("figuras/11d_observado_vs_ajustado.png", width = 1000, height = 500)
plot(base_f$periodo, base_f$dlog_uy * 100, type = "l", lwd = 2, col = "grey30",
     xlab = "", ylab = "Variación mensual del precio de importación (%)",
     main = "Variación observada vs. explicada por el modelo final")
lines(base_f$periodo, fitted(modelo_final) * 100, lwd = 2, col = "firebrick")
abline(h = 0, lty = 3)
legend("topright", legend = c("Observada", "Ajustada por el modelo"),
       col = c("grey30", "firebrick"), lwd = 2, bty = "n")
dev.off()

# ============================================================
# RESUMEN PARA EL INFORME
# ============================================================
# 1. ¿Cuánto se transmite?  0,85 (IC 95%: 0,60 a 1,10). Transmisión alta;
#    no se puede descartar que sea completa.
# 2. ¿Cuánto demora?  Se reparte en tres meses: 0,24 el mismo mes, 0,25
#    al mes siguiente y 0,35 dos meses después. Del tercer mes en
#    adelante no hay efecto.
# 3. ¿Es robusto?  Sin los meses atípicos: 0,87. Los residuos tienen
#    autocorrelación negativa de primer orden (ruido del precio
#    implícito); con errores estándar Newey-West los coeficientes
#    siguen siendo significativos y el IC del pass-through es
#    [0,74 ; 0,96]. El modelo con 2 rezagos es el mejor por AIC y BIC.
# 4. ¿Otras variables?  El gas natural aporta (0,19); Brent y tipo de
#    cambio no.
