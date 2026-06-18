# Mi Biblioteca

Aplicación Android de lectura de PDFs publicada en Google Play. Diseñada para transformar documentos PDF en una experiencia de lectura, con funcionalidades inteligentes para estudiar y organizar tu contenido.

## Descargar

[![Google Play](https://img.shields.io/badge/Google_Play-Descargar-green?style=for-the-badge&logo=google-play)](https://play.google.com/store/apps/details?id=com.isidrogajardo.mi_biblioteca)

## Características

**Biblioteca personal**
- Importa PDFs desde tu dispositivo
- Miniatura automática de portada
- Búsqueda y ordenamiento por nombre, fecha o última lectura
- Progreso de lectura guardado automáticamente

**Modo lectura inteligente**
- Extrae el texto del PDF y lo presenta como libro digital
- Tipografía Merriweather con texto justificado
- Temas claro, oscuro y sepia
- Tamaño de fuente y espaciado ajustable
- Animación de cambio de página

**Subrayados y notas**
- Selecciona texto y subraya con 4 colores (amarillo, verde, rojo, azul)
- Notas por página
- Panel de subrayados agrupados por página
- Navegación directa al subrayado con un toque

**Búsqueda inteligente**
- Busca palabras o frases dentro del libro
- Muestra contexto completo de cada resultado
- Navega directo a la página del resultado

**OCR para PDFs escaneados**
- Detecta automáticamente si el PDF es escaneado
- Extrae texto con Google MLKit (100% offline)
- Actívalo en cualquier momento desde la biblioteca

**100% Offline**
- No requiere internet para ninguna función
- Todos los datos se guardan localmente con Hive

## Stack tecnológico

|        Área          |             Tecnología              |
|----------------------|-------------------------------------|
| Framework            | Flutter + Dart                      |
| Base de datos local  | Hive                                |
| Renderizado PDF      | pdfx                                |
| Extracción de texto  | syncfusion_flutter_pdf              |
| OCR offline          | Google MLKit Text Recognition       |
| Selector de archivos | file_picker                         |
| Tipografía           | Google Fonts (Merriweather + Inter) |
| Animaciones          | flutter_animate                     |

## Estructura del proyecto

```
lib/
├── main.dart
├── models/
│   ├── libro.dart
│   └── subrayado.dart
├── screens/
│   ├── biblioteca_screen.dart   # Pantalla principal
│   ├── lector_screen.dart       # Lector PDF y modo lectura
│   ├── busqueda_screen.dart     # Busqueda dentro del libro
│   └── onboarding_screen.dart   # Pantalla de bienvenida
├── services/
│   ├── storage_service.dart     # CRUD con Hive
│   └── pdf_service.dart         # Procesamiento PDF y OCR
├── widgets/
│   └── libro_card.dart
└── theme/
    └── app_theme.dart
```

## Cómo ejecutar

```bash
# Clonar repositorio
git clone https://github.com/Isidro-Gajardo/mi-biblioteca.git
cd mi-biblioteca

# Instalar dependencias
flutter pub get

# Ejecutar en dispositivo Android
flutter run
```

> **Nota:** Se requiere dispositivo o emulador Android. La app no esta disponible para iOS ni web.


## Próximas funcionalidades (posiblemente...)

- [ ] Resaltado visual de subrayados en modo PDF
- [ ] Estadísticas de lectura
- [ ] Soporte para múltiples idiomas en OCR

## Autor

**Isidro Gajardo** — Ingeniero en Informática  
[GitHub](https://github.com/Isidro-Gajardo) · [LinkedIn](https://linkedin.com/in/isidro-gajardo-velasquez-54169b348)
