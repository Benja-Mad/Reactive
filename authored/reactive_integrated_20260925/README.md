# Reactive · iteración integrada, 25 septiembre 2026

## Decisión central

Conectar defensa, daño y programación reactiva usando la materia ya existente. No añadir otra familia elemental todavía. La diferencia jugable es que una cobertura preparada puede convertirse automáticamente en un contraataque cuando el enemigo la rompe.

## Cambios de esta iteración

- `WorldMatter/Programs`: ejecutor autoritativo de rutinas estructuradas, con hasta cuatro pasos después de crear agua y una reacción de un solo uso. Sin evaluación de texto ni lenguaje nuevo.
- Disparadores: rotura, impacto y transformación. Respuestas disponibles: impulso, orden de detonación y congelación. Su compatibilidad se vuelve a validar al ejecutarse; no son recetas garantizadas.
- Cada despliegue crea una referencia estable. Los pasos se resuelven separados por 0,18 s; si falla uno, la materia anterior permanece y se informa la causa. Al terminar se arma la reacción. El panel también permite vincularla a una referencia existente.
- Cada jugador puede ejecutar una rutina a la vez, con seis segundos entre despliegues. Se mantienen los límites de 8 constructos propios y 32 globales. Cola reactiva de 32 entradas, disparos de un solo uso consumidos antes de encolarse, resolución fuera de la emisión del evento.
- Los centinelas adquieren objetivos detrás de materia y su disparo daña la cobertura que intercepta el rayo. Tres impactos de 8 rompen un muro de 20 de integridad. La estructura protege al jugador durante el impacto que la rompe.
- Un tercer centinela presiona el patio sur. No se añadió otro sistema de enemigos ni oleadas.
- Las explosiones ahora consultan oclusión contra colisiones del escenario. Mantienen ausencia de daño a jugadores, una decisión de prototipo pendiente de balance.

## Uso en la partida normal

Entrar desde el menú normal, elegir Solo o usar el lobby existente. La consola de materia está en `main_scene.tscn`; ya no requiere la escena de desarrollo.

- **E**: preparar y guardar una rutina. El combate continúa. Seleccionar hasta cuatro operaciones y un evento/respuesta. Se guarda localmente una rutina entre sesiones.
- **Q mantenida**: previsualizar la forma final aproximada; **soltar Q**: crear agua y ejecutar los pasos preparados en ese punto. La dirección queda guardada desde el jugador hacia el cursor. La pared se eleva transversalmente a ella.
- **C**: seleccionar la materia propia próxima al cursor; una marca de suelo identifica la referencia.
- **1 / 2 / 3 / 4**: elevar / congelar / recubrir / impulsar sobre la referencia.
- **R**: impacto manual. **T**: detonar el recubrimiento. **Supr**: retirar materia propia.
- En el panel, “Vincular reacción…” arma el objeto seleccionado usando la dirección elegida al abrirlo.
- El checkbox de disparo/curación periódica controla el `fire()` / `heal()` del bloque existente. **F**, movimiento y salto permanecen. El editor textual viejo queda oculto en la partida normal, conservado en la herramienta de desarrollo.

No hay ejecución arbitraria de código. Las opciones del panel producen datos que el servidor vuelve a comprobar. La previsualización sólo valida el suelo de creación: no promete que toda la secuencia futura vaya a ser compatible ni que al congelar siga libre el volumen.

## Consecuencias combinables

1. Crear → elevar → congelar; armar rotura → impulso. La cobertura absorbe disparos y devuelve fragmentos cuando cede, usando el vector guardado.
2. El mismo objeto puede recubrirse. Los nanites conservan identidad al fragmentarse; la orden de detonación sigue disponible mientras exista el grupo.
3. Cambiar la respuesta a impacto → detonación convierte un recubrimiento compatible en una reacción al primer golpe, sin una función de “muro explosivo”.
4. Una superficie de agua recubierta puede recibir transformación → detonación y luego congelarse manualmente. El disparador pertenece al objeto, no a un tipo de hechizo.
5. Impacto e impulso siguen siendo operaciones manuales: no hay que esperar al enemigo para convertir defensa en ataque.

