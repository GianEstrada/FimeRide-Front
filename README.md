# fimeride

A new Flutter project.

***

## Requerimientos
- Android Studio 
- Cuenta en mapbox
- Seguir todos los pasos para instalar Flutter en VS Code (https://docs.flutter.dev/install/quick)

## Pasos para importar el proyecto
1. ejecuta el comando `flutter pub get` desde la raiz del pryecto para descargar todas las librerias, dependencias y paquetes necesarios
2. ejecuta el comando `flutter doctor` para verificar que se tiene todo lo necesario.

## Pasos para correr el proyecto
1. Crear un archivo .env en la raiz del proyecto, ASEGURARSE DE QUE EL ARCHIVO ESTA EN EL *.gitignore* PARA QUE NO SE COMMITE.
2. En el .env agregar la key de mapbox de la sig. forma:
    `mapboxAccessToken=tu-key`
> la key se puede encontrar en la pag. de mapbox.
3. desde la consola ejecutar: 
    `flutter run --dart-define-from-file=.env`