# Reactive · materia, centinela, interfaz y operadores · 2 octubre 2026

## Decisión central

La materia ya reaccionaba a eventos. Esta pasada la vuelve **un programa que se lee en el patio**: cada constructo cambia de fase sin perder su identidad, una reacción puede llamar a otra a través de un conducto visible y el jugador ve la forma final antes de desplegarla. Nada de esto añade texto evaluable ni un lenguaje nuevo: todo son datos que el anfitrión vuelve a validar.

## Sistemas

**Ciclo de fases.** Hielo ← agua → vapor, en las dos direcciones (`materials.gd`, `TRANSITIONS`).

- *Calentar* lleva el hielo a agua y el agua a vapor. Está disponible como paso de rutina, como reacción y como golpe manual.
- Al derretirse, los fragmentos de hielo se juntan en un charco.
- El vapor se condensa solo a los 7 s, en el mismo sitio, y vuelve a ser el charco que era. Esa condensación emite `transformed`, así que la reacción *al cambiar de fase* también se dispara cuando el vapor se condensa.
- El constructo conserva identificador, dueño, recubrimiento, conducto y reacción a través de todos los cambios.

**El vapor como pantalla.**

- **Visión:** no es sólido. Su núcleo (el 80 % interior del elipsoide) corta la línea de visión. Los centinelas no adquieren objetivos a través de él y su disparo se dispersa dentro de la nube (`sight_obstruction`). Funciona igual en clientes: el rayo de aviso termina donde la nube lo tapa.
- **Empuje:** se puede impulsar. Una nube empujada se acumula contra lo que encuentra, en vez de romperse.
- **Nanites:** detonar los nanites suspendidos en una nube cubre una esfera 1,6 veces mayor con la misma energía.
- **Disparo de La Fundidora:** sus disparos atraviesan el agua en pie y la hierven al pasar (`heat_along`). Disparar a tu propia cortina de agua levanta una cortina de humo.

**Conductos.** `L` conecta la referencia seleccionada con otra propia, a menos de 14 m.

- **El pulso:** cuando la reacción de A se dispara, A envía un pulso que recorre el conducto a 9 m/s. Al llegar, B emite `pulsed` y se dispara su reacción *al recibir pulso*.
- **Si la acción falla:** el pulso sale igual. El evento ocurrió, y una cadena no debe depender de que cada eslabón sea compatible.
- **Al borrar un constructo:** desaparecen los conductos que llegaban a él.
- **Sin bucles:** las reacciones se consumen al dispararse, así que una cadena circular no se repite.

**Rutinas encadenadas y tres ranuras.**

- **Ranuras:** hay tres rutinas, `TAB` cambia entre ellas y se guardan entre sesiones. La rutina antigua guardada pasa a la ranura 1.
- **Encadenar:** una rutina marcada así abre al terminar un conducto desde la construcción que produjo la rutina anterior del mismo jugador.
- **Defaults:** *Barrera* (elevar, congelar, recubrir; rotura → impulso), *Mina · relé* (recubrir; pulso → detonar, encadenada) y *Nube minada · relé* (recubrir, calentar; pulso → detonar, encadenada). Juntas forman una trampa: el enemigo rompe la barrera, los fragmentos salen disparados y el pulso detona la mina y la nube que vienen detrás.

**Lectura previa.** `routine_model.gd` simula la rutina sobre un registro de prueba antes de ejecutarla:

- le da un nombre (*Barrera*, *Velo*, *Mina*, *Placa*…);
- la describe en una frase en el orden en que van a pasar las cosas;
- marca el paso en que se detendrá y por qué;
- avisa cuando la reacción no podrá hacer nada (por ejemplo, impulsar agua que nunca se rompe).

Es sólo consejo: el anfitrión sigue validando contra el mundo real.

## El centinela

El anillo fijo en el suelo desaparece. El aviso ahora es un **rayo de seguimiento** (`sentry_telegraph.gd`):

