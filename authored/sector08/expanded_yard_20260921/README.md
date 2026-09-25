# Patio ampliado y variante visual

El recinto pasa de 52 × 40 m a 68 × 40 m (31% más de superficie delimitada, no de superficie libre). Ocho metros por lado, con suelo, colisiones, vallas y prolongación del entorno mediante las piezas originales. No se ha escalado la geometría ni alejado la cámara. El generador existente usa una semilla fija; no cambia entre partidas.

El patio central y su arquitectura se conservan. El oeste tiene un acceso estrecho por los edificios existentes; el este ofrece más espacio. Las nuevas franjas son una extensión funcional con menor detalle artístico que el centro, no nuevos distritos completamente compuestos. Para crecer mucho más conviene diseñar módulos completos y ensamblarlos mediante conexiones explícitas.

La cámara ampliada se desplaza paralela al suelo para conservar su altura. Mantiene orientación, FOV, sprites y filtro de diorama. Se omite en esta variante el panel publicitario ligado al encuadre, cuya colocación estaba pensada para un recorrido pequeño. El resto de las estructuras de primer plano sigue en el mundo.

La variante visual reduce bloom, densidad de lluvia y niebla local, y la intensidad de reflejos del suelo; sube la rugosidad mínima. Conserva los acentos cálidos y fríos y la profundidad de campo.

## Comparación y controles

- `centre.png`: variante contenida en el escenario ampliado.
- `wet_comparison.png`: mismo escenario y encuadre con el tratamiento húmedo anterior. La animación ambiental y los centinelas no están sincronizados entre ejecuciones.
- `west.png`, `east.png`: extremos de la ampliación.
- En el nodo Arena de main_scene.tscn: `restrained_presentation = false` recupera el acabado anterior; `lateral_extension = 0` recupera límites, recorrido de cámara y panel de la arena original. Son opciones independientes y se aplican al iniciar la escena.

## Verificación

Godot 4.7.2, Forward+ / Metal, capturas 1920 × 1080. Suite de integración: 30/30 comprobaciones aprobadas (los dos checks del panel no se aplican al estar desactivado). Incluye movimiento, cámara, respawn, colisiones, límites alineados con vallas y cobertura de suelo.

`review_expanded_yard.tscn`: aprobado. Sondeos de cápsula encuentran un corredor recto al oeste y once al este en las filas muestreadas. En ambos extremos el personaje tiene contacto con el suelo, pavimento y posición dentro de cuadro; la cámara conserva la altura. Son pruebas de geometría y posiciones de extremos, no una partida multijugador ni una prueba de oleadas.

Las juntas de las losas tienen una base continua bajo ellas; el informe conserva por separado la cobertura de losas anterior a esa base. Persisten al salir los mensajes de liberación de Shader/Texture RIDs ya documentados en la revisión anterior. No hay una nueva medición de rendimiento.

La propuesta de magia está en `elemental_construction.md`; no se implementaron nuevas habilidades.
