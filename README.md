# LacakSaji

A Flutter-based Android application for food safety verification and food waste reduction across Indonesia's Free Nutritious Meal (*Makan Bergizi Gratis* / MBG) distribution chain, designed in alignment with National Nutrition Agency Regulation (*Perbagi*) No. 4 of 2026.

## Project Overview

LacakSaji operates as an early-prevention (*pre-consumption*) gate between catering kitchens (*Satuan Pelayanan Pemenuhan Gizi* / SPPG) and recipient schools. It ensures delivered meals remain within safe time-temperature limits, pass organoleptic inspections, maintain 48-hour archive sample records, and trigger rapid cross-school emergency alerts if food spoilage or contamination is detected.

## Key Features

- **Offline-Verifiable Ed25519 QR Passport:** Locks the kitchen packaging timestamp (`sealed_at`) with an asymmetric digital signature to prevent time tampering (*anti-backdating*) and allow verification at schools without an internet connection.
- **Risk & BMKG Weather-Based Danger-Zone Clock:** Dynamically calculates safe distribution windows using menu risk categories (`HIGH`, `MEDIUM`, `LOW`), transit duration, and local sub-district (`adm4`) temperature data from the BMKG public API, complete with offline caching and fallback.
- **3-Layer Hybrid Organoleptic Audit:** Combines fast on-device inference (TFLite INT8), cloud visual enrichment (Gemini Flash via Supabase Edge Function when online), and a quick manual organoleptic checklist completed by school PICs.
- **2x24-Hour Sample Bank Vault:** Tracks 1 archived meal portion stored below 5 degrees Celsius with a unique label code and a 48-hour local notification reminder for laboratory testing compliance.
- **Dual-Channel Cluster Alert & 1-Tap KLB Report:** Broadcasts real-time emergency alerts (Supabase Realtime and FCM High-Priority) to all other schools supplied by the same SPPG kitchen, while generating a 1-page KLB Incident Report PDF for the nearest community health center (*Puskesmas*) without requiring them to install the app.
- **Plate-Waste Loop:** Scans leftover meal trays to estimate uneaten portions and help SPPG kitchens reduce daily food waste.

## User Roles

- **SPPG Kitchen Staff:** Whitelist-based account activation, school link approvals, daily batch QR seal generation, distribution monitoring, and plate-waste analytics.
- **School Teacher / PIC:** Registration via NPSN, batch QR scanning, hybrid organoleptic inspection, 48-hour sample bank logging, plate-waste scanning, and triggering Cluster Alerts or KLB PDF dispatches to Puskesmas.
- **Courier & Puskesmas (Non-Login):** Couriers present the digital delivery card or printed QR label; Puskesmas staff receive emergency summaries and KLB PDF reports directly via WhatsApp or Email.
- **BGN / Health Office Supervisor:** Read-only oversight across registered kitchens and schools.

## Tech Stack

- **Frontend:** Flutter (Material Design 3), `go_router`, `flutter_riverpod`
- **Offline-First Storage & Sync:** `drift` (SQLite), `workmanager`, `connectivity_plus`
- **Cryptography & QR:** `cryptography` (Ed25519), `qr_flutter`, `mobile_scanner`
- **Edge AI & Vision:** `tflite_flutter` (on-device INT8), Gemini Flash API (via Supabase Edge Function)
- **Backend & Notifications:** Supabase (Auth, Postgres, Realtime, Storage, Edge Functions), Firebase Cloud Messaging (FCM), `flutter_local_notifications`
- **Weather & Utilities:** BMKG Public API (`adm4`), `geolocator`, `pdf`, `share_plus`, `url_launcher`
