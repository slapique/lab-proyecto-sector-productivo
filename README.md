# Bitácora del proyecto — Pass-through de la urea en Uruguay

**Materia:** Introducción a la Ciencia de Datos — Universidad de Montevideo
**Repositorio:** `lab-proyecto-sector-productivo`
**Última actualización:** setiembre 2026

---

## 1. El proyecto

**Sector:** agroindustria — mercado uruguayo de fertilizantes.

**Tema:** el *pass-through* de la urea, es decir, cómo se trasladan los cambios del
precio **internacional** de la urea al precio **local** (de importación) en Uruguay.

**Pregunta principal:**
> ¿Cuánto del aumento o caída del precio internacional de la urea termina reflejándose
> en Uruguay, y cuánto demora en hacerlo?

**Por qué importa:** Uruguay importa casi toda la urea que consume, así que es *tomador
de precios*. En teoría, lo que pasa en el mercado internacional debería reflejarse en el
precio local, pero ese traslado no tiene por qué ser completo ni inmediato. Medir ese
mecanismo ayuda a anticipar costos del sector agropecuario.

**Enfoque:** trabajamos con un solo fertilizante, la **urea** (un nitrogenado *simple*),
para que la serie de precios sea homogénea y la comparación consistente. La variable a
explicar se mide en **dólares (USD)**, lo que aísla el pass-through internacional del
ruido cambiario.

### Variables

| Rol | Variable | Fuente |
|---|---|---|
| **Y** (a explicar) | Precio de importación de la urea (USD/ton, CIF) | Comtrade + Datamyne |
| **X** | Precio internacional de la urea (USD/ton) | World Bank (Pink Sheet) |
| **X** | Gas natural (USD/mmbtu) — insumo de la urea | World Bank (Pink Sheet) |
| **X** | Petróleo Brent (USD/bbl) — proxy energético/flete | World Bank (Pink Sheet) |
| **X** (control) | Tipo de cambio USD/UYU | BCU / INE |

Las tres preguntas que buscamos responder al final:
**¿Cuánto se transmite? → ¿Cuánto demora? → ¿Qué variables influyen?**

---

## 2. Método de trabajo

Cada dataset se procesa por separado con el mismo circuito de *data profiling*
antes de unir la base:

**carga → estructura → identidad → completitud → duplicados → tipos → coherencia**

Recién cuando cada fuente está limpia y validada se unen todas por la columna `periodo`
(una fila = un mes). Perfilar cada una por separado aísla los problemas en su fuente y
evita arrastrarlos a la tabla final.

---

## 3. Registro de avances

### 3.1 Recolección de datos

- **Precio de importación de urea (Y).** Se descargó de dos fuentes que comparten origen
  (la aduana uruguaya): **UN Comtrade** para 2022–2023 (código HS `310210`, reporter
  Uruguay, importaciones, partner World, mensual) y **Datamyne** para 2024 en adelante
  (a nivel operación). Se decidió arrancar en 2022 para dejar afuera la pandemia.
- **Precios internacionales (X).** *Pink Sheet* del World Bank
  (`CMO-Historical-Data-Monthly.xlsx`): urea, gas natural y petróleo Brent.
- **Tipo de cambio.** BCU / INE (`Cotización monedas.xlsx`).

### 3.2 Construcción de la base de la Y

Comtrade viene **agregado** (un total por mes) y Datamyne viene **por operación**, así
que a Datamyne hubo que agregarlo a total mensual (sumando todas las empresas y orígenes)
para dejarlo al mismo nivel que Comtrade. El precio se calcula como
`valor CIF (USD) ÷ toneladas`.

**Chequeo de compatibilidad entre fuentes:** ambas usan el mismo criterio de valor
(**CIF, USD**) y la misma unidad de peso (kg), y el empalme 2023→2024 es continuo, sin
saltos artificiales — lo que confirma que se pueden pegar en una sola serie. Resultado:
una base mensual de **57 meses** (2022-01 a 2026-09).

### 3.3 Profiling de la Y — hallazgos