- **Rastreo:** durante 0,75 s busca al jugador. Empieza suelto, desviado hacia un lado, y se va ajustando a medida que sube la carga. La figura del centinela gira con él.
- **Corte:** el rayo termina en lo primero que encontraría un disparo real (escenario, cobertura, jugador o vapor), así que el jugador ve en el propio rayo si su cobertura lo protege. Un punto de luz rojo ilumina esa superficie.
- **Fijación:** a los 3,25 s el anfitrión fija el punto. El rayo deja de moverse, se vuelve sólido y un anillo se cierra sobre el punto durante los 0,35 s que quedan. Esa línea congelada es la ventana para esquivar.
- **Disparo:** a los 3,6 s dispara contra el punto fijado, con la misma regla de cobertura de antes y además el vapor.
- **Red:** el estado se replica con cuatro RPC (`begin_track`, `commit`, `cancel_track`, `finish_shot`). Cada cliente dibuja el rayo localmente a partir de posiciones ya replicadas.

## Correcciones tras la primera prueba

**Las teclas no respondían en el modo de prueba multijugador.** No era la consola. `lobby_test.tscn` tenía su temporizador de inicio en *autostart*: el anfitrión entraba a la partida un segundo después de abrirse, antes de que se conectara nadie, y la instancia que llegaba después se quedaba atascada en la pantalla de prueba, sin cuerpo (se reproduce también en el `HEAD` anterior). Ahora:

- el temporizador espera a que se conecten todos los asientos de prueba, o 4 s desde la última conexión, y un asiento solo arranca de inmediato;
- `main_scene.gd` ya no crea a los jugadores a los 0,2 s: cada cliente avisa que cargó la escena, repitiendo el aviso hasta tener cuerpo, y el anfitrión espera a todos los que están conectados (con 12 s de margen) antes de crearlos. Un aviso de creación enviado a una escena que todavía carga se perdía para siempre;
- los asientos de prueba sin instancia ya no generan un jugador con id 0;
- el menú ya no cambia de escena dentro de su propio `_ready`.

Comprobado con dos procesos: el cliente tiene cuerpo, `E` abre el editor, `Q` despliega y se mueve.

**El disparo del centinela.** El hilo rojo de 0,16 s pasa a ser una descarga (`sentry_discharge.gd`):

- **Carga:** durante la fijación, chispas convergen en el cañón.
- **Disparo:** un frente al rojo blanco recorre la línea fijada en 0,085 s y deja un canal ionizado que crepita con un arco eléctrico. Va acompañado de un fogonazo que ilumina al propio centinela y de humo en la boca.
- **Impacto:** cambia según lo que haya golpeado, y el anfitrión lo decide junto con el daño.
  - *Jugador:* chispas, destello y una mancha roja. El jugador sale despedido, pierde el control un instante, su figura se pone roja y su cámara tiembla.
  - *Cobertura:* metal fundido salpicando la superficie.
  - *Vapor:* un resplandor apagado que se dispersa dentro de la nube.
  - *Escenario:* chispas, humo y una quemadura en el suelo que se desvanece a los 6 s.

## La materia, visualmente

