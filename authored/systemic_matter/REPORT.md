# Materia programable — auditoría y corte vertical

## Arquitectura existente reutilizada

El bloque `scenes/characters/programming_block.gd` compara cadenas exactas (`fire()` y `heal()`) en un Timer. No es todavía un intérprete ni un grafo de eventos. Damage y Support implementan `use_ability`; conservé ambos y su interfaz.

Los jugadores conservan autoridad de movimiento, sincronizada mediante InputSynchronizer y RPCs de posición. El servidor resuelve daño y curación. El proyectil existente hace un raycast y llama `take_damage` en el servidor; el nuevo constructo ofrece ese mismo método. El centinela utiliza ese método y RPCs propios para salud y reinicio. Sólo añadí su pertenencia al grupo `matter_damageable`, un adaptador de selección para daño de área.

Los centinelas son StaticBody3D: no existe locomoción enemiga que inmovilizar. Tampoco encontré un sistema general de estados de combate. Por eso elegí agua/hielo + recubrimiento + impacto/impulso, y diferí raíces. No añadí un enemigo ni un sistema de oleadas.

DioramaArena sigue controlando cámara y encuadre; Sector 08 conserva luces, materiales, profundidad de campo, pixelación y controlador de onda/apagón/recuperación. Las modificaciones artísticas que ya estaban sin commit antes de esta petición se conservaron. Esta iteración no las rediseña. La colisión existente usa principalmente la capa predeterminada 1; los sólidos nuevos usan esa misma capa para que los proyectiles y personajes existentes los reconozcan.

GroundSurfaceState sigue siendo presentación local de humedad/grietas, no una fuente autoritativa de recursos. No convertí los charcos decorativos en reservas físicas ni hice manipulables las 2990 mallas del escenario.

## Modelo sistémico propuesto e implementado

`WorldMatter`, un Node3D de la escena principal, mantiene un diccionario acotado de registros. Cada registro tiene ID estable, propietario, material, forma, estados, propiedades añadidas, recubrimientos, posición, tamaño, orientación, integridad, velocidad y duración.

- Materiales: catálogo pequeño de datos, propiedades y transiciones explícitas.
- Estados: etiquetas, actualmente mojado/congelado.
- Propiedades: capacidades consultables como reshapeable, breakable, brittle, coatable y movable. Los fragmentos adquieren movilidad por su transformación de forma.
- Recubrimientos: diccionario dentro del registro, con propietario. El recubrimiento no sustituye al huésped.
- Operaciones: lista permitida, validación común `preview`, comprobación autoritativa y handlers pequeños por operación.
- Eventos: señales con tipo, ID y posición. Incluyen created, reshaped, transformed, coated, hit, broken, impulsed, commanded, detonated, collided, expired y removed. No hay un motor de macros ejecutándose en cada cliente.
- Visuales: `construct_view.gd` proyecta el registro a un cuerpo estático, una malla, una colisión y un MultiMesh de ocho fragmentos. No decide transformaciones ni daño.

Es una base específica para un juego, no un ECS, motor químico o simulador de partículas. Los registros son diccionarios para mantener el corte pequeño; si el vocabulario crece, conviene tiparlos antes de añadir docenas de claves.

## Implementación exacta

1. `create`: acepta un material con fuente habilitada. En este corte sólo agua; crea un volumen lógico rectangular de 4 × 0,12 × 3 m sobre suelo plano, dentro del alcance.
2. `raise`: requiere materia moldeable y forma superficial. Cambia a 4 × 1,8 × 0,2 m conservando el volumen aproximado. La dirección define orientación; el tamaño es fijo por ahora.
3. `freeze`: aplica una transición del catálogo. Conserva ID, geometría y recubrimientos. Comprueba espacio libre antes de hacer sólida la forma.
4. `impact`: aplica 25 puntos de daño a materia rompible. Un proyectil normal también aplica su daño habitual mediante take_damage.
5. Rotura: la materia frágil sin integridad pasa a un grupo de fragmentos con el mismo ID. Pierde la colisión de pared y adquiere movilidad.
6. `push`: añade un impulso horizontal limitado a materia móvil. No es aún un campo de viento persistente.
7. `coat`: añade nanites a superficies compatibles. Se puede aplicar antes o después de congelar, y persiste al romper.
8. `command`: despacha una orden permitida del recubrimiento; ahora sólo detonate. Consume el recubrimiento antes de aplicar efectos. Tres zonas de explosión siguen el eje y extensión del objeto, compartiendo la energía total. No consulta si el huésped es agua, hielo o fragmentos.
9. `remove`: retira un constructo propio. También expiran y se retiran al desconectar su propietario.

Los fragmentos constituyen un solo grupo de daño: un raycast central barrido detecta el primer impacto, daña y consume el grupo. Es una aproximación deliberada: las ocho piezas no tienen impactos, rebotes ni gravedad individuales.

## Prueba emergente

La secuencia capturada en Sector 08 es:

`create(water) → raise → freeze → coat(nanites) → impact → push → command(detonate)`.

No hay un handler para esa secuencia. El paso siguiente consulta el resultado actual del anterior. También se prueba `create(water) → coat → detonate`, sin congelación, y recubrir antes de elevar/congelar/romper. El objeto y su recubrimiento conservan su identidad hasta destrucción o consumo.

Las pruebas verifican daño de fragmentos contra un actor mínimo, impacto del proyectil existente contra hielo y daño de detonación contra un centinela real en la captura integrada. No se demuestra inmovilización, porque no hay enemigos móviles adecuados en esta rama.

## Transiciones específicas y aproximaciones

- `freeze: water → ice`: transición de material explícita y legítima.
- El catálogo de hielo aporta solidez, fragilidad e integridad; el de agua aporta capacidad de cambiar de forma.
- Raise usa dos formas controladas, superficial y pared, con dimensiones fijas. No calcula una superficie de fluido.
- La regla de rotura es por propiedad brittle, no por nombre de material. La fragmentación es una forma agregada compartida.
- Nanites tiene una orden explícita detonate, radio y energía constantes. La orden es independiente del huésped.
- Agua/hielo tienen un tratamiento visual particular. Eso no decide resultados de combinaciones.

No hay funciones por combo ni condiciones de tres materiales. Tampoco está implementada una nube libre de nanites: el corte prueba su comportamiento como recubrimiento.

## Integración con programación

API disponible: `preview(peer, operation, target_id, args)`, `submit(operation, target_id, args)` y, sólo en servidor, `execute(peer, operation, target_id, args)`. Las respuestas contienen éxito/causa e ID.

Un futuro nodo Create puede almacenar el ID devuelto; Freeze, Coat y Push reciben ese ID. El bloque actual puede enviar instrucciones estructuradas a submit sin ejecutar GDScript escrito por usuarios. El resultado remoto es asíncrono: el futuro programador debe esperar operation_result antes de consumir el ID.

Los eventos pueden alimentar un planificador del servidor: por ejemplo, al recibir broken, encolar una orden de impulso para el tick siguiente. No ejecutar macros indistintamente en clientes y servidor. El corte rechaza ejecución reentrante; un planificador futuro necesita límite de instrucciones, profundidad y eventos por tick. No reescribí el editor ni añadí parsing, variables o bucles.

## Multiplayer

Autoridad fija del servidor. Los RPCs de petición toman el propietario del emisor real, validan alcance, capacidades, espacio libre y límites; no reciben registros completos confiables del cliente. Se admite impacto sobre constructos ajenos como acción ofensiva; el resto requiere propiedad.

Límites: 8 constructos por jugador, 32 globales, alcance 18 m, peticiones remotas separadas al menos 120 ms. Sólo el servidor simula integridad, movimiento, tiempo de vida y daño.

Se replican instantáneas completas fiables con revisión monotónica, inmediatamente al ejecutar operaciones y hasta 10 Hz en movimiento. Un cliente que entra pide el estado actual; una desconexión limpia lo que poseía. Las colisiones se proyectan también en clientes, compatibles con la autoridad de movimiento existente.

Prueba ENet de dos procesos locales: estado inicial, rechazo de propietario, creación, congelación, recubrimiento, fragmentación, movimiento replicado y limpieza al desconectar. El fixture desactiva los callbacks del lobby que cambian de escena, para probar el transporte aisladamente. No equivale a una sesión completa de lobby de cuatro jugadores ni a una prueba con latencia/pérdida reales.

Las instantáneas fiables y sin interpolación son una solución de prototipo. Antes de escalar: actualizaciones incrementales y movimiento interpolado; separar estado fiable de movimiento no fiable si las mediciones lo justifican. El sistema hereda las limitaciones del movimiento con autoridad del jugador; no pretende resolver anticheat.

## Rendimiento y límites

Se almacenan 32 objetos lógicos como máximo. Un grupo de fragmentos dibuja ocho instancias mediante un MultiMesh, sin cuerpos por fragmento: hasta 256 fragmentos visuales y 128 nodos de constructos. La geometría/material sólo se actualiza al cambiar su descripción, y las posiciones durante movimiento.

Los informes JSON registran el coste medido de 32 grupos en movimiento durante 120 ticks y el tamaño serializado de una instantánea llena. Es una medición headless de CPU en esta máquina, sin coste GPU. No debe compararse con el frame time completo ni presentarse como una garantía de 60 FPS.

Una instantánea de 32 registros ocupa aproximadamente 13,3 kB antes de cabeceras/transporte: a 10 Hz ronda 133 kB/s por destinatario, más operaciones/eventos. Adecuado para un prototipo local acotado, excesivo si se multiplica sin revisar. No hay índices espaciales: el daño de área recorre constructos acotados y actores del grupo. Cuando crezca el número de enemigos, deberá medirse y migrarse a consultas espaciales.

La explosión reutiliza el efecto transitorio existente del combate. No genera entidades de gameplay por chispa. Los efectos heredados se liberan mediante sus tweens.

## UX y cómo probar

