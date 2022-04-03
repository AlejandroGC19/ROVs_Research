REALIZADO POR: Alejandro Garrocho Cruz, Diciembre 2021

OBJETIVO: Este script consiste en representar los datos ya obtenidos con el sonar Ping360 en pruebas experimentales, con el objetivo de procesar los datos mediante clustering para llevar a cabo la estimación de la abundancia de peces.

El algoritmo principal es IdentificacionPeces.m, el resto son funciones que utilizaremos o no dependiendo de las características de la prueba que se determine.

El orden de uso de estas funciones es el siguiente:
1. Grafica_sonar360_v2: Crea el interfaz donde se mostrarán los resultados, características de la prueba y botones para interactuar.
2. CrearMensajeSonar360_TR: Crea el formato del mensaje byte a byte del protocolo PingProtocol utilizado por el sonar Ping360 de BlueRobotics.
3. ObtenerMatrizParedCircular/Poligono: Usar para entornos cerrados (circulares o poligonales) para evitar detección de paredes.
4. Representacion_PV_TR: Representa los datos almacenados.
5. IdentificacionYFiltro: Realiza el clustering para identificar los componentes que queremos detecctar.
6. Cerrrar_Grafico_v2: Permite cerrar la gráfica al pulsar el botón "salir".