- **Charco:** contorno orgánico vivo, un menisco y anillos de contención que avanzan hacia el centro, como si el borde estuviera siendo retenido. Refracta lo que hay debajo.
- **Cortina de agua:** el agua **fluye hacia arriba**, contra la gravedad: es la señal más clara de que algo la sostiene. Tiene una cresta que rueda, extremos que se desploman, hilos de luz que suben por dentro y espuma en la base y en la cresta. Al elevarse, sube desde el charco que era.
- **Hielo:** ya no es una losa. Es una fila de columnas cristalinas crecidas desde el suelo (malla procedural sembrada por id, idéntica en todos los peers) sobre un zócalo compacto, con nervaduras pálidas, un núcleo oscuro con profundidad aparente, escarcha en la base y una red de fracturas que se abre según cae la integridad. Al congelarse, el hielo crece desde abajo con un frente de luz mientras el agua se desvanece.
- **Vapor:** partículas iluminadas con turbulencia más un `FogVolume` que recibe la luz de la escena. Se aclara durante el último segundo antes de condensarse. Con nanites, la nube se tiñe de latón.
- **Nanites:** celdas hexagonales de latón que se agrupan en canales y avanzan. Al recubrir, el enjambre sube desde la base; algunas celdas transmiten destellos que se desplazan.
- **Reacción armada:** una costura de luz recorre la base, más un glifo (`ROTURA ▸ IMPULSO`) sobre el constructo.
- **Conductos:** un filamento de latón en arco con paquetes de luz que avanzan hacia el receptor, para que la dirección del programa se lea incluso en reposo. El extremo brilla más si el receptor espera un pulso. El pulso es una cuenta de luz que recorre el arco.
- **Eventos:** la rotura lanza esquirlas reales del mismo material; el impacto, astillas y un destello; la detonación, una onda expansiva, chispas, humo y un destello cálido. Congelar, hervir y condensar tienen cada uno su efecto. Todos se generan desde el flujo de eventos replicado y se cuelgan junto al mundo, nunca dentro de él.

## Interfaz en partida

Toda la interfaz está dibujada, no hecha con controles por defecto. Usa un solo lenguaje con la señalética del patio: placas ennegrecidas con esquinas cortadas, bordes de latón, texto en sodio y la tipografía condensada DIN (DIN Condensed en macOS, Bahnschrift en Windows).

- **HUD:** operador e integridad en doce celdas; la rutina cargada con sus tres ranuras y un anillo de carga de 6 s; la referencia seleccionada con su integridad, recubrimiento, conducto y reacción en glifos; un aviso que se desvanece y se pone rojo cuando algo falla.
- **Tira inferior:** la rutina cargada como una línea de glifos, legible en pleno combate sin abrir nada, con el paso que fallará marcado.
- **Editor (`E`):** el programa dispuesto como la tubería que es (origen → cuatro pasos ‖ cuando → entonces). Cada tarjeta cambia con clic, clic derecho o rueda. Debajo, una frase describe lo que pasará y una línea en rojo indica dónde se detendrá. Botones para encadenar, armar la reacción en la selección y guardar. El combate continúa mientras está abierto.
- **Mientras se mantiene `Q`:** se proyecta un holograma de la forma final (columnas de hielo, cortina, nube o charco) donde va a quedar; una flecha de chevrones en el suelo muestra el vector guardado (más intensa si la reacción es impulsar); y un conducto de previsualización llega desde la construcción anterior si la rutina se encadena. Todo se pone rojo si el suelo no sirve o falta carga.
- **Selección:** corchetes de latón en el suelo alrededor de la referencia, en vez de una caja plana.

## Front-end

- **Fondo:** una imagen del propio patio renderizada desde la escena de partida (con una barrera, una mina conectada y una nube), que deriva muy lentamente bajo la lluvia, con el lado del menú hundido en sombra.
- **Menú:** el icono de Godot desaparece. Queda una marca *REACTIVE*, con *Unidad de contención · Sector 08* encima y debajo el lema *La materia obedece. Hasta que la rompen.*
- **Tema y textos:** todas las pantallas del lobby comparten tema (`lobby_theme.tres`) y están traducidas al español.
- **Sala:** muestra el retrato del operador elegido en lugar del icono, apagado hasta que el jugador marca *listo*.

## Los operadores

Los sprites de fantasía medieval se reemplazan por dos personas del Sector 08, dibujadas en pixel art cuadro a cuadro por `tools/operators/generate_operators.py`. Es reproducible: se ejecuta y se regeneran las tiras y los `SpriteFrames`.

**La Fundidora (daño).** Operaria de fundición de la unidad.

