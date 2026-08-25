# 🚴 RideMate
**RideMate** is a modern, cross-platform Flutter application designed to simplify ride tracking, fuel expense calculations, bill splitting among friends, and ledger settlements. Whether you're commuting daily with colleagues, embarking on road trips with friends, or managing shared vehicle expenses, RideMate offers seamless tracking, real-time map visualization, UPI payment integration, and comprehensive report exports.
---
## 🌟 Key Features
* **🛰️ Live GPS & Route Tracking**
  * Real-time GPS ride tracking with route visualization using [OpenStreetMap](https://www.openstreetmap.org/) and `flutter_map`.
  * Accurate distance computation powered by Open Source Routing Machine (OSRM) and Geolocator.
  * Manual distance entry mode supported for quick logging.
* **⛽ Smart Fuel & Expense Calculation**
  * Calculates exact fuel consumption (in Liters) and monetary cost based on custom vehicle mileage (km/L) and current fuel prices (₹/L).
  * Supports multiple custom vehicles with default mileage and fuel settings.
* **👥 Fair Expense Splitting**
  * Split ride costs equally or set custom per-person shares among friends.
  * Multi-participant selection with real-time share preview.
* **📜 Settlement Ledger**
  * Complete financial ledger keeping track of net balances ("Who owes whom").
  * Add payment settlements to mark debts as settled.
  * Full friend-wise history of shared rides and payment records.
* **💳 UPI Payment Integration & Instant Sharing**
  * Direct UPI deep-linking support (`upi://pay`) for one-tap payments via Google Pay, PhonePe, Paytm, BHIM, etc.
  * Generate and share detailed WhatsApp settlement breakdowns with custom messages.
