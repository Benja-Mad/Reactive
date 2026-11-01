# Rutinas: propiedades y reglas, no recetas

> Documento de propuesta histórica. El comportamiento implementado desde el 21 de octubre de 2026
> está en [Gameplay elemental](gameplay-elemental.md). En particular, `raise` ya no crea un muro,
> los campos comparten una ley de fuerza y las reacciones tienen un momento explícito.

Diseño para implementar C++ (más elementos, menos telegrafiado) y las ideas tomadas de Control,
pensado para un survivor. Parte del código actual: `recipe.gd`, `build.gd`, `spellwork.gd`,
`node_editor.gd`, `world_matter.gd`.

## El problema con C++ tal como está escrito

C++ resuelve "pocos elementos" escribiendo tablas a mano: unas 25 materias con nombre en C+, más
unas 40 al sumar `arc`, más una tabla secreta de 7 × 3 lecturas por especialista. Eso tiene tres
costos en un survivor:

- **Es muy predefinido.** Cada celda es contenido que hay que diseñar, dibujar, balancear y
  mantener. Lo que el jugador "descubre" es una lista, no un sistema.
- **No es intuitivo.** "`hack` sobre la raya = se zambulle en su sombra" no se puede deducir; solo
  se memoriza. El «?» de la bitácora esconde esas sorpresas, pero no las vuelve lógicas.
- **El editor tendría que explicar cada celda a mano.** Es justo lo que hoy falla: mostrar qué hace
  una combinación.

## La idea: pocas propiedades y pocas reglas

En vez de recetas (A + B = C con nombre propio), la materia **y las máquinas** comparten un
vocabulario corto de propiedades, y unas pocas reglas físicas actúan sobre ellas. Las combinaciones
salen solas, se pueden razonar, y el editor las explica generando el texto desde las mismas reglas.

### Propiedades (iguales para materia y máquinas)

| propiedad | valores | qué la cambia |
|---|---|---|
| `temp` | −2 congelado · −1 frío · 0 · +1 caliente · +2 ardiendo | fuego, frío, la llama de Brasa, el contacto |
| `wet` | sí / no | agua, lluvia, ánimas del Sereno |
| `charge` | 0, 1, 2 | arco |
| `grav` | −1 repele · 0 · +1 atrae | pozo, repulsor |
| `mass` | número (vapor ligero, agua media, hielo y chatarra pesados) | la sustancia, la fase |
| `code` | ninguno · señuelo · contrasello | piezas de código (etapa 3) |

La fase del agua **sale de `temp`**: −1 o menos es hielo, +1 o más es vapor, +2 es vapor hirviendo.
Los flags actuales se vuelven propiedades: `hard` = hielo a −2, `scald` = vapor a +2,
`well`/`repel` = `grav` ±1, `coat` sigue como carga explosiva.

Cada máquina tiene **etiquetas** fijas además de sus propiedades: material (`metal`, `piedra`,
`carne`, `cera`, `agua`), `mass`, `vuela`. Ejemplos: el repartidor es metal y rápido; el quiltro
es carne con pelo; la gárgola es piedra pesada; la raya vuela y es liviana; la Novia lleva agua;
la animita es cera y fuego.

### Las reglas (corren en el host, en `spellwork.tick`)

1. **Calor.** Lo que se toca tiende a la temperatura del otro, un paso cada ~0,5 s. Agua que llega
   a −1 se congela y a +1 hierve. Máquina mojada y fría → congelada 1 s. Máquina mojada que toca
   algo caliente → nube de vapor y se seca. Cera caliente → la animita se reenciende.
2. **Conducción.** La carga salta entre cosas conductoras en contacto: agua, chatarra, máquinas
   mojadas o de metal. Cada salto gasta carga y hace daño; la cadena tiene un presupuesto
   (máx. ~6 saltos), así que no hay bucles infinitos.
3. **Gravedad.** Un campo `grav` mueve todo según su masa: lo pesado se arrastra más, el vapor casi
   no; lo que vuela cae hacia un pozo. Gravedad + carga = imán para lo metálico (sale solo, sin
   tabla).
4. **Impulso.** Lo que choca hace daño según masa × velocidad. El ariete, la caída desde altura
   (el Ground Slam de Control) y la chatarra lanzada salen de esta regla, sin números aparte.

Con eso, los resultados de la tabla de C+ salen solos: remolino (agua + pozo), picadora (esquirlas
pesadas orbitando un pozo y chocando), nube combustible, tormenta (vapor con carga), choque
térmico. Ninguno se escribe a mano; el editor los describe por sus reglas ("conduce a 6 saltos",
"pesado: el pozo lo arrastra").

Lo sorprendente sigue existiendo, pero es **segundo orden lógico**, no una tabla secreta: el arco
sobre un charco donde está la Novia la descarga entera porque ella *es* agua; el pozo baja a la raya
porque vuela y es liviana; el frío sobre una manada mojada por el Sereno la congela entera. Se
puede deducir después de verlo una vez, y eso es lo que hace que descubrir se sienta bien.

