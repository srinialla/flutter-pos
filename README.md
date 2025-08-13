# POS Flutter App

A comprehensive Point of Sale (POS) mobile application built with Flutter, featuring offline-first capabilities, barcode scanning, inventory management, and real-time synchronization with Firebase.

## Features

### ✅ **Core Features**
- **Offline-First Architecture**: Full functionality without internet connection
- **User Authentication**: Firebase Auth with email/password
- **Product Management**: Add, edit, delete products with barcode support
- **Barcode/QR Scanning**: Support for multiple formats (EAN-13, UPC-A, Code 128, QR Code)
- **Sales & Checkout**: Complete POS checkout flow with multiple payment methods
- **Inventory Tracking**: Real-time stock management and low stock alerts
- **Local Storage**: Hive database for offline data persistence
- **Firebase Sync**: Two-way synchronization with conflict resolution
- **Modern UI**: Material 3 design with dark/light theme support

### 🔄 **Sync Strategy**
- Automatic sync when online
- Manual sync option
- Conflict resolution (latest timestamp wins)
- Background sync capabilities
- Offline indicator and sync status

### 📱 **Supported Platforms**
- **Mobile**: Android, iOS
- **Web**: Chrome, Firefox, Safari, Edge
- **Desktop**: Windows, macOS, Linux

## Project Structure

```
lib/
├── core/
│   ├── config/          # Firebase configuration
│   ├── models/          # Data models (Product, Sale, etc.)
│   ├── services/        # Business logic services
│   └── router/          # Navigation routing
├── providers/           # State management (Provider pattern)
├── screens/            # UI screens
│   ├── auth/           # Authentication screens
│   ├── dashboard/      # Main dashboard
│   ├── products/       # Product management
│   ├── sales/          # Sales and checkout
│   ├── scanner/        # Barcode scanner
│   ├── settings/       # App settings
│   └── splash/         # Splash screen
└── main.dart           # App entry point
```

## Setup Instructions

### 1. Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / VS Code
- Firebase account

### 2. Clone and Install Dependencies
```bash
git clone <repository-url>
cd pos_flutter_app
flutter pub get
```

### 3. Generate Hive Adapters
```bash
flutter packages pub run build_runner build
```

### 4. Firebase Setup

#### Option A: Use Existing Configuration
The app includes placeholder Firebase configuration. For development, you can:
1. Replace the placeholder values in `lib/core/config/firebase_config.dart`
2. Add your `google-services.json` to `android/app/`
3. Add your `GoogleService-Info.plist` to `ios/Runner/`

#### Option B: Generate New Configuration
1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Enable Authentication and Firestore
3. Run `flutterfire configure` (requires FlutterFire CLI)
4. Follow the prompts to set up platforms

### 5. Android Setup
```bash
# For Android, ensure you have the required permissions in AndroidManifest.xml
# (already configured in this project)
```

### 6. Enable Target Platforms
```bash
# Enable web support
flutter config --enable-web

# Enable desktop support
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop  
flutter config --enable-linux-desktop
```

### 7. Run the App

**Mobile (Android/iOS):**
```bash
flutter run
```

**Web:**
```bash
flutter run -d web-server --web-hostname localhost --web-port 8080
# or
flutter run -d chrome
```

**Desktop:**
```bash
# Windows
flutter run -d windows

# macOS  
flutter run -d macos

# Linux
flutter run -d linux
```

## Firebase Configuration

### Authentication
- Enable Email/Password authentication in Firebase Console
- Optionally enable Google Sign-In

### Firestore Database
Create the following collections structure:
```
users/{userId}/
  ├── products/
  │   └── {productId}
  └── sales/
      └── {saleId}
```

### Security Rules Example
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Usage

### Demo Credentials
For testing purposes, use:
- **Email**: demo@example.com
- **Password**: demo123

### Getting Started
1. **Login**: Use demo credentials or create a new account
2. **Add Products**: Navigate to Products → Add Product
3. **Scan Barcodes**: Use the Scanner to add products by barcode
4. **Make Sales**: Go to Sales → Add products to cart → Checkout
5. **View Analytics**: Dashboard shows sales statistics and inventory status

