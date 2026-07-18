# Bubble

Bubble es una aplicación de mensajería para iOS desarrollada con SwiftUI y Firebase. Permite mantener conversaciones privadas, participar en un chat público y crear comunidades con miembros y roles, dentro de una interfaz adaptada a los modos claro y oscuro.

El proyecto prioriza la privacidad, la comunicación en tiempo real y una experiencia coherente entre los distintos tipos de chat.

## Funcionalidades

### Mensajería

- Chats privados entre amigos.
- Chat público compartido entre usuarios.
- Chats de comunidad con propietarios, miembros y roles.
- Mensajes de texto, imágenes, notas de voz y archivos.
- Respuestas dentro de la conversación con una vista previa compacta del mensaje original.
- Edición, reenvío, copia, compartición y eliminación de mensajes.
- Reacciones con emojis y menús contextuales mediante pulsación prolongada.
- Separadores por fecha, hora de envío, avatares y agrupación visual de mensajes consecutivos.
- Animaciones de entrada y globos de conversación con una apariencia común en los tres tipos de chat.

### Comunidades

- Creación y edición de comunidades con imagen propia.
- Carga y caché de imágenes mediante Kingfisher y Firebase Storage.
- Invitación de amigos registrados.
- Roles de miembro, moderador y administrador.
- Gestión de permisos para invitar, expulsar, silenciar y cambiar roles.
- Eliminación de comunidades reservada a su propietario.

### Estado de lectura

- Indicadores visuales para mensajes pendientes.
- Contadores por chat y por comunidad.
- Marcado automático como leído al abrir una conversación.
- Sincronización del estado de lectura entre dispositivos mediante Firestore.
- Badge en el icono de la aplicación con el total de pendientes mientras la aplicación puede sincronizar los datos.

> El badge se actualiza desde los listeners de Firestore. Para recibir nuevos valores con la aplicación completamente cerrada sería necesario añadir notificaciones remotas mediante APNs y Firebase Cloud Messaging.

### Usuarios y seguridad

- Inicio de sesión con Google y Sign in with Apple.
- Creación y edición del perfil, avatar y nombre de usuario.
- Solicitudes de amistad, aceptación, cancelación y eliminación de amigos.
- Estado conectado/desconectado y última conexión.
- Bloqueo de usuarios, denuncias y revisión de reportes.
- Eliminación de cuenta.
- Cifrado de mensajes y adjuntos antes de almacenarlos.
- Firebase App Check para reducir el acceso desde clientes no autorizados.
- Reglas específicas de privacidad para Cloud Firestore y Firebase Storage.

## Tecnologías

- Swift 6 y SwiftUI.
- Firebase Authentication.
- Cloud Firestore.
- Firebase Storage.
- Firebase App Check.
- Google Sign-In.
- AuthenticationServices para Sign in with Apple.
- Kingfisher para descarga y caché de imágenes.
- CryptoKit para cifrado.
- AVFoundation para grabación y reproducción de audio.
- PhotosUI, Quick Look y PDFKit para imágenes y archivos.

El target enlaza únicamente los productos externos que utiliza la aplicación. Las demás entradas que Xcode muestra en Package Dependencies son dependencias transitivas requeridas por Firebase, Firestore o Google Sign-In.

## Requisitos

- macOS con Xcode 16.2 o posterior.
- iOS 18.2 o posterior.
- Una cuenta de Firebase.
- Una aplicación iOS registrada en Firebase.
- Configuración de Google Sign-In y Sign in with Apple para habilitar ambos proveedores.

## Instalación

1. Clona el repositorio:

   ```bash
   git clone https://github.com/lordzzz777/Bubble.git
   cd Bubble
   ```

2. Abre el proyecto:

   ```bash
   open Bubble.xcodeproj
   ```

3. Espera a que Swift Package Manager resuelva las dependencias.

4. Compila el esquema `Bubble` desde Xcode o desde Terminal:

   ```bash
   xcodebuild \
     -project Bubble.xcodeproj \
     -scheme Bubble \
     -sdk iphonesimulator \
     -configuration Debug \
     build CODE_SIGNING_ALLOWED=NO
   ```

## Configuración de Firebase

### 1. Registrar la aplicación

