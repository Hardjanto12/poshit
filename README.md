# PoSHIT

A modern, cross-platform Point of Sale (POS) system built with Flutter. PoSHIT is designed for small businesses and shops, providing inventory, transaction, and reporting management with support for Bluetooth receipt printers.

## Features

- **User Authentication**: Secure login system with default admin account creation on first run.
- **Product Management**: Add, edit, delete, and list products with SKU and inventory tracking options.
- **Transaction Processing**: Create new sales, manage a cart, calculate change, and record transactions.
- **Transaction History**: View, filter, and export transaction history. Generate PDF reports.
- **Reporting Dashboard**: Daily revenue, transaction summaries, and top-selling products.
- **Receipt Printing**: Print receipts via Bluetooth printers (ESC/POS compatible) or generate PDF receipts.
- **Settings**: Customize business name, receipt footer, printer type, inventory/SKU options, and more.
- **Multi-Platform**: Runs on Windows, Linux, macOS, Android, and iOS (with platform-specific printer support).
- **API Integration**: Connects to a Go-based backend API for data persistence and multi-device sync.

## Screenshots

_Add screenshots here if available_

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.8.1 or later)
- A running Go API backend (see `lib/services/api_service.dart` for endpoint details)
- (Optional) Bluetooth ESC/POS printer for receipt printing

### Installation

1. **Clone the repository:**
   ```sh
   git clone <your-repo-url>
   cd poshit
   ```
2. **Install dependencies:**
   ```sh
   flutter pub get
   ```
3. **Configure API Endpoint:**
   - By default, the API base URL is `http://localhost:3000/api/` (see `lib/services/api_service.dart`).
   - Update this if your backend runs elsewhere.
4. **Run the app:**
   - For desktop:
     ```sh
     flutter run -d windows   # or macos, linux
     ```
   - For mobile:
     ```sh
     flutter run -d android   # or ios
     ```

### Database

- The backend uses MariaDB/MySQL. See `database_schema.sql` for the schema.

## Usage

- On first run, a default admin account is created: `admin` / `admin123`.
- Log in, add products, and start processing transactions.
- Access settings from the drawer to configure business info and printer.
- Use the reporting dashboard for sales analytics.

## Tech Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Go (API, not included in this repo)
- **Database:** MariaDB/MySQL (see `database_schema.sql`)
- **Bluetooth Printing:** [bluetooth_print_plus](https://pub.dev/packages/bluetooth_print_plus), [esc_pos_utils_plus](https://pub.dev/packages/esc_pos_utils_plus)
- **PDF Generation:** [pdf](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing)

## Key Packages

- `sqflite`, `sqflite_common_ffi` — Local database (for desktop/mobile)
- `http` — API requests
- `shared_preferences` — Local storage for session/settings
- `intl` — Currency/date formatting
- `crypto` — Password hashing
- `collection`, `path`, `path_provider`, `share_plus`, `cupertino_icons`

## Project Structure

- `lib/`
  - `main.dart` — App entry point
  - `models/` — Data models (User, Product, Transaction, etc.)
  - `screens/` — UI screens (login, products, transactions, settings, etc.)
  - `services/` — Business logic, API, and data services
  - `utils/` — Utilities (currency formatting, etc.)
- `database_schema.sql` — SQL schema for backend database

## Customization

- Change the API endpoint in `lib/services/api_service.dart` if needed.
- Update business info and receipt settings in the app's Settings screen.

## License

_Specify your license here_

---

_PoSHIT — Simple, modern POS for everyone._
