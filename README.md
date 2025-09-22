# Jia Inventory System

An inventory management system designed to simplify stock tracking, supplier management, and order handling.  
This project was developed as part of a learning and practical implementation of supply chain and inventory management concepts.  

---

## 📌 Features

- 📦 Manage products (add, edit, delete, search) 
- 📊 Track incoming and outgoing stock  
- 📈 Simple reports and analytics
- 🔐 User authentication
- 📂 Data storage with online database (depending on Supabases (for image storage) and firebase (for basic data))

---

## 🚀 Setup & Installation

1. **Clone the repository**  
   ```bash
   git clone https://github.com/siangloh/Jia-Inventory-System.git
2. **Install dependencies**
   ```bash
   flutter pub get
3. **Run the application**
    ```bash
    flutter run

## 🖥️ Usage
1. Launch the app on Android, iOS, or web
2. Sign in
3. Navigate between modules via the bottom navigation bar:
   - Dashboard – Dashboard overview
   - Products – Manage product details
   - Users - Add or update user information
   - Order - Add or update PO form
   - Warehouse - warehouse products adjustment, warehouse overview, and product inbound and outbound management
   - Part Issues - Product Issue and request
4. Track product inventory in real-time

## 🛠️ Tech Stack
- Framework: Flutter
- Backend / Database: Firebase Firestore and supabases
- Language: Dart
- Other tools: Android Studio
  
## 📂 Folder Structure
```text
Jia-Inventory-System/
├── android/         # Native Android project files (Gradle configs, manifests)  
├── ios/             # Native iOS project files (Xcode configs, plist)  
├── lib/             # Main Flutter source code  
│   ├── dao/         # Data Access Objects (database queries, business logic)  
│   ├── models/      # Data models (e.g., Product)  
│   ├── screens/     # UI screens / pages of the app  
│   ├── services/    # Business logic, APIs, and external service integration  
│   ├── widgets/     # Reusable UI components (buttons, navigation, headers)  
│   └── main.dart    # Application entry point  
├── pubspec.yaml     # Project dependencies and assets  
└── README.md        # Project documentation  
```

## 🤝 Contributors

A big thank you to the following people who have contributed to the development of **Jia Inventory System**:

1. **[Loh Keat Siang](https://github.com/siangloh)** – Project Owner, Lead Developer, Product Management, Dashboard, System Integration, Sidebar & Header  
2. **[Yeap Zi Jia](https://github.com/yeapzijia)** – Warehouse Management Module  
3. **[Jacky Kong Kah Wei](https://github.com/jacky0981)** – Part Issues Module  
4. **[Lee Gim Sheng](https://github.com/kelsongitlee)** – Product Inbound & Outbound Management
