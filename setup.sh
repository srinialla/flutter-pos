#!/bin/bash

# 🚀 Flutter POS App Setup Script
# This script automates the setup process for the Flutter POS app

set -e  # Exit on any error

echo "🚀 Starting Flutter POS App Setup..."
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if Flutter is installed
check_flutter() {
    print_info "Checking Flutter installation..."
    if command -v flutter &> /dev/null; then
        FLUTTER_VERSION=$(flutter --version | head -n 1)
        print_status "Flutter is installed: $FLUTTER_VERSION"
    else
        print_error "Flutter is not installed!"
        print_info "Please install Flutter from: https://docs.flutter.dev/get-started/install"
        exit 1
    fi
}

# Check Flutter doctor
check_flutter_doctor() {
    print_info "Running Flutter doctor..."
    if flutter doctor --android-licenses > /dev/null 2>&1; then
        print_status "Flutter doctor check passed"
    else
        print_warning "Flutter doctor has some issues. Running flutter doctor..."
        flutter doctor
        print_info "Please resolve any issues shown above before continuing"
        read -p "Press Enter to continue after resolving issues..."
    fi
}

# Install dependencies
install_dependencies() {
    print_info "Installing Flutter dependencies..."
    if flutter pub get; then
        print_status "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
}

# Add dev dependencies
add_dev_dependencies() {
    print_info "Adding development dependencies..."
    flutter pub add --dev build_runner hive_generator
    print_status "Development dependencies added"
}

# Generate Hive adapters
generate_adapters() {
    print_info "Generating Hive type adapters..."
    if flutter packages pub run build_runner build --delete-conflicting-outputs; then
        print_status "Hive adapters generated successfully"
    else
        print_warning "Failed to generate adapters. This might be due to missing dependencies."
        print_info "You can manually run: flutter packages pub run build_runner build"
    fi
}

# Check for Firebase configuration
check_firebase() {
    print_info "Checking Firebase configuration..."
    if [ -f "lib/firebase_options.dart" ]; then
        print_status "Firebase is configured"
    else
        print_warning "Firebase not configured"
        print_info "To configure Firebase:"
        print_info "1. Install Firebase CLI: npm install -g firebase-tools"
        print_info "2. Login: firebase login"
        print_info "3. Configure: flutterfire configure"
        
        read -p "Do you want to configure Firebase now? (y/n): " configure_firebase
        if [ "$configure_firebase" == "y" ] || [ "$configure_firebase" == "Y" ]; then
            configure_firebase_now
        fi
    fi
}

# Configure Firebase
configure_firebase_now() {
    print_info "Configuring Firebase..."
    
    # Check if Firebase CLI is installed
    if command -v firebase &> /dev/null; then
        print_status "Firebase CLI is installed"
    else
        print_warning "Firebase CLI not found. Installing..."
        if command -v npm &> /dev/null; then
            npm install -g firebase-tools
        else
            print_error "npm not found. Please install Node.js and npm first"
            return 1
        fi
    fi
    
    # Check if FlutterFire CLI is installed
    if command -v flutterfire &> /dev/null; then
        print_status "FlutterFire CLI is installed"
    else
        print_info "Installing FlutterFire CLI..."
        dart pub global activate flutterfire_cli
    fi
    
    # Configure Firebase
    print_info "Running flutterfire configure..."
    flutterfire configure
    print_status "Firebase configuration completed"
}

# Create Android permissions
setup_android_permissions() {
    print_info "Setting up Android permissions..."
    
    MANIFEST_FILE="android/app/src/main/AndroidManifest.xml"
    
    if [ -f "$MANIFEST_FILE" ]; then
        # Check if permissions are already added
        if grep -q "POST_NOTIFICATIONS" "$MANIFEST_FILE"; then
            print_status "Android permissions already configured"
        else
            print_info "Adding Android permissions to manifest..."
            
            # Backup original manifest
            cp "$MANIFEST_FILE" "${MANIFEST_FILE}.backup"
            
            # Add permissions before <application> tag
            sed -i '/<application/i\
    <!-- Notification permissions -->\
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\
    <uses-permission android:name="android.permission.VIBRATE" />\
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />\
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\
    \
    <!-- Bluetooth permissions -->\
    <uses-permission android:name="android.permission.BLUETOOTH" />\
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />\
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\
    \
    <!-- File access permissions -->\
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>\
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>\
' "$MANIFEST_FILE"
            
            print_status "Android permissions added to manifest"
        fi
    else
        print_warning "Android manifest not found. Skipping Android permissions setup."
    fi
}

# Test app compilation
test_compilation() {
    print_info "Testing app compilation..."
    if flutter analyze; then
        print_status "Static analysis passed"
    else
        print_warning "Static analysis found issues. Check output above."
    fi
    
    # Try to build for the current platform
    print_info "Testing build process..."
    case "$OSTYPE" in
        darwin*)  
            if flutter build ios --no-codesign; then
                print_status "iOS build test passed"
            else
                print_warning "iOS build test failed"
            fi
            ;;
        linux*)   
            if flutter build linux; then
                print_status "Linux build test passed"
            else
                print_warning "Linux build test failed"
            fi
            ;;
        msys*|win32*)     
            if flutter build windows; then
                print_status "Windows build test passed"
            else
                print_warning "Windows build test failed"
            fi
            ;;
        *)        
            print_info "Skipping platform-specific build test"
            ;;
    esac
}

# Display summary
display_summary() {
    echo ""
    echo "======================================"
    echo -e "${GREEN}🎉 Setup Complete!${NC}"
    echo "======================================"
    echo ""
    echo -e "${BLUE}📱 Your Flutter POS App is ready!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run the app: flutter run"
    echo "2. For release build: flutter build apk (Android) or flutter build ios (iOS)"
    echo "3. Check SETUP_AND_FIXES.md for detailed information"
    echo ""
    echo "Features included:"
    echo "✅ Complete POS system"
    echo "✅ Refund management with audit trails"
    echo "✅ Multi-user team synchronization"
    echo "✅ Inventory alerts and management"
    echo "✅ Bluetooth printer support"
    echo "✅ Export to CSV/Excel/PDF"
    echo "✅ Customer and supplier management"
    echo "✅ Purchase order management"
    echo "✅ Advanced analytics and reporting"
    echo ""
    echo -e "${GREEN}Happy coding! 🚀${NC}"
}

# Main execution
main() {
    print_info "Flutter POS App Setup Script v1.0"
    echo ""
    
    check_flutter
    check_flutter_doctor
    install_dependencies
    add_dev_dependencies
    generate_adapters
    check_firebase
    setup_android_permissions
    test_compilation
    display_summary
}

# Run main function
main "$@"