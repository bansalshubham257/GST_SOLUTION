# GST Solution — Phase 1

> **The simplest GST invoicing + return preparation platform for Indian small businesses.**

Built with Flutter (Android-first) + Node.js/Express + PostgreSQL + Firebase Auth.

---

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Flutter 3.x (Dart ≥3.0)
- PostgreSQL 15+
- Firebase project

---

## 📦 Backend Setup

```bash
cd backend
cp .env.example .env        # Fill in your credentials
npm install
# Run DB migration
psql $DATABASE_URL < ../database/migrations/001_initial_schema.sql
npm run dev                  # Starts on :5000
```

### Environment Variables (`.env`)

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `FIREBASE_PRIVATE_KEY` | Firebase Admin private key |
| `FIREBASE_CLIENT_EMAIL` | Firebase Admin client email |
| `FIREBASE_STORAGE_BUCKET` | Firebase Storage bucket |
| `SUPABASE_URL` | Supabase project URL (for file uploads) |
| `SUPABASE_SERVICE_KEY` | Supabase service role key |
| `PORT` | Server port (default: 5000) |

---

## 📱 Flutter App Setup

```bash
cd flutter_app
flutter pub get
# Configure Firebase
flutterfire configure          # Generates lib/firebase_options.dart
flutter run                    # Android emulator/device
```

### Key Config
- **API URL**: Update `lib/core/constants/api_constants.dart` → `baseUrl`
- **Firebase**: Run `flutterfire configure` after setting up your Firebase project
- **Android emulator**: Default API URL is `http://10.0.2.2:5000/api/v1`

---

## 🏗️ Architecture

```
GST Solution/
├── backend/                    # Node.js / Express API
│   ├── server.js
│   └── src/
│       ├── config/             # DB, Firebase
│       ├── controllers/        # Business logic
│       ├── middleware/         # Auth, error handling
│       ├── routes/             # API routes
│       └── services/           # GST engine, Socket.IO, Storage
│
├── flutter_app/                # Flutter Android app
│   └── lib/
│       ├── core/               # Shared utilities
│       │   ├── constants/      # API & app constants
│       │   ├── network/        # Dio + interceptors
│       │   ├── router/         # go_router navigation
│       │   ├── storage/        # Hive + Secure storage
│       │   ├── theme/          # Material 3 theming
│       │   ├── utils/          # GST calculator, GSTIN validator
│       │   └── widgets/        # Reusable UI components
│       │
│       └── features/           # Feature-first modules
│           ├── auth/           # Firebase Auth (OTP, Google, Email)
│           ├── business_setup/ # Business profile
│           ├── dashboard/      # Stats, charts, recent invoices
│           ├── invoice/        # Create, view, PDF, export
│           ├── customer/       # CRM, ledger
│           ├── gst_reports/    # GSTR-1, GSTR-3B, Sales register
│           ├── gst_filing/     # Validation + JSON export
│           └── chat_support/   # In-app support + AI bot
│
└── database/
    └── migrations/
        └── 001_initial_schema.sql
```

---

## 📋 API Reference

Base URL: `http://localhost:5000/api/v1`

All authenticated routes require: `Authorization: Bearer <firebase_id_token>`

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/login` | Sync user after Firebase auth |
| GET | `/auth/me` | Get current user |
| POST | `/auth/logout` | Logout |

### Business
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/business` | Get business profile |
| POST | `/business/setup` | Create/update business |
| PATCH | `/business/logo` | Update logo URL |
| PATCH | `/business/settings` | Update settings |

### Invoices
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/invoices` | List (search, filter, paginate) |
| POST | `/invoices` | Create invoice |
| GET | `/invoices/:id` | Get single invoice |
| PUT | `/invoices/:id` | Update invoice |
| DELETE | `/invoices/:id` | Delete draft |
| POST | `/invoices/:id/cancel` | Cancel invoice |
| POST | `/invoices/:id/duplicate` | Duplicate invoice |

### Customers
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/customers` | List + search |
| POST | `/customers` | Add customer |
| GET | `/customers/:id` | Get customer |
| PUT | `/customers/:id` | Update customer |
| DELETE | `/customers/:id` | Soft delete |
| GET | `/customers/:id/invoices` | Customer invoices |
| GET | `/customers/:id/ledger` | Customer ledger |

### GST Reports
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/gst/summary` | Monthly GST summary |
| GET | `/gst/sales-register` | Sales register |
| GET | `/gst/tax-liability` | Tax liability |
| GET | `/gst/gstr1-draft` | GSTR-1 draft JSON |
| GET | `/gst/gstr3b-draft` | GSTR-3B summary |
| GET | `/gst/filing-checklist` | Validation checklist |
| GET | `/gst/generate-json` | Export filing JSON |
| GET | `/gst/export?format=excel` | Export Excel/PDF |
| POST | `/gst/validate` | Validate GSTIN |

### Dashboard
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/dashboard/stats` | Monthly stats |
| GET | `/dashboard/monthly-summary` | 12-month trend |
| GET | `/dashboard/recent-invoices` | Last 5 invoices |

