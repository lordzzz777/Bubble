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
- **Firebase:** Autenticación, base de datos y notificaciones push.
  
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
   
3. Configura las credenciales de Firebase:
   - Ve a [Firebase Console](https://console.firebase.google.com/).
   - Crea un nuevo proyecto o usa uno existente.
   - Descarga el archivo `GoogleService-Info.plist` y agrégalo al proyecto.

4. Ejecuta el proyecto en un simulador o dispositivo físico:
   ```bash
   xcodebuild run
   ```

---

## Contribuidores

- yeikobu, [Github](https://github.com/yeikobu) y [Linkedin](https://www.linkedin.com/in/jacob-aguilar-campos/overlay/about-this-profile/?lipi=urn%3Ali%3Apage%3Ad_flagship3_profile_view_base%3Bkqfp06aKQ92Qw9GLJqDagg%3D%3D)
- lordzzz777, [Github](https://github.com/lordzzz777) y [Linkedin](https://www.linkedin.com/in/esteban-pérez-castillejo-a79476333/?midToken=AQFoUW3wQ6lhOw&midSig=00uIzmNbyL9HE1&eid=na0p6l-m6peu2ao-y8&otpToken=MTMwMTFlZTcxNzJiYzljY2IwMmIwZmViNDExZGVmYjI4ZmM2ZDk0MDljYWM4YzZlN2JkYTAxNjc0YTVmNWNmYmY0ZGRkNmU3MThlNWNmZjk0MGZhYzhiMDI4NTRjM2RmNTUyM2YzMTdiNTc0OWRlNzhlOTgyMTIwY2QsMSwx&originalSubdomain=es)

---

## Licencia

Este proyecto está licenciado bajo la [MIT License](LICENSE).

---

## Capturas de Pantalla

<img width="150"  alt="login" src="https://github.com/user-attachments/assets/039ec655-a08c-49b9-bd82-44dc5cb38870" />
<img width="150"  alt="Registrar usuario" src="https://github.com/user-attachments/assets/67a63285-05ce-4904-8e87-60fa455284a8" />
<img width="150"  alt="ChatsView" src="https://github.com/user-attachments/assets/239da25f-7cf1-4c8a-9a92-cc9e36a7cd3a" />
<img width="150" alt="listachat" src="https://github.com/user-attachments/assets/54b10476-ff57-4996-b418-029e3fa23730" />
<img width="156" alt="Captura de pantalla 2025-03-05 a las 3 14 51" src="https://github.com/user-attachments/assets/2f0cea5e-36d1-4928-a35e-5bd31c70316a" />
<img width="154" alt="Captura de pantalla 2025-03-05 a las 3 21 22" src="https://github.com/user-attachments/assets/4b393b6d-021e-4479-9ae3-8fe519674d3f" />
<img width="154" alt="Captura de pantalla 2025-03-05 a las 3 31 16" src="https://github.com/user-attachments/assets/6a24d0c6-8971-45ca-a03b-a82062f382d3" />

---

## Próximos Pasos

- **Primer sprint, estatus: finalizado:**
    - Crear login o registro,
    - Crear nueva cuenta
      
- **Segundo sprint, estatus: finalizado:**
    - Vista chats: Vistas de Listado de Chats,
    - Vista chats: Eliminar chats con swipe hacia la izquierda,
    - Vista de chats: Mostrar detalles en tarjetas de chat (Chat Card Details)
  
- **Tercero sprint, estatus: finalizado:**
    - Flujo de navegación según estado de registro,
    - Solucionar typo del botón de Google,
    - Eliminar chats con swipe hacia la izquierda,
    - Solicitudes de amistad, Flujo de navegación según estado de registro
      
- **Cuarto sprint, estatus: finalizado :**
    - Solucionar bug que te lleva a la pantalla de crear nueva cuenta con una cuenta ya creada,
    - Solucionar bug que crashea la app al recibir una solicitud de amistad,
    - Refactorizar alerts de la vista de chats y su respectivo viewmodel,
    - Refactorizar alerts de la vista de chats y su respectivo viewmodel,
    - Actualización Readme

- **Quinto sprint, estatus: finalizado :**
    - Solucionar bug aceptar solicitudes de amistad
    - Edición de perfil
    - Funcionalidad para enviar y recibir mensajes en la vista de un chat
    - Actualización Readme

- **Sexto sprint, estatus: finalizado :**
    - Eliminación de Cuenta en "Bubble"
    - Agregar menu con opciones a la vista de Chat
    - Vista chats: Cambiar Entre Chats Privados y Público
    - Errores en la vista de chat privado
    - Agregar funcionalidad de mostrar hora en cada mensaje y el chat

- **Septimo sprint, estatus: finalizado :**
    - Solucionar bug que no agrega el ID del amigo agregado al arreglo en firebase firestore
    - Mejoras en la visualización de mensajes
    - solucionar el desborde del botón de cerrar sesión en los iPhone pequeños
      
- **Octavo sprint, estatus: En Proceso ... :**
    - Refactorización general de Proyecto
    - modificar de funciónalidad de agregar amigos
    - CRUD de mensjes dentro chats Cafe
    - Funcionalidad de actualizar estado conectado/desconectado