- **Ropa:** capa de goma de alta visibilidad con banda reflectante, delantal de cuero, botas con puntera.
- **Cabeza:** visor de soldar levantado sobre la frente, con la ranura ámbar todavía encendida, y una trenza atada con latón.
- **Equipo:** un tanque de latón con manómetro le sobresale por encima del hombro y alimenta por manguera una lanza térmica que lleva baja y adelantada.
- **Animación:** en reposo se le escapan brasas de la boquilla. Al disparar, la lanza se nivela y empuja (`Fire`), y todos los peers lo ven. Sus disparos hierven el agua: el personaje es la fuente de calor del ciclo de fases.

**El Sereno (apoyo).** El vigilante nocturno del patio.

- **Ropa:** sombrero de hule de ala ancha que gotea, una gota cada vez; poncho largo color petróleo con brillos de lluvia; barba gris; un solo lente cian.
- **Equipo:** un rollo de cable de conducto al hombro y un bastón con farol.
- **El farol:** su luz cian es la misma con la que cura. Se balancea al caminar y el bastón se apoya y se levanta a cada paso.

Ambos llevan el contorno selectivo y el borde de luz cian del patio. Mantienen la tubería existente: `AnimatedSprite3D`, filtro *nearest*, encaje al suelo de `configure_player_presentation`.

## Controles

| Tecla | Acción |
|---|---|
| `Q` mantener / soltar | proyectar / desplegar la rutina cargada |
| `TAB` / `⇧TAB` | cambiar de rutina |
| `E` | editar la rutina (guardar al cerrar) |
| `C` | seleccionar la referencia propia más cercana al cursor |
| `L` | conectar la selección con otra referencia propia bajo el cursor |
| `R` / `T` | golpear / detonar la selección |
| `1`–`4` | elevar / congelar / recubrir / impulsar a mano |
| `⌫` o `Supr` | retirar la selección |
| `P` | programa periódico `fire()` / `heal()` |
| `F` | disparar / curar, como antes |

## Validación

- **Regresión de materia:** 69 comprobaciones, antes 46. Cubre el ciclo de fases completo, que el vapor bloquee y no bloquee la visión donde corresponde, la condensación, el disparo que hierve agua, la detonación ampliada en nube, los conductos (rechazos, pulso, cadena que detona, corte al borrar) y el encadenado de rutinas. Pasa con pantalla y en modo headless.
- **Integración reactiva:** 13/13, adaptada a la nueva API del centinela.
- **Arena integrada:** pasa.
- **ENet con dos procesos:** pasa.
- **Validadores del sector 08:** pipeline, diorama, art, pixel, play y parallax pasan.
- **Capturas:** `capture.tscn` (materia, centinela, consola, operadores), `capture_menus.tscn` y `capture_backdrop.tscn` regeneran las imágenes de `proof/` y el fondo del menú.

## Límites

- **Sin playtesting:** no se hizo una sesión larga de juego ni se probó una partida en red con los nuevos conductos y el vapor entre dos máquinas; la prueba ENet cubre el flujo de materia, no el centinela nuevo.
- **Visibilidad del vapor:** el volumen de niebla aporta poco a la distancia de la cámara (60 m). La lectura del vapor la cargan las partículas.
- **Charco frente a gráficos:** la refracción depende de la textura de pantalla; con la presentación pixelada en modos SOFT o MEDIUM no se revisó.
- **Selección parcial:** los corchetes de selección pueden quedar tapados en parte por la propia construcción, por la profundidad.
- **Rutina en un solo lugar:** las rutinas se guardan localmente. El anfitrión no las conoce hasta que se despliegan.
- **Animación de apoyo:** El Sereno no tiene animación propia de curación; la curación sigue mostrándose con el enlace de energía existente.

## Siguiente paso recomendado

Probar la trampa de tres ranuras (barrera → mina → nube) contra un enemigo móvil, y medir si los jugadores construyen cadenas o sólo coberturas. Si las construyen, el siguiente sistema natural es un conducto con condición (un filtro sobre el pulso) antes que otro material.