La primera secuencia fue verificada contra un centinela real. Las demás describen composición permitida por las reglas; no fueron objeto de una batería exhaustiva de pruebas de juego.

## Escenario y dirección artística

Se reutiliza la extensión previa de 68 × 54 m. Esta pasada añade contenido y rutas, no más metros de pavimento. `containment_court.gd` coloca tres pórticos abiertos, tres particiones escalonadas, dos islas de cerámica seca y pilas de servicio. Bases/particiones tienen colisión; las coronas quedan por encima del paso. Las piezas y posiciones son deliberadas, sin generación aleatoria.

Lenguaje compartido: costillas pálidas, juntas oscuras, placas comprimidas y abrazaderas de latón. Los pórticos marcan rutas alternativas sin indicar una receta. El hielo tiene borde irregular y nervaduras; el recubrimiento sigue bandas y canales en vez de una cuadrícula aleatoria. El daño oscurece fracturas y una costura discreta indica una reacción armada.

Se redujeron bloom, densidad de niebla, lluvia y reflejos añadidos. Se mantuvieron cámara P30, seguimiento, sprites y composición diorama. El sur tiene siluetas y contrastes materiales legibles incluso con glow, niebla volumétrica y reflejos añadidos apagados. La imagen comparativa no elimina toda la iluminación ni todo el reflejo físico.

Las piezas nuevas siguen siendo geometría modular sencilla; no se presentan como assets finales de artista. La referencia HD-2D se mantiene como relación entre sprite, volumen y profundidad. El fondo conserva bastante cian y ámbar del escenario aprobado: no se ha resuelto toda la identidad visual con una sola pasada.

## Validación y límites

Resultados y capturas finales en `proof/`:

- Prueba funcional integrada: defensa bloquea daño, enemigo rompe cobertura, evento impulsa, recubrimiento persiste, fragmentos dañan al atacante y se limpian.
- Regresión existente de materia: 46 comprobaciones aprobadas.
- Regresión de arena con renderizado: 30 comprobaciones aprobadas, incluidos movimiento, cámara, suelo, límites y colisión. El intento headless fue descartado: la prueba requiere datos de MultiMesh del renderer y espera una captura.
- ENet, dos procesos locales: rutina enviada por cliente, autoridad/propiedad, conexión tardía, transformación, reacción automática, movimiento y limpieza al desconectar aprobados. No se repitió una sesión de cuatro jugadores ni se simuló latencia.
- Revisión de capturas integrada y sin efectos ópticos principales; apertura del panel verificada en escena. No se realizó una sesión larga de playtesting ni una auditoría completa de navegación del nuevo módulo.
- No se repitieron pruebas de onda/apagón/recuperación, cuyos controladores no cambian. Tampoco se hizo un benchmark gráfico; la suite existente de materia incluye su medición CPU, que no representa el coste visual del nuevo módulo.

Se mantienen instantáneas completas fiables y movimiento sin interpolación. Las reacciones quedan dentro del registro replicado, el servidor conserva las colas de ejecución y los clientes reciben resultados. Los eventos de un objeto destruido ya no tienen un huésped sobre el que actuar. Una reacción fuera del alcance de 18 m puede fallar: conserva la validación común del prototipo.

Aún faltan enemigos móviles, progresión y un objetivo de partida con derrota/victoria; los centinelas y la reaparición siguen siendo un ensayo de combate. Sólo se guarda una rutina local, no una biblioteca ni un editor de grafos. No hay recogida de agua ambiental, energía, física por fragmento ni deformación real. El impulso sigue usando un rayo para todo el grupo. El brillo de armado es indicativo, no una visualización completa del programa.

## Próxima iteración recomendada

Probar este vocabulario con un enemigo móvil sencillo y una partida corta con objetivo, presión y final claros. Medir si el jugador elige cuándo guardar, sacrificar o detonar una cobertura. Priorizar selección, lectura del vector guardado y feedback de fallos antes de añadir materiales. Después, concreto/escombros podría reutilizar daño y movimiento y vincular mejor la magia con el pavimento existente.