## Lo que entra de Control

- **Chatarra como munición (Launch).** Cada máquina que cae deja restos pesados y oscuros en el
  piso unos 8 s. Es una sustancia más (`mass` alta, conductora, metal). Una rutina puede partir de
  chatarra en vez de agua. Es el bucle survivor ideal: más muertes = más munición. Brasa la pone al
  rojo con la llama. Tiene que verse distinta de las piezas de XP (esas son chispas chicas que
  vuelan hacia ti; esto es peso muerto en el suelo).
- **Orbitar (Launch/Shield).** La materia gira alrededor del operador y sale disparada en el THEN.
  Con `raise` es un escudo que absorbe un golpe. Necesita la etapa 0.
- **Shift.** `grav` + `raise` = pendiente: una franja donde todo se desliza hacia un lado. Con
  hielo, tobogán.
- **Empujar hacia peligros.** Gratis con las reglas: un repulsor que mete máquinas en fuego o
  escarcha dispara la regla de calor sobre ellas.
- **Seize.** El contrasello solo prende en un **sello expuesto** (`exposure` > 1, ya existe y se
  replica): hay que hacer coincidir la rutina con la apertura de la máquina.
- **No:** apuntar en vivo, levitar, esquivar. Chocan con "programar en vez de apuntar" y con la red
  host-autoritativa. Tampoco nombres ni estética de Remedy.

## Encaje en el survivor

- **El editor sigue lineal** (WHEN → cadena → THEN). Cada nodo muestra bajo él las propiedades
  resultantes como íconos de pixel (temperatura, mojado, carga, gravedad, masa) y una línea de
  "con lo que toque: …" generada desde las reglas. Así se ve qué hace una combinación sin texto
  escrito a mano por caso.
- **Un lenguaje visual por propiedad, igual en materia y en máquinas:** borde naranja o cian según
  temperatura, chispa de 1 px si tiene carga, anillos hacia dentro o hacia fuera según gravedad,
  glitch cian en el sello si tiene código. Si algo chisporrotea, conduce: se lee igual en un charco
  que en un quiltro.
- **Subir de nivel** ofrece piezas y mejoras de propiedad ("más voltaje": +1 salto; "más masa": la
  chatarra pega más). Escala como un survivor sin multiplicar contenido.
- **Bitácora de fenómenos.** Cuando las reglas producen algo notable (cadena de 5+ saltos, manada
  congelada, máquina aplastada por chatarra), el juego lo reconoce, le da nombre y lo anota en la
  bitácora del grupo. El nombre llega *después* de que pasó; no es una receta que se busca.
- **Cooperativo.** Las propiedades no tienen dueño: el agua del Sereno moja, el arco de otro la
  usa, la llama de Brasa la evapora. El daño de materia nunca afecta a jugadores. La muerte se
  acredita a quien hizo la última acción.
- **Legibilidad en el caos:** tope de reacciones por tick, fusión de registros al reaccionar (el
  snapshot se achica), tope de materia por jugador.

## Etapas

**Etapa 0 — base técnica (sin cambios de juego visibles)**

- Interpolar en el cliente la posición de la materia (`construct_view.apply` hoy la asigna directo
  a 10 Hz; las máquinas ya interpolan en `_client_motion`).
- Pasar los registros a propiedades: `temp`, `wet`, `charge`, `grav`, `mass` (y `code` reservado).
  `well`/`repel`/`scald`/`hard` se derivan de ellas; la fase del agua sale de `temp`. `recipe.gd`
  simula sobre propiedades y produce los mismos resultados que hoy.
- Etiquetas en las máquinas (material, masa, vuela) y propiedades replicadas en el snapshot.
- Los tests actuales (`validate`, `specialists`, `validate_matter`, `network`) tienen que pasar
  igual: es un refactor.

**Etapa 1 — las reglas y el arco**

- Las 4 reglas (calor, conducción, gravedad por masa, impulso) en `spellwork.tick`, sobre materia y
  máquinas, con los topes anti-bucle. Los comportamientos que hoy están a mano (`soak`, `burn`,
  `pulled`, el vapor que escalda a la Novia, el hielo que derrite la animita) pasan a ser casos de
  las reglas donde se pueda, sin perder lo que ya prueban `specialists`.
- `heat`/`freeze` pasan a ser fuego/frío (energías que mueven `temp`); se agrega **`arc`** (carga).
- El editor muestra las propiedades bajo cada nodo y la línea "con lo que toque" generada desde las
  reglas.
- Checks nuevos por regla y una partida `soak` para medir balance y `snapshot_bytes`.

**Etapa 2 — Control:** chatarra, orbitar, pendiente, impulso por altura en `drop`.

**Etapa 3 — código:** señuelo; después contrasello limitado a sellos expuestos.

**Etapa 4 — bitácora de fenómenos** y su panel en el editor.
