# POS Flutter App - Cross-Platform Deployment Guide

This guide covers deployment for mobile, web, and desktop platforms.

## 🚀 Quick Start Commands

### Development
```bash
# Mobile (Android/iOS)
flutter run

# Web  
flutter run -d chrome

# Desktop
flutter run -d windows  # or -d macos / -d linux
```

### Production Builds
```bash
# Mobile
flutter build apk --release                    # Android APK
flutter build appbundle --release              # Android App Bundle
flutter build ios --release                    # iOS

# Web
flutter build web --release                    # Web deployment

# Desktop  
flutter build windows --release                # Windows
flutter build macos --release                  # macOS
flutter build linux --release                  # Linux
```

## 📱 Mobile Deployment

### Android

#### Prerequisites
- Android Studio installed
- Android SDK and build tools
- Keystore for signing (production)

#### Development
```bash
# Run on device/emulator
flutter run

# Build debug APK
flutter build apk --debug
```

#### Production
```bash
# Create keystore (first time only)
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Configure signing in android/key.properties
storePassword=your_store_password
keyPassword=your_key_password  
keyAlias=upload
storeFile=../path/to/upload-keystore.jks

# Build release APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

#### Distribution
- **APK**: Direct installation or third-party stores
- **App Bundle**: Google Play Store upload

### iOS

#### Prerequisites
- Xcode installed (macOS only)
- Apple Developer account
- iOS development certificates

#### Development
```bash
# Run on device/simulator (macOS only)
flutter run
```

#### Production
```bash
# Build iOS app
flutter build ios --release

# Archive and upload via Xcode
open ios/Runner.xcworkspace
```

## 🌐 Web Deployment

### Build
```bash
# Standard web build
flutter build web --release

# With custom base href (for subdirectories)
flutter build web --release --base-href "/pos-app/"
```

### Hosting Options

#### 1. Firebase Hosting
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize in project root
firebase init hosting

# Deploy
firebase deploy
```

#### 2. GitHub Pages
```bash
# Build with GitHub Pages base href
flutter build web --release --base-href "/repository-name/"

# Copy build/web contents to gh-pages branch
```

#### 3. Nginx/Apache
```nginx
# nginx.conf example
server {
    listen 80;
    server_name your-domain.com;
    root /path/to/build/web;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

#### 4. Docker
```dockerfile
# Dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### PWA Features
- **Offline Support**: Service worker caching
- **Install Prompt**: Add to home screen
- **Push Notifications**: Future enhancement

## 🖥️ Desktop Deployment

### Windows

#### Prerequisites
- Visual Studio 2019+ with C++ tools
- Windows 10 SDK

#### Build
```bash
# Build Windows executable
flutter build windows --release
```

#### Distribution
- **Portable**: Distribute `build/windows/runner/Release/` folder
- **Installer**: Use tools like Inno Setup or NSIS
- **Microsoft Store**: Package as MSIX

#### MSIX Package
```bash
# Add msix dependency to pubspec.yaml
# Configure msix settings
flutter pub run msix:create
```

### macOS

#### Prerequisites
- Xcode installed
- macOS development environment

#### Build
```bash
# Build macOS app
flutter build macos --release
```

#### Distribution
- **DMG**: Create disk image for distribution
- **App Store**: Submit via App Store Connect
- **Notarization**: Required for distribution outside App Store

### Linux

#### Prerequisites
- Linux development tools
- GTK development libraries

#### Build
```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

# Build Linux app
flutter build linux --release
```

#### Distribution
- **AppImage**: Portable application format
- **Snap**: Ubuntu software center
- **Flatpak**: Cross-distribution package

## 🔧 Platform-Specific Configurations

### Web Configuration

#### Progressive Web App
- Manifest configured in `web/manifest.json`
- Service worker for offline support
- Custom icons and splash screens

#### Security Headers
```html
<!-- Add to web/index.html -->
<meta http-equiv="Content-Security-Policy" content="default-src 'self'">
```

### Desktop Configuration

#### Windows
- App icon: `windows/runner/resources/app_icon.ico`
- Version info: `windows/runner/Runner.rc`
- Dependencies: Included in build output

#### macOS
- App icon: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- Info.plist: `macos/Runner/Info.plist`
- Entitlements: Configure for sandbox/capabilities

#### Linux
- Desktop file: Create `.desktop` file for application menu
- App icon: Standard Linux icon sizes

## 📊 Performance Optimization

### Web
- **Tree Shaking**: Automatic in release builds
- **Code Splitting**: Use deferred imports
- **Caching**: Configure service worker

### Mobile
- **Obfuscation**: `--obfuscate --split-debug-info=build/debug-info/`
- **Shrinking**: Enable in `android/app/build.gradle`

### Desktop
- **Native Dependencies**: Minimize external libraries
- **Startup Time**: Optimize initialization code

## 🚀 CI/CD Pipeline Example

### GitHub Actions
```yaml
# .github/workflows/build.yml
name: Build Multi-Platform

on: [push, pull_request]

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.10.0'
        
    - run: flutter pub get
    - run: flutter test
    
    # Platform-specific builds
    - name: Build Web
      if: matrix.os == 'ubuntu-latest'
      run: flutter build web --release
      
    - name: Build Windows
      if: matrix.os == 'windows-latest'  
      run: flutter build windows --release
      
    - name: Build macOS
      if: matrix.os == 'macos-latest'
      run: flutter build macos --release
      
    - name: Build Linux
      if: matrix.os == 'ubuntu-latest'
      run: flutter build linux --release
```

## 🔐 Security Considerations

### All Platforms
- **Firebase Security Rules**: Properly configured
- **API Keys**: Environment-specific configuration
- **Data Encryption**: Implement for sensitive data

### Web
- **HTTPS**: Required for PWA features
- **CSP Headers**: Content Security Policy
- **XSS Protection**: Input sanitization

### Mobile
- **Certificate Pinning**: For API communications
- **Root Detection**: Consider for sensitive apps
- **Biometric Authentication**: Future enhancement

### Desktop
- **Code Signing**: Required for distribution
- **Update Security**: Secure update mechanism
- **Privilege Escalation**: Run with minimal permissions

## 📈 Monitoring & Analytics

### Web
- Google Analytics for web
- Performance monitoring
- Error tracking (Sentry, etc.)

### Mobile
- Firebase Analytics
- Crashlytics for crash reporting
- Performance monitoring

### Desktop
- Custom analytics implementation
- Error logging and reporting
- Usage metrics collection

## 🆘 Troubleshooting

### Common Issues

#### Web
- **CORS Issues**: Configure Firebase/backend CORS
- **Service Worker**: Clear cache during development
- **Font Loading**: Ensure fonts are properly served

#### Mobile
- **Build Issues**: Check Android/iOS toolchain
- **Permissions**: Verify manifest permissions
- **Signing**: Ensure proper certificate configuration

#### Desktop
- **Dependencies**: Install required system libraries
- **Permissions**: File system access rights
- **Display Issues**: Handle different screen DPI

### Debug Commands
```bash
# Verbose build output
flutter build [platform] --release --verbose

# Analyze app size
flutter build [platform] --analyze-size

# Check for issues
flutter doctor -v
```

---

## Support & Resources

- **Flutter Documentation**: https://flutter.dev/docs
- **Platform Guides**: https://flutter.dev/docs/deployment
- **Community Support**: https://flutter.dev/community
- **Issue Tracking**: Create issues in project repository

For platform-specific deployment questions, refer to the official Flutter documentation and platform-specific guidelines.