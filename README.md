# 🌾 Phytolens

**AI-Powered Plant Disease Detection & Agricultural Monitoring System**

A production-ready Flutter application combining machine learning, real-time weather monitoring, and smart notifications to help farmers protect their crops.

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Backend-009688?logo=fastapi)](https://github.com/rudra2311-patel/FAST_API)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 🎯 What It Does

Phytolens empowers farmers with:
- **🔬 Instant Disease Detection** - On-device ML using TensorFlow Lite (no internet needed)
- **🌦️ Real-Time Weather Alerts** - Critical weather notifications via WebSocket + FCM
- **🗺️ Farm Management** - Geolocation-based farm monitoring
- **📊 Smart Notifications** - 24hr deduplication system (no spam alerts)
- **🌍 Multi-Language Support** - Accessible to farmers worldwide

---

## 🚀 Tech Stack

### Frontend (Flutter)
```
Flutter 3.0+ • Dart • Provider (State Management)
TensorFlow Lite • SQLite • WebSocket
Firebase (FCM, Analytics) • Geolocator
```

### Backend ([FastAPI Repository](https://github.com/rudra2311-patel/FAST_API))
```
FastAPI • PostgreSQL • Redis • JWT Auth
Firebase Admin SDK • WebSocket • Docker
```

### Key Features
- **Offline-First Architecture** - ML inference works without internet
- **Dual Notification System** - Local alerts + backend FCM sync
- **JWT Authentication** - Secure token refresh flows
- **Real-Time Monitoring** - WebSocket for live updates
- **Smart Alert Deduplication** - Prevents notification spam

---

## 📖 Deep Dive

Want to understand how it all works?

👉 **[Engineering Behind Phytolens](https://chic-taffy-7be25a.netlify.app/)**

Explore the architecture, technical decisions, challenges solved, and system design.

---

## 🎨 Screenshots

<table>
  <tr>
    <td><img src="screenshots/home.png" width="200"/></td>
    <td><img src="screenshots/scan.png" width="200"/></td>
    <td><img src="screenshots/alerts.png" width="200"/></td>
    <td><img src="screenshots/farms.png" width="200"/></td>
  </tr>
  <tr>
    <td align="center">Home Dashboard</td>
    <td align="center">Disease Scan</td>
    <td align="center">Weather Alerts</td>
    <td align="center">Farm Management</td>
  </tr>
</table>

---

## 🛠️ Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio / VS Code
- Firebase account (for FCM)

### Installation

```bash
# Clone the repository
git clone https://github.com/rudra2311-patel/agriscan-pro.git
cd agriscan-pro

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Backend Setup
Check out the [FastAPI Backend Repository](https://github.com/rudra2311-patel/FAST_API) for backend setup instructions.

---

## 📦 Project Structure

```
lib/
├── core/           # Theme, constants, utilities
├── models/         # Data models (Alert, Farm, Notification)
├── screens/        # UI screens (Auth, Home, Farms, Scans, Alerts)
├── services/       # API, Database, FCM, Translation
├── widgets/        # Reusable UI components
└── main.dart       # App entry point
```

---

## 🔑 Key Implementations

### 1. On-Device ML
- TensorFlow Lite model for instant plant disease detection
- No cloud dependency - works offline
- Real-time inference with camera feed

### 2. Notification Architecture
- **Local Layer**: SQLite for daily weather status
- **Backend Layer**: PostgreSQL with FCM for critical alerts
- **Smart Sync**: Unified display with read/unread state management

### 3. Weather Monitoring
- WebSocket connection for real-time updates
- REST API fallback
- 24-hour deduplication logic

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Developer

**Rudra Patel**

- 🌐 Portfolio: [rudrabuilds.me](https://rudrabuilds.me)
- 💼 LinkedIn: [Rudra Patel](https://www.linkedin.com/in/rudra-patel-32859425b/)
- 📧 Email: programmercreature@gmail.com
- 🐙 GitHub: [@rudra2311-patel](https://github.com/rudra2311-patel)

---

## ⭐ Show Your Support

If you find this project useful, please consider giving it a star! It helps others discover the project.

---

<div align="center">
  <sub>Built with ❤️ for farmers worldwide</sub>
</div>
