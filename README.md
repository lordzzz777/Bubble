# Bubble

## Descripción
Bubble es una aplicación moderna y minimalista desarrollada en **SwiftUI**, diseñada para ofrecer una experiencia de comunicación rápida, segura y eficiente entre usuarios. La aplicación prioriza la simplicidad, el rendimiento y la privacidad.

---

## Características Principales

- **Chats en tiempo real:** Mantén conversaciones rápidas y fluidas.
- **Cifrado extremo a extremo:** Aseguramos la privacidad de tus mensajes.
- **Notificaciones push:** Recibe alertas instantáneas de mensajes nuevos.
- **Interfaz amigable:** Diseñada para ofrecer una experiencia intuitiva y agradable.
- **Compatibilidad multimedia:** Envía y recibe imágenes, videos y archivos.
- **Personalización:** Elige temas claros u oscuros.

---

## Tecnologías Utilizadas

- **SwiftUI:** Para la interfaz de usuario moderna y reactiva.
- **Combine:** Para manejar eventos y datos en tiempo real.
- **Firebase:** Autenticación, base de datos y notificaciones push.
- **CloudKit:** Almacenamiento seguro en la nube.
- **Core Data:** Almacenamiento local de mensajes.

---

## Instalación y Configuración

1. Clona este repositorio:
   ```bash
   git clone https://github.com/lordzzz777/Bubble.git
   ```

2. Abre el proyecto en **Xcode**:
   ```bash
   cd Bubble
   open Bubble.xcodeproj
   ```

3. Instala las dependencias necesarias usando **CocoaPods** o **Swift Package Manager** (según sea necesario).
   ```bash
   pod install
   ```

4. Configura las credenciales de Firebase:
   - Ve a [Firebase Console](https://console.firebase.google.com/).
   - Crea un nuevo proyecto o usa uno existente.
   - Descarga el archivo `GoogleService-Info.plist` y agrégalo al proyecto.

5. Ejecuta el proyecto en un simulador o dispositivo físico:
   ```bash
   xcodebuild run
   ```

---

## Contribuidores

- **Esteban** - [@tu_usuario](https://github.com/tu_usuario)
- **Tu compañero** - [@usuario_compañero](https://github.com/usuario_compañero)

---

## Licencia

Este proyecto está licenciado bajo la [MIT License](LICENSE).

---

## Capturas de Pantalla

![Pantalla de Inicio](docs/screenshots/home.png)
![Chat en Tiempo Real](docs/screenshots/chat.png)

---

## Próximos Pasos

- Implementar videollamadas en tiempo real.
- Añadir soporte para stickers y emojis personalizados.
- Mejorar la accesibilidad y localización a varios idiomas.