1. Crea o abre un proyecto en [Firebase Console](https://console.firebase.google.com/).
2. Registra una aplicación iOS con el mismo Bundle Identifier configurado en Xcode.
3. Descarga `GoogleService-Info.plist`.
4. Añádelo al target `Bubble` sin publicar credenciales de un proyecto privado.

### 2. Authentication

Activa en Firebase Authentication los proveedores utilizados:

- Google.
- Apple.

Para Apple también debes activar la capability **Sign in with Apple** para el identificador de la aplicación en tu cuenta de Apple Developer y en Xcode.

### 3. Firestore y Storage

Habilita Cloud Firestore y Firebase Storage. Las reglas versionadas del repositorio se encuentran en:

- [`firestore.rules`](firestore.rules)
- [`storage.rules`](storage.rules)

Puedes desplegarlas con Firebase CLI después de seleccionar tu proyecto:

```bash
firebase login
firebase use <firebase-project-id>
firebase deploy --only firestore:rules,storage
```

No utilices reglas globales del tipo `request.auth != null` para toda la base de datos. Las reglas incluidas restringen el acceso según identidad, participación y propiedad de los recursos.

### 4. App Check

La aplicación utiliza el proveedor de depuración durante el desarrollo y el proveedor configurado para producción. Registra los tokens de depuración solamente en entornos de desarrollo y no los publiques en el repositorio.

## Estructura del proyecto

```text
Bubble/
├── Model/          Modelos de usuarios, chats, comunidades y moderación
├── Services/       Firebase, cifrado, archivos, audio y estado de lectura
├── View/           Pantallas y componentes SwiftUI
├── ViewModels/     Estado y lógica de presentación
└── Tools/          Utilidades, logging, red y componentes del sistema
```

La aplicación sigue una separación basada en vistas, ViewModels y servicios. Los listeners en tiempo real se encapsulan en servicios y se cancelan cuando dejan de ser necesarios.

## Privacidad

Bubble almacena en Firebase únicamente la información necesaria para prestar el servicio. Los mensajes y adjuntos compatibles se cifran antes de subirse, y las reglas de Firestore y Storage limitan el acceso a usuarios autenticados y participantes autorizados.

El repositorio incluye [`PrivacyInfo.xcprivacy`](PrivacyInfo.xcprivacy). Antes de distribuir la aplicación, revisa también las declaraciones de privacidad de App Store Connect para que coincidan con los datos realmente tratados por tu despliegue.

## Estado del proyecto

Funciones completadas actualmente:

- Registro, autenticación y flujo de creación de cuenta.
- Perfiles, presencia y solicitudes de amistad.
- Chat privado y chat público con operaciones completas sobre mensajes.
- Comunidades, invitaciones, roles e imágenes.
- Respuestas independientes dentro de cada conversación.
- Imágenes, archivos y notas de voz.
- Reacciones, reenvío y menús contextuales.
- Cifrado de mensajes y adjuntos.
- Estado de lectura y contadores sincronizados.
- Moderación, bloqueo y denuncias.
- Compatibilidad visual con modo claro y oscuro.
- Limpieza de dependencias y código sin uso.

## Capturas históricas

<p>
  <img width="120" alt="Inicio de sesión" src="https://github.com/user-attachments/assets/039ec655-a08c-49b9-bd82-44dc5cb38870" />
  <img width="120" alt="Registro de usuario" src="https://github.com/user-attachments/assets/67a63285-05ce-4904-8e87-60fa455284a8" />
  <img width="120" alt="Listado de chats" src="https://github.com/user-attachments/assets/239da25f-7cf1-4c8a-9a92-cc9e36a7cd3a" />
  <img width="120" alt="Detalle de chat" src="https://github.com/user-attachments/assets/54b10476-ff57-4996-b418-029e3fa23730" />
</p>

<p>
  <img width="120" alt="Conversación privada" src="https://github.com/user-attachments/assets/2f0cea5e-36d1-4928-a35e-5bd31c70316a" />
  <img width="120" alt="Mensajes" src="https://github.com/user-attachments/assets/4b393b6d-021e-4479-9ae3-8fe519674d3f" />
  <img width="120" alt="Vista de chat" src="https://github.com/user-attachments/assets/e85d6473-ff82-4832-bb00-e33581c2ff3d" />
</p>

## Contribuidores

- [Esteban Pérez Castillejo (lordzzz777)](https://github.com/lordzzz777)
- [Jacob Aguilar Campos (yeikobu)](https://github.com/yeikobu)
- [ManuelCBR](https://github.com/ManuelCBR)

## Licencia

Este proyecto se distribuye bajo la [licencia MIT](LICENSE).