- **Estructura:** 57 filas × 9 columnas. Unidad de observación: un mes.
- **Clave primaria:** `periodo` (57 valores únicos, sin nulos ni repetidos).
- **Completitud:** la única columna con nulos es `n_ops` (24 NA). Son **NA estructurales**,
  no datos perdidos: corresponden a las filas de Comtrade, que al ser agregado no trae el
  conteo de operaciones. No se rellenan ni se borran.
- **Tipos:** `periodo` venía como texto y se convirtió a fecha (`ym()`).
- **Coherencia:** el precio coincide con `valor ÷ toneladas` en todas las filas; sin
  valores negativos ni ceros; **serie mensual continua, sin huecos** (condición necesaria
  para el análisis de rezagos).
- **A vigilar:** 3 meses de **bajo volumen** (ene-2022, mar-2025, ene-2026) marcados con
  `flag_bajo_volumen`. Se importó tan poco esos meses que el precio unitario sale ruidoso.
  No se corrigen ahora: se dejan marcados y se decide en la etapa de modelado (por ejemplo,
  corriendo el modelo con y sin ellos como chequeo de robustez).

### 3.4 Profiling de las X del World Bank — hallazgos

El *Pink Sheet* no es una tabla limpia: trae 6 filas de encabezado, decenas de columnas
(de las que se usan 3) y datos desde 1960. La limpieza estructural consistió en saltar el
encabezado, seleccionar las columnas de urea/gas/petróleo, parsear la fecha (`1960M01` →
fecha) y **tratar los `…` como NA** (falsos nulos: si no, R leería esas columnas como texto).

- **Estructura (ya limpia):** 48 filas × 5 columnas (`periodo` + urea + gas US + gas Europa
  + Brent), todas numéricas.
- **Completitud:** sin nulos en la ventana 2022–2025 (los `…` estaban en datos viejos).
- **Duplicados:** ninguno. **Coherencia:** serie continua, rangos plausibles (urea
  285–925 USD/ton, gas US 1,5–8,8, gas Europa 8–70, Brent 63–120).
- **Observación:** la versión inicial del Pink Sheet llegaba solo hasta **dic-2025**,
  mientras la Y llega hasta set-2026 → se detectó una brecha de cobertura.

### 3.5 Actualización y unión de la base

- Se **actualizó el Pink Sheet a agosto-2026**, CUIDADO PQ PENSAMOS QUE LO ACTUALIZAMOS A SETIEMBRE PERO TODAVÍA NO ESTAN LOS DATOS DE SETIEMBRE
- Tenemos 2 bases de datos sobre el **gas natural** o sea, esta duplicado, ya que la base de 
datos del "pink sheet" ya lo tiene a ese dato, hay que elegir con 
cuál nos quedamos y cuál borramos, yo (Flor) me quedaría con el 
pink sheet porque tiene el precio del gas de europa y 
el de EEUU --> más completo
- Se perfilo también el **tipo de cambio**.
- Se **unió la base mensual** (Y + X) por `periodo`, dejando la tabla lista para el análisis.

---

## 4. Decisiones tomadas

- **Un solo fertilizante (urea)** para homogeneidad de la serie.
- **Variable Y en USD** → el tipo de cambio queda como control secundario, no protagonista.
- **Valor CIF** en ambas fuentes de la Y, para que el empalme sea comparable.
- **Ventana desde 2022** (deja afuera la pandemia).
- **Meses de bajo volumen** marcados, no eliminados (se deciden en el modelado).

### Decisiones pendientes

- **Qué serie de gas usar:** US (más estable) o Europa (capta mejor el shock energético de
  2022). Se resuelve al modelar, probando ambas.

---

## 6. Aprendizajes de datos (para el informe)

- **El dataset es la salida de un proceso, no la realidad.** Comtrade, Datamyne y el Pink
  Sheet fueron armados para otros fines; hubo que interpretarlos y adaptarlos.
- **Distinguir "falta el dato" de "no corresponde".** Los NA de `n_ops` son estructurales.
- **Los falsos nulos disfrazados de texto** (`…` del World Bank) cambian el tipo de toda
  una columna si no se los trata.
- **Compatibilidad entre fuentes:** al combinar dos orígenes (Comtrade + Datamyne) hay que
  verificar que midan lo mismo (mismo criterio de valor, unidad y producto) antes de pegarlos.
- **Un outlier real no se borra en la limpieza:** se marca y se decide en el análisis.

