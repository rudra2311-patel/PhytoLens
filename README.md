<div align="center">

# 🌾 Phytolens

### *AI-Powered Plant Disease Detection & Agricultural Monitoring*

**Instant, Offline, Intelligent — Empowering Farmers with Technology**

<br>

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Backend-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://github.com/rudra2311-patel/FAST_API)
[![TensorFlow](https://img.shields.io/badge/TensorFlow_Lite-ML-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue?style=for-the-badge)](LICENSE)

<br>

### 🚀 **[EXPLORE THE COMPLETE ENGINEERING JOURNEY →](https://chic-taffy-7be25a.netlify.app/)**

*Architecture • System Design • Technical Deep Dives • Problem-Solving*

---

</div>

## 💡 The Vision

Phytolens bridges the gap between cutting-edge AI technology and agricultural needs. Built as a **production-ready, full-stack mobile application** that works offline, delivers instant results, and scales with real-world farming demands.

### What Makes It Special?

```
🔬 On-Device ML          →  No internet? No problem. TensorFlow Lite runs locally
🌐 Real-Time Monitoring  →  WebSocket + FCM for instant critical weather alerts
🎯 Smart Notifications   →  24-hour deduplication prevents alert fatigue
🗺️  Farm Management      →  Geolocation-based multi-farm tracking
🌍 Accessibility         →  Multi-language support for global reach
```

---

## 🛠️ Tech Stack

<div align="center">

### Frontend Arsenal
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Provider](https://img.shields.io/badge/Provider-State_Management-blueviolet?style=flat-square)
![TensorFlow Lite](https://img.shields.io/badge/TensorFlow_Lite-FF6F00?style=flat-square&logo=tensorflow&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![WebSocket](https://img.shields.io/badge/WebSocket-Real--Time-success?style=flat-square)

### Backend Powerhouse
[![Backend Repo](https://img.shields.io/badge/🔗_Backend_Repository-FastAPI-009688?style=flat-square)](https://github.com/rudra2311-patel/FAST_API)

![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=flat-square&logo=postgresql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-DC382D?style=flat-square&logo=redis&logoColor=white)
![JWT](https://img.shields.io/badge/JWT-Auth-black?style=flat-square&logo=jsonwebtokens)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)
![Firebase Admin](https://img.shields.io/badge/Firebase_Admin-FFCA28?style=flat-square&logo=firebase&logoColor=black)

</div>

---

## 🎯 Key Features

<table>
<tr>
<td width="50%">

### 🧠 Machine Learning
- **On-Device Inference** with TensorFlow Lite
- No cloud dependency (works 100% offline)
- Real-time camera feed processing
- Instant disease classification

</td>
<td width="50%">

### 🔔 Notification System
- **Dual-layer architecture** (Local + Backend)
- SQLite for daily status checks
- PostgreSQL + FCM for critical alerts
- Smart deduplication (no spam!)

</td>
</tr>
<tr>
<td width="50%">

### 🌦️ Weather Monitoring
- WebSocket for real-time updates
- REST API fallback mechanism
- 24-hour deduplication logic
- Location-based farm tracking

</td>
<td width="50%">

### 🔐 Security & Auth
- JWT token-based authentication
- Secure token refresh flows
- Encrypted local storage
- Backend session management

</td>
</tr>
</table>

---

## 📐 Architecture & Screenshots

<!-- Add your architecture diagrams and app screenshots here -->







---

<div align="center">

## 🎓 Want to See How It All Works?

### **[📚 Complete Technical Documentation & Architecture →](https://chic-taffy-7be25a.netlify.app/)**

*Deep dive into system design, technical decisions, challenges solved, and implementation details*

**🔍 What You'll Discover:**
- Full system architecture breakdown
- Machine learning pipeline explained
- Notification system design patterns
- Database schema & API design
- Performance optimization techniques
- Real-world challenges & solutions

---

</div>

## 🚀 Quick Start

### Prerequisites
```bash
Flutter SDK 3.0+
Dart 3.0+
Android Studio / VS Code
Firebase Account (for FCM)
```

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
Full backend setup instructions: **[FastAPI Backend Repository](https://github.com/rudra2311-patel/FAST_API)**

---

## 📁 Project Structure

```
lib/
├── 🎨 core/
│   ├── theme/              # App theme & styling
│   └── constants/          # App-wide constants
│
├── 📊 models/              # Data models (Alert, Farm, Notification)
│
├── 📱 screens/
│   ├── auth/               # Login, Signup, Splash
│   ├── home/               # Dashboard, Navigation
│   ├── farms/              # Farm Management
│   ├── scans/              # Disease Detection
│   ├── alerts/             # Notifications & Alerts
│   ├── weather/            # Weather Forecast
│   └── profile/            # User Profile
│
├── ⚙️  services/
│   ├── api_services.dart        # REST API integration
│   ├── fcm_service.dart         # Push notifications
│   ├── farm_database_helper.dart # SQLite operations
│   └── translation_service.dart  # Multi-language support
│
├── 🎭 widgets/             # Reusable UI components
│   └── animated/           # Custom animations
│
└── main.dart               # App entry point
```

---

## 🔥 Technical Highlights

### 1️⃣ Offline-First Architecture
Built to work in rural areas with limited connectivity. ML model runs entirely on-device, with smart sync when online.

### 2️⃣ Dual Notification System
Combines local SQLite alerts (daily status) with backend FCM notifications (critical real-time alerts) for comprehensive coverage.

### 3️⃣ Smart Deduplication
24-hour window prevents alert spam — same condition + same farm = only one notification per day.

### 4️⃣ Real-Time Updates
WebSocket connection for instant weather updates, with automatic REST API fallback for reliability.

### 5️⃣ Scalable Backend
FastAPI + PostgreSQL + Redis architecture designed for production load with caching and session management.

---

## 🤝 Contributing

We welcome contributions! Here's how:

1. **Fork** the repository
2. Create a **feature branch**: `git checkout -b feature/AmazingFeature`
3. **Commit** your changes: `git commit -m 'Add AmazingFeature'`
4. **Push** to branch: `git push origin feature/AmazingFeature`
5. Open a **Pull Request**

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

## 👨‍💻 Connect With Me

**Rudra Patel** — Full-Stack Developer

[![Portfolio](https://img.shields.io/badge/🌐_Portfolio-rudrabuilds.me-00C7B7?style=for-the-badge)](https://rudrabuilds.me)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Rudra_Patel-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/rudra-patel-32859425b/)
[![GitHub](https://img.shields.io/badge/GitHub-rudra2311--patel-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/rudra2311-patel)
[![Email](https://img.shields.io/badge/Email-programmercreature%40gmail.com-D14836?style=for-the-badge&logo=gmail&logoColor=white)](mailto:programmercreature@gmail.com)

---

### ⭐ If you find this project valuable, give it a star!

*It helps others discover the project and motivates continued development*

---

<br>

**Built with ❤️ for farmers worldwide**

*Transforming agriculture through technology, one farm at a time*

</div>