### Products/Catalog
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/products` | List products |
| POST | `/products` | Add product |
| PUT | `/products/:id` | Update product |
| DELETE | `/products/:id` | Delete product |

### Chat Support
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/chat/rooms` | List chat rooms |
| POST | `/chat/rooms` | Create room |
| GET | `/chat/rooms/:id/messages` | Get messages |
| POST | `/chat/rooms/:id/messages` | Send message |
| POST | `/chat/ai-assist` | AI assistant |

---

## 💾 Database Schema

Key tables: `users`, `businesses`, `customers`, `invoices`, `invoice_line_items`, `products`, `gst_filing_history`, `chat_rooms`, `chat_messages`, `subscriptions`, `audit_logs`

Run migration: `psql $DATABASE_URL < database/migrations/001_initial_schema.sql`

---

## 📱 Flutter Screens

| Screen | Route | Description |
|--------|-------|-------------|
| Login | `/login` | OTP / Google / Email |
| OTP Verify | `/otp-verification` | OTP input |
| Business Setup | `/business-setup` | First-time setup |
| Dashboard | `/dashboard` | Stats, charts, quick actions |
| Invoice List | `/invoices` | All invoices + search/filter |
| Create Invoice | `/invoices/create` | New invoice with GST auto-calc |
| Invoice Detail | `/invoices/:id` | View / actions |
| Invoice Preview | `/invoices/:id/preview` | PDF preview / download |
| Customer List | `/customers` | All customers |
| Add Customer | `/customers/add` | New customer |
| Customer Detail | `/customers/:id` | Customer + ledger |
| GST Reports | `/gst-reports` | Reports hub |
| GSTR-1 | `/gst-reports/gstr1` | GSTR-1 draft |
| GSTR-3B | `/gst-reports/gstr3b` | GSTR-3B summary |
| GST Filing | `/gst-filing` | Validation + export |
| Chat Support | `/chat-support` | In-app support + AI |

---

## 🧮 GST Engine

The `GstCalculator` class (`lib/core/utils/gst_calculator.dart`) handles:

- **Intra-state**: CGST + SGST (each = GST/2)
- **Inter-state**: IGST (full GST rate)
- **GSTIN-based detection**: Compares first 2 digits (state code)
- **Slab-wise aggregation**: Groups items by GST rate
- **Round-off**: Auto rounds to nearest rupee
- **Amount in words**: Indian format (Lakh, Crore)

Supported rates: `0%`, `5%`, `12%`, `18%`, `28%`

### GSTIN Validation
```dart
final result = GstinValidator.validate('27AABCU9603R1ZX');
// result.isValid → true
// result.stateCode → '27' (Maharashtra)
```

---

## 🔐 Authentication Flow

```
User opens app
    → Firebase check (currentUser)
    → if logged in → check business setup → Dashboard
    → if not logged in → Login page

Login options:
    1. Mobile OTP  → verifyPhoneNumber → OTP page → Dashboard
    2. Google      → GoogleSignIn → Dashboard
    3. Email       → signInWithEmailAndPassword → Dashboard

Post-login:
    → POST /auth/login  (sync user to PostgreSQL)
    → GET /auth/me      (check business setup)
    → if no business → BusinessSetupPage
```

---

## 🗺️ User Flow

```
Sign Up / Login (Firebase Auth)
    ↓
Business Setup (name, GSTIN, PAN, address, logo)
    ↓
Dashboard (sales, GST collected, invoice count)
    ↓
Create Invoice → Add customer → Add items → Auto GST calc → Generate PDF
    ↓
Invoice stored → Dashboard auto-updates
    ↓
GST Reports → Monthly Summary → Slab-wise breakdown
    ↓
GST Filing → Validation checklist → Export JSON → Upload to GST Portal
```

---

## 📊 State Management (Riverpod)

| Provider | Usage |
|---|---|
| `authStateProvider` | Auth state (logged in, business setup) |
| `invoiceListProvider` | Invoice list with pagination |
| `invoiceDetailProvider(id)` | Single invoice |
| `createInvoiceProvider` | Create/update invoice |
| `customerListProvider` | Customer list |
| `dashboardStatsProvider` | Dashboard stats |
| `recentInvoicesProvider` | Recent 5 invoices |
| `gstMonthlySummaryProvider(month)` | GST summary |
| `gstr1Provider(month)` | GSTR-1 data |
| `gstFilingChecklistProvider` | Filing validation |
| `themeModeProvider` | Dark/light mode |

---

## 📡 Offline Support

- **Hive** caches invoices + customers locally
- API calls fall back to cache on network error
- Draft invoices saved locally
- Automatic sync when back online

---

## 🚢 Deployment

### Backend (Railway / Render)
1. Connect GitHub repo
2. Set environment variables
3. Add PostgreSQL plugin
4. Deploy → auto-starts on `npm start`

### Flutter (Android APK)
```bash
cd flutter_app
flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔮 Future Phases

- Phase 2: eInvoice integration (IRP API), WhatsApp notifications, payment tracking
- Phase 3: AI OCR bill scanning, inventory management, multi-user teams
- Phase 4: CA dashboard, direct GST portal API filing, desktop app

---

## 📝 License

MIT © 2026 GST Solution