### Sample Data
The app can generate sample products for testing:
- Go to Products screen
- The app will prompt to add sample data if no products exist

## Platform-Specific Features

### Mobile (Android/iOS)
- **Camera Barcode Scanning**: Real-time camera-based scanning
- **Offline Storage**: Full Hive database with complete offline support
- **Touch Gestures**: Optimized for touch interaction
- **Bottom Navigation**: Mobile-optimized navigation pattern

### Web
- **PWA Support**: Installable Progressive Web App
- **Manual Barcode Entry**: Text input with clipboard support
- **Responsive Design**: Adapts to different screen sizes
- **Keyboard Shortcuts**: Desktop-like keyboard navigation

### Desktop (Windows/macOS/Linux)
- **Window Management**: Resizable windows with native controls
- **Navigation Rail/Drawer**: Desktop-optimized navigation
- **Keyboard Shortcuts**: Full keyboard support
- **Native File System**: Access to local file system for exports
- **Multi-window Support**: Future enhancement capability

## Key Components

### Local Storage (Hive)
- **Products**: Stored in local Hive database
- **Sales**: Complete transaction history
- **Settings**: App preferences and configuration
- **Offline Mode**: Full CRUD operations work offline (Mobile/Desktop only)

### Barcode Scanning
Supported formats:
- EAN-13, EAN-8
- UPC-A, UPC-E
- Code 128, Code 39
- QR Codes

### Sales Flow
1. Add products to cart (scan or search)
2. Modify quantities and apply discounts
3. Calculate tax and total
4. Select payment method
5. Process payment and generate receipt
6. Update inventory automatically

### Sync Process
1. **Upload**: Local changes pushed to Firebase
2. **Download**: Remote changes pulled from Firebase
3. **Conflict Resolution**: Latest timestamp wins
4. **Status Tracking**: Visual indicators for sync status

## Development

### Adding New Features
1. **Models**: Add to `lib/core/models/`
2. **Services**: Business logic in `lib/core/services/`
3. **Providers**: State management in `lib/providers/`
4. **UI**: Screens in `lib/screens/`

### Running Tests
```bash
flutter test
```

### Building for Release

**Mobile:**
```bash
# Android
flutter build apk --release
flutter build appbundle --release  # For Google Play Store

# iOS
flutter build ios --release
```

**Web:**
```bash
# Build for web deployment
flutter build web --release

# Build with custom base href
flutter build web --release --base-href "/pos-app/"
```

**Desktop:**
```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux  
flutter build linux --release
```

## Dependencies

### Core
- `flutter`: UI framework
- `provider`: State management
- `hive`: Local database
- `firebase_core`, `firebase_auth`, `cloud_firestore`: Firebase services

### UI/UX
- `google_fonts`: Typography
- `go_router`: Navigation
- `material_components_flutter`: Material Design

### Features
- `mobile_scanner`: Barcode scanning
- `connectivity_plus`: Network status
- `permission_handler`: Device permissions
- `image_picker`: Image handling
- `intl`: Internationalization

## Troubleshooting

### Common Issues

**Build Runner Issues**:
```bash
flutter packages pub run build_runner clean
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**Firebase Connection Issues**:
- Verify `google-services.json` is in the correct location
- Check Firebase project configuration
- Ensure internet connectivity for initial sync

**Permission Issues**:
- Camera permission required for barcode scanning
- Storage permission for image handling
- Network permission for sync

### Performance
- Local data is cached for fast access
- Images are stored as base64 (consider optimizing for production)
- Sync happens in background to avoid UI blocking

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is open source and available under the [MIT License](LICENSE).

## Support

For support and questions:
- Create an issue in the repository
- Check the documentation
- Review the troubleshooting section

---

**Note**: This is a complete POS application with production-ready features. For production use, consider additional security measures, error handling, and performance optimizations based on your specific requirements.