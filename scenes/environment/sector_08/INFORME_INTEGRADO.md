# Sector 08 — validación artística del juego integrado

Baseline: `feat/sector08-arena`, commit `12a997f`. La integración y los cambios ambientales pedidos ya estaban versionados. Los JPG sin versionar de `claude_ground_pass_20260907/motion_frames` se conservaron sin incorporarlos a este commit. No se continuó el trabajo de personajes conceptuales.

## Motivación de luz

- **Cyan / Spine:** se conserva el anclaje `spine_node_2`, su dirección, fuente y volumen local. La maquinaria vertical permite inferir su origen cuando la parte superior sale del encuadre.
- **Cálido / compound_lamp:** la baseline ya incluye lente emisiva, carcasa y brazo fijado al gantry. Tres focos comparten el ancho de una sola apertura y la energía total; no se añadieron luces. La lente y el haz permanecen alineados en los extremos observados del seguimiento.
- **Farola del patio:** se conserva la farola existente, su cono de 31° con sombras y dispersión 1,35. No se aumentó niebla ni emisión.

Los FogVolumes y SpotLight3D son mundiales. La baseline combina dispersión volumétrica real con hebras aditivas sobre geometría 3D fija y test de profundidad; estas últimas no equivalen a un trazador volumétrico completo. Sus transformaciones permanecieron idénticas durante el movimiento. No se introdujeron overlays ni capas que sigan la pantalla.

## Cámara / parallax

Validación principal: `scenes/main_scene.tscn`, dos personajes reales creados por el spawner existente, etiquetas y bloque de programación visibles. La segunda plaza es una instancia real en el proceso de prueba, no una segunda conexión de red.

El vídeo usa exclusivamente acciones `move_up` y `move_right`; no teletransporta al jugador ni asigna offsets a la cámara. El jugador recorrió un desplazamiento neto de 22,14 m y activó 9 m de seguimiento lateral. P30 mantuvo exactamente su basis y FOV durante los 360 cuadros. Dead zone (0,10; 0,13), límite (9; 3) y velocidad 3,2 intactos. El test de integración existente también pasa, aunque su comprobación determinista sí usa una excursión del objetivo: no se utilizó ese salto para el vídeo.

El foreground presenta mayor desplazamiento aparente que las fachadas; luz/arquitectura cambian de solapamiento. La revisión de fotogramas no muestra fuentes desprendidas de sus soportes. Queda aliasing fino en cables y rejas; no se afirma que todas las trayectorias posibles estén libres de shimmer. El skyline sigue mayormente fuera de P30 y no se contabiliza como capa visual validada.

## Foreground

La discrepancia original era un rango de desenfoque cercano demasiado corto, no una capa UI. La baseline actual ya lo amplió a 71–93 m y conserva PBR, depth test, tratamiento pixel y oclusión. Se mantuvo ese ajuste. En el vídeo el segundo jugador queda parcialmente oculto por tuberías, con la etiqueta todavía útil. No se movieron piezas ni colisiones.

## Display

Las líneas cyan eran `Barrier_Field`, una barrera programable del chokepoint del patio. La baseline ya conserva el nodo, mesh, UV y metadata y oculta solo su representación de barras. El marco aloja el display físico **C/S TRANSIT 08**, carcasa, abrazaderas y alimentación. Se conservan sus estados normal/alerta/sin señal/corrupto ligados a parámetros del distrito y el derrame de luz de corto alcance. No se rehízo ni se añadió otro cartel.

## Jugadores

Único cambio artístico nuevo: Sprite3D animado de los dos personajes de escala 2,5 a **3,5** (+40 %), aplicado una sola vez al aparecer en Sector 08. Se inspecciona alpha >=0,5 del primer frame Idle para colocar el borde inferior opaco a 1 cm sobre el apoyo físico. Las etiquetas se elevan por encima de la cabeza.

