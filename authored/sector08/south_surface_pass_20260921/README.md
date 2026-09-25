# Patio sur, farola y superficies

## Implementado

- Extensión sur de 14 m, hasta z=28; recinto total 68 × 54 m. Suelo, base continua y vallas usan los mismos límites que la colisión. La cámara conserva altura y orientación.
- Primer módulo fijo editable: `scenes/environment/sector_08/modules/south_rain_court.tscn`. Dos jardineras, drenaje, luz de servicio y marcadores de conexión norte/sur. La colocación es manual; no hay generación aleatoria de módulos. Pavimento y cierre perimetral siguen usando las piezas reutilizadas existentes.
- Eliminado el plano aditivo de tres rayos dibujados en la luminaria cálida. Conservada la luz volumétrica con sombras; reducido el aporte volumétrico de la farola del patio.
- Humedad restaurada sin recuperar todo el bloom. Materiales de suelo reciben humedad ambiental y hasta ocho regiones locales actualizables por ID.
- Humedad y fractura visual independientes. Lluvia humedece; ausencia de lluvia seca más lentamente. El mismo control ajusta emisores de lluvia e impactos visuales sobre agua.

## API de presentación

`Arena/GroundSurfaceState.set_rain(intensity)` controla lluvia en [0,1]. `set_patch(id, Vector2(x,z), radius, moisture, fracture)` crea o actualiza una zona y devuelve false si el radio no es positivo o se supera el límite de ocho zonas. `remove_patch(id)` la retira. El radio está limitado a 12 m. En zonas superpuestas la humedad de la última zona insertada se mezcla sobre las anteriores; las grietas usan el máximo. No ejecutar estas llamadas independientemente en cada cliente para mecánicas competitivas: un futuro sistema autoritativo debe replicar sus parámetros.

La humedad varía gradualmente. La fractura actual es una máscara visual sobre el pavimento, no desplazamiento de vértices, colisión ni destrucción. Las zonas de prueba sólo se crean en la escena de verificación; el juego arranca sin grietas mágicas.

## Estados que conviene separar

| Eje | Valores iniciales propuestos | Consecuencia futura |
|---|---|---|
| Sustrato | pavimento, tierra, canal | Qué transformaciones permite |
| Humedad | seco → húmedo → saturado | Reserva de agua y aspecto |
| Integridad | intacto → agrietado → abierto | Acceso al sustrato y espacio para raíces |
| Temperatura | normal, congelado | Hielo sobre agua existente |
| Vegetación | ausente, brotando, estable | Raíces y plantas como entidades |

No convertir cada combinación en un material distinto. Un pavimento puede estar mojado y agrietado a la vez. Hielo, deformación y vegetación son propuestas; no están implementados.

Para naturaleza: abrir una grieta sobre un sustrato permitido, hacer emerger una raíz o planta de una biblioteca pequeña de formas y activar su colisión cuando haya espacio. La humedad podría acelerar el crecimiento. Así se reutiliza la secuencia de transformación y previsualización de agua/hielo sin simular raíces ni romper cada losa en fragmentos físicos. La zona debe conservar su grieta cuando la planta desaparezca, si así lo define la mecánica.

## Alcance

Este es un módulo inicial y una base de presentación, no un bioma terminado ni un sistema completo de construcción. El centro conserva su composición; la ampliación requiere una pasada artística posterior si se quiere el mismo detalle en todo el recinto. No se implementaron hechizos, consumo de recursos, navegación dinámica ni replicación de estados del terreno.

## Verificación realizada

Godot 4.7.2 / Metal, 1920 × 1080. Integración 30/30. Prueba de ampliación aprobada: acceso recto desde el patio anterior hacia el sur en diez filas muestreadas, contacto con suelo, pavimento y jugador dentro del encuadre en ambos lados y al sur. Altura de cámara preservada. Pruebas de superficie aprobadas: humedecimiento, secado, fractura independiente, límite de regiones, actualización por ID, rechazo de radio inválido y apagado de emisores al detener lluvia.

Capturas: centre.png muestra luz y humedad; south.png muestra el módulo; dry_cracked.png y wet_cracked.png prueban la misma región con humedad distinta. Los efectos ambientales no están sincronizados entre las imágenes. Persisten los avisos conocidos de recursos de render al cerrar Godot. No se midió rendimiento ni se probó multijugador.