Abrir `tests/matter/playground.tscn` en Godot y ejecutar esa escena (F6). Es Sector 08 integrado con una herramienta de desarrollo; el menú normal y el bloque de programación no cambian.

- 1 crear agua; 2 elevar; 3 congelar; 4 impacto.
- 5 impulso; 6 recubrir; 7 ordenar detonación; 8 retirar.
- Tab selecciona otro constructo. El cursor elige lugar/dirección y el clic confirma.
- La forma fantasma muestra el resultado inmediato; el color y texto indican compatibilidad. El impulso muestra una flecha. No hay lista de recetas.

La previsualización es inicial. Para producción faltan selección directa accesible, anclas A/B editables, volumen/energía y costes visibles, respuesta de rechazo tras cambios de red y distinción entre objetivo fuera de alcance y ocluido. Congelar necesita que el volumen esté libre; el servidor vuelve a verificarlo aunque la previsualización local indicara compatibilidad.

## Lenguaje visual

Agua de baja emisión con ondulación y respuesta especular; hielo pálido con variación de superficie. Los nanites modifican la misma superficie con pequeñas islas metálicas y pulsos tenues. Fragmentos conservan material y recubrimiento. La detonación usa un destello breve cálido del sistema existente.

No se recoloreó la arena ni se añadieron zonas que revelen combos. Las formas son deliberadamente esquemáticas, no assets finales. El agua levantada es un volumen rectangular y los nanites todavía se leen como un patrón bastante geométrico. La secuencia se colocó dentro de la banda de gameplay legible; no cambié el DoF para favorecer la demostración.

## Recomendación de alcance

El concepto completo excede una iteración razonable de un proyecto universitario. La versión viable es un catálogo pequeño con 6–8 operaciones, constructos agregados y pocos ejes de estado.

Prioridad para las siguientes familias:

1. Agua/hielo: reutiliza cambio de fase, moldeado, rotura y movimiento.
2. Nanites/recubrimientos: añade comportamientos a geometrías existentes y conserva historia.
3. Concreto/escombros: reutiliza integridad, forma, rotura e impulso; requiere un adaptador de sustrato antes de levantar pavimento real.
4. Biomasa/raíces: añade anclaje/captura sólo cuando exista locomoción enemiga y un contrato de estados compartido.
5. Electricidad: después, sobre una red acotada de objetos conductores; no una simulación de cada charco/píxel.

Push/impact son operaciones transversales, no otra familia elemental. Pospondría magnetismo, gases y calor distribuido. Primero conviene probar si jugadores inventan usos distintos con estos mismos pocos verbos.

## Límites explícitos antes de ampliar

No hay recursos/energía, enlace con agua ambiental, terreno deformable, raíces, hielo que se derrite, fuego, macros programables, navegación dinámica ni física por fragmento. Las explosiones actualmente atraviesan cobertura y no dañan jugadores; afectan constructos rompibles y actores que implementan take_damage en el grupo correspondiente. La decisión sobre oclusión, fuego amigo y contrajuego debe resolverse antes de balancear.

Las regiones grandes y operaciones sobre geometría importada necesitarán adaptadores por objeto o módulos; no conviene inferir capacidades a partir del nombre de cada malla. La base actual prueba composición de constructos nuevos y compatibilidad con el combate, no que toda la ciudad sea ya programable.

## Resultados de validación y evidencia

- 46 comprobaciones sistémicas aprobadas: compatibilidad, identidad, recubrimientos, eventos, daño, colisiones, expiración y límites. Incluye 40 ciclos de crear/congelar/eliminar sin nodos de constructos huérfanos. [Resultado](proof/matter_validation.json).
- ENet con dos procesos: conexión tardía, autoridad, rechazo de propiedad, transformaciones, movimiento y desconexión aprobados. [Servidor](proof/network_host.json) · [Cliente](proof/network_client.json).
- 30 comprobaciones de la arena integrada aprobadas. [Resultado](proof/arena_integration.json).
- Onda, apagón y recuperación de Sector 08 aprobados. [Resultado](proof/diorama_validation.json).
- 32 grupos móviles: media de 0,408 ms por actualización de lógica/nodos durante 120 ticks, máximo observado de 1,04 ms en la ejecución de pruebas. Instantánea llena: 13.308 bytes. Medición headless; no incluye GPU ni valida una partida de cuatro jugadores.
- Daño sobre centinela real verificado: salud 29,998 → 22,217. [Resultado](proof/sentry_damage.json).
- La escena de herramientas inicia sin errores de script. Godot mantiene advertencias de liberación de Shader/Texture RID al cerrar, también presentes en el escenario previo; no constituyen una validación de ausencia de fugas GPU.

### Capturas de la secuencia real

[Agua](proof/01_water.png) → [elevada](proof/02_raised.png) → [hielo](proof/03_ice.png) → [recubrimiento](proof/04_coated.png) → [fragmentos](proof/05_fragments.png) → [impulso](proof/06_impulse.png) → [detonación](proof/07_detonation.png).

[Registro de eventos de la captura](proof/events.json).