**La cifra ~113 px describe el lienzo, no el cuerpo opaco.** El cuadro local pasa aproximadamente de 111–113 a **157 px**; el segundo queda en **160 px**. El cuerpo opaco local pasa de aproximadamente 54 a **76 px**, y el segundo de 58 a **81 px**, a 1920×1080. La medición inicial sin umbral incluía alpha residual de compresión; el script final aplica 0,5 y el informe distingue ambas cosas.

Apoyo visual final: Y≈0,0696 / 0,0694 m; suelo físico Y=0,06 m. Alturas visuales aproximadas 2,205 / 2,31 m. No se aumentaron cuerpos, cápsulas, velocidad, footprint ni movimiento. Las cápsulas siguen siendo (radio 0,3291; altura 1,6182) y (radio 0,5; altura 2). No existía un nodo separado de sombra de contacto en estos personajes; no se añadió otro sistema de sombras.

`DioramaArena` solo recibe un hook virtual genérico vacío, `configure_player_presentation()`. MainScene lo invoca al estar listo cada jugador; el ajuste específico vive en Sector08LookDev. La lógica de framing y seguimiento no se modifica. SOFT se selecciona en la instancia real del arena; Clean y Medium siguen disponibles. El muestreo del mundo es 1280×720 sobre render nativo 1920×1080; no se atribuye una reducción del coste GPU a una resolución interna que el pipeline no usa.

## Validación

- Integración existente: **22/22 checks**, dos jugadores, cámara del arena actual, cámaras de personajes cedidas, movement_basis, movimiento, seguimiento y apoyo.
- Runtime Sector 08: **2/2 tests**, recursos, extras y UV auditables.
- Captura integrada ampliada: **16/16 puntos de spawn libres**, 175 formas de colisión, rutas de manifest, wave >0,8, blackout >0,99, recovery <0,001, materiales reactivos compartidos con identidad estable.
- PBR: 2510 meshes authored, 374 overrides; 3043 nodos metadata; 27 meshes Spine. Hashes de GLB, texturas, manifests, shaders, colisiones y movimiento preservados; ver `preservation.json`.
- Suite `test_vertical_slice.gd`: **no ejecutable en esta rama**, faltan HealthComponent y ProgramInstruction. No se incorporaron sistemas de otra rama para ocultar esa limitación.
- Sin errores de carga/importación en el juego. Al cerrar aparecen dos avisos de liberación de recursos de partículas/shader; ya aparecen en la baseline y quedan pendientes.

## Rendimiento

Mismo equipo Apple M5 / Metal Forward+, 1920×1080, SOFT, dos jugadores, 120 muestras sin grabar vídeo. VSync limita la interpretación.

| Métrica | Baseline | Resultado |
|---|---:|---:|
| Frame p50 | 16,720 ms | 16,666 ms |
| Frame p95 | 17,318 ms | 17,979 ms |
| CPU render p50 | 1,599 ms | 1,728 ms |
| Draw calls | 2752 | 2752 |
| Luces añadidas | — | 0 |
| Geometría/texturas añadidas | — | 0 |

GPU timing devuelve 0: no disponible. No hay mejora de rendimiento demostrada; la mediana de frame permanece cercana a 16,7 ms y las diferencias de CPU/p95 no justifican optimizaciones adicionales. No cambia el presupuesto volumétrico.

## Evidencia y deuda visual

Evidencia en `authored/sector08/integrated_pass_20260907`: before/after, recortes de fuentes, foreground, cartel y jugadores; normal/wave/blackout/recovered; vídeo `gameplay.mp4` y JSON de movimiento.

El tamaño visual mejora la presencia sin invadir la UI. Sigue habiendo una franja de arquitectura muy próxima y desenfocada que ocupa bastante pantalla inferior; el segundo spawn sufre oclusión sostenida y el cartel queda parcialmente tapado desde algunas posiciones. Se documenta sin mover arquitectura ni modificar el seguimiento aprobado. La próxima evaluación útil es circulación y legibilidad del segundo jugador en esa franja, además del aliasing de rejas y de las limitaciones del componente artístico de los haces. La arena no se declara terminada.
