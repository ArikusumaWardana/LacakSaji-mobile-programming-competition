-- LacakSaji Reset & Expanded Seed Data
-- Includes 2 SPPG Kitchens, 4 Schools (3 approved + 1 pending),
-- 12 Food Batches (including multiple batches sealed 4-5+ hours earlier for RED Danger-Zone testing),
-- 7 Inspections, 5 Bank Sampel Vaults, 8 Plate-Waste Logs, and 1 Historical Resolved Cluster Alert.

begin;

truncate table
  public.alert_acknowledgements,
  public.cluster_alerts,
  public.plate_waste_logs,
  public.sample_vaults,
  public.school_inspections,
  public.food_batches,
  public.schools,
  public.sppg_kitchens,
  public.profiles,
  public.official_sppg_registry
cascade;

delete from auth.users
where id not in (
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000003',
  '20000000-0000-4000-8000-000000000004',
  '30000000-0000-4000-8000-000000000001'
);

-- 1. Official SPPG Registry (2 claimed + 4 unclaimed sandbox activation codes)
insert into public.official_sppg_registry (
  reg_number,
  activation_pin_hash,
  official_name,
  region_name,
  is_claimed,
  claimed_at
)
values
  ('BGN-PWT-2026-001', extensions.crypt('112233', extensions.gen_salt('bf')), 'SPPG Purwokerto Utara', 'Banyumas, Jawa Tengah', true, now()),
  ('BGN-PWT-2026-002', extensions.crypt('223344', extensions.gen_salt('bf')), 'SPPG Sokaraja', 'Banyumas, Jawa Tengah', true, now()),
  ('BGN-SBX-2026-101', extensions.crypt('101010', extensions.gen_salt('bf')), 'SPPG Banyumas Barat (Sandbox 1)', 'Banyumas, Jawa Tengah', false, null),
  ('BGN-SBX-2026-102', extensions.crypt('202020', extensions.gen_salt('bf')), 'SPPG Kembaran (Sandbox 2)', 'Banyumas, Jawa Tengah', false, null),
  ('BGN-SBX-2026-103', extensions.crypt('303030', extensions.gen_salt('bf')), 'SPPG Ajibarang (Sandbox 3)', 'Banyumas, Jawa Tengah', false, null),
  ('BGN-SBX-2026-104', extensions.crypt('404040', extensions.gen_salt('bf')), 'SPPG Wangon (Sandbox 4)', 'Banyumas, Jawa Tengah', false, null)
on conflict (reg_number) do nothing;

-- 2. Demo Auth Users & Identities (Password: LacakSaji2026!)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at,
  is_sso_user, is_anonymous
)
values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'dapur.a@lacaksaji.id', extensions.crypt('LacakSaji2026!', extensions.gen_salt('bf')), now(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Petugas SPPG Purwokerto Utara"}'::jsonb, false, now(), now(), false, false),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'dapur.b@lacaksaji.id', extensions.crypt('LacakSaji2026!', extensions.gen_salt('bf')), now(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Petugas SPPG Sokaraja"}'::jsonb, false, now(), now(), false, false),
  ('00000000-0000-0000-0000-000000000000', '20000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'sdn1.pwt@lacaksaji.id', extensions.crypt('LacakSaji2026!', extensions.gen_salt('bf')), now(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"PIC SDN 1 Purwokerto"}'::jsonb, false, now(), now(), false, false),
  ('00000000-0000-0000-0000-000000000000', '20000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'sdn2.pwt@lacaksaji.id', extensions.crypt('LacakSaji2026!', extensions.gen_salt('bf')), now(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"PIC SDN 2 Purwokerto"}'::jsonb, false, now(), now(), false, false),
  ('00000000-0000-0000-0000-000000000000', '20000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'sdn1.sokaraja@lacaksaji.id', extensions.crypt('LacakSaji2026!', extensions.gen_salt('bf')), now(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"PIC SDN 1 Sokaraja"}'::jsonb, false, now(), now(), false, false),
  ('00000000-0000-0000-0000-000000000000', '20000000-0000-4000-8000-000000000004', 'authenticated', 'authenticated', 'sdn4.pwt@lacaksaji.id', extensions.crypt('LacakSaji2026!', extensions.gen_salt('bf')), now(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Bapak Wahyu (PIC SDN 4 Purwokerto)"}'::jsonb, false, now(), now(), false, false),
  ('00000000-0000-0000-0000-000000000000', '30000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'pengawas.bgn@lacaksaji.id', extensions.crypt('LacakSaji2026!', extensions.gen_salt('bf')), now(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Pengawas BGN Banyumas"}'::jsonb, false, now(), now(), false, false)
on conflict (id) do nothing;

insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
values
  ('10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '{"sub":"10000000-0000-4000-8000-000000000001","email":"dapur.a@lacaksaji.id","email_verified":true,"phone_verified":false}'::jsonb, 'email', '10000000-0000-4000-8000-000000000001', now(), now(), now()),
  ('10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', '{"sub":"10000000-0000-4000-8000-000000000002","email":"dapur.b@lacaksaji.id","email_verified":true,"phone_verified":false}'::jsonb, 'email', '10000000-0000-4000-8000-000000000002', now(), now(), now()),
  ('20000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '{"sub":"20000000-0000-4000-8000-000000000001","email":"sdn1.pwt@lacaksaji.id","email_verified":true,"phone_verified":false}'::jsonb, 'email', '20000000-0000-4000-8000-000000000001', now(), now(), now()),
  ('20000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', '{"sub":"20000000-0000-4000-8000-000000000002","email":"sdn2.pwt@lacaksaji.id","email_verified":true,"phone_verified":false}'::jsonb, 'email', '20000000-0000-4000-8000-000000000002', now(), now(), now()),
  ('20000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000003', '{"sub":"20000000-0000-4000-8000-000000000003","email":"sdn1.sokaraja@lacaksaji.id","email_verified":true,"phone_verified":false}'::jsonb, 'email', '20000000-0000-4000-8000-000000000003', now(), now(), now()),
  ('20000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000004', '{"sub":"20000000-0000-4000-8000-000000000004","email":"sdn4.pwt@lacaksaji.id","email_verified":true,"phone_verified":false}'::jsonb, 'email', '20000000-0000-4000-8000-000000000004', now(), now(), now()),
  ('30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', '{"sub":"30000000-0000-4000-8000-000000000001","email":"pengawas.bgn@lacaksaji.id","email_verified":true,"phone_verified":false}'::jsonb, 'email', '30000000-0000-4000-8000-000000000001', now(), now(), now())
on conflict (id) do nothing;

-- 3. Public Profiles
insert into public.profiles (id, role, full_name)
values
  ('10000000-0000-4000-8000-000000000001', 'kitchen', 'Ibu Ratna (Petugas SPPG Purwokerto Utara)'),
  ('10000000-0000-4000-8000-000000000002', 'kitchen', 'Bapak Hendra (Petugas SPPG Sokaraja)'),
  ('20000000-0000-4000-8000-000000000001', 'school', 'Ibu Siti (PIC SDN 1 Purwokerto)'),
  ('20000000-0000-4000-8000-000000000002', 'school', 'Bapak Agus (PIC SDN 2 Purwokerto)'),
  ('20000000-0000-4000-8000-000000000003', 'school', 'Ibu Dewi (PIC SDN 1 Sokaraja)'),
  ('20000000-0000-4000-8000-000000000004', 'school', 'Bapak Wahyu (PIC SDN 4 Purwokerto)'),
  ('30000000-0000-4000-8000-000000000001', 'supervisor', 'Pengawas BGN Wilayah Banyumas');

-- 4. Two SPPG Kitchens (with valid Ed25519 public keys matching seeded QR signatures)
insert into public.sppg_kitchens (id, owner_user_id, reg_number, invite_code, name, adm4_code, lat, lng, public_key, is_verified)
values
  ('a1000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'BGN-PWT-2026-001', 'SPPG-PWT-01', 'SPPG Purwokerto Utara', '33.02.26.1001', -7.4126, 109.2345, 'C3YKuS6l/aLw84uHmW2ot6vDNXBbaIOeKj0EZ0Mb3u8=', true),
  ('a2000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'BGN-PWT-2026-002', 'SPPG-PWT-02', 'SPPG Sokaraja', '33.02.18.2005', -7.4561, 109.2869, 'MiNAtV+jOhbDyvFtfXl5BheY+RhDD8R94JQy+4HnTrk=', true);

-- 5. Four Schools (3 approved + 1 pending awaiting kitchen approval)
insert into public.schools (id, owner_user_id, sppg_id, npsn, name, adm4_code, lat, lng, puskesmas_wa, verification_status)
values
  ('b1000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', '20301901', 'SDN 1 Purwokerto', '33.02.26.1001', -7.4188, 109.2351, '628112800001', 'approved'),
  ('b1000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', '20301902', 'SDN 2 Purwokerto', '33.02.26.1003', -7.4215, 109.2402, '628112800002', 'approved'),
  ('b2000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000002', '20302101', 'SDN 1 Sokaraja', '33.02.18.2005', -7.4589, 109.2904, '628112800003', 'approved'),
  ('b1000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001', '20301904', 'SDN 4 Purwokerto', '33.02.26.1004', -7.4152, 109.2421, '628112800004', 'pending');

-- 6. Twelve Food Batches (includes today's old-hour UNSAFE batches, YELLOW batch, fresh GREEN batches, and 1-3d history)
insert into public.food_batches (id, sppg_id, batch_code, menu_name, portion_count, risk_category, sealed_at, timestamp_source, packaging_photo_url, signature_b64)
values
  ('c1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'BCH-2611-P01', 'Nasi Ayam Suwir Kuah Santan & Tumis Kacang', 160, 'HIGH', '2026-11-21T08:33:37.000Z'::timestamptz, 'server_verified', null, 'AKGChkC99fmoSzFsWiB7xPnIv38q97HiRjb1ZliP++eCChrXl2dU2TkVxOLhS9TBn8hBkLKQIxpAS91UozfrAA=='),
  ('c1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'BCH-2611-P02', 'Nasi Goreng Kampung Telur Dadar & Acar', 150, 'MEDIUM', '2026-11-21T08:48:37.000Z'::timestamptz, 'server_verified', null, 'zn3bVlLouJ9oaA57MAQfAkwgCZBQkm8Q2riGGFlqyqXQppNZFx4xpTxz0O4qqlr+WQWaxSOjU+7gmKLe6ESQCQ=='),
  ('c1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000001', 'BCH-2611-P03', 'Nasi Kari Ayam Santan & Sayur Buncis', 145, 'HIGH', '2026-11-21T09:38:37.000Z'::timestamptz, 'server_verified', null, 'CBJd4sMeB2BsPQADVuKvBu8grUYhTpErrXXymi19stoLOEKsyIP4uYtoNy51rqj5HgBbUpvz9XJN5TAxLWTUAg=='),
  ('c1000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001', 'BCH-2611-P04', 'Nasi Soto Ayam Bening & Jeruk', 165, 'HIGH', '2026-11-21T11:58:37.000Z'::timestamptz, 'server_verified', null, '4M9Tp2ZOD90pk9aYkYTG4bombSKregHUG8MNlrdssJUNNyH31EPbppBaNni2ysFRRtf0IRavZzU6dwxLY+gTBw=='),
  ('c1000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000001', 'BCH-2611-P05', 'Nasi Ayam Panggang Kecap, Tumis Kangkung & Pisang', 170, 'MEDIUM', '2026-11-21T13:13:37.000Z'::timestamptz, 'server_verified', null, 'AEzNdYtw9fCQSEZJEN1kz5i/wnivIIEbGBL2yCYBAsha58OYZHGOMMwAGFOzvoUGnOWaQLiAr4eu2ygfFkwbDw=='),
  ('c1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000001', 'BCH-2611-P06', 'Roti Gandum Isi Telur, Susu UHT & Apel', 180, 'LOW', '2026-11-21T13:23:37.000Z'::timestamptz, 'server_verified', null, 'oBmjc9GIzPyvEA2nDBdugIqwIN7bzs0Qd8ot3qmIzA6y+x1wDhlOsGdeWwWeKdf55yUiak6eeGTlxxU/rlXpAQ=='),
  ('c2000000-0000-4000-8000-000000000007', 'a2000000-0000-4000-8000-000000000002', 'BCH-2611-S01', 'Nasi Rendang Daging Santan & Daun Singkong', 155, 'HIGH', '2026-11-21T09:03:37.000Z'::timestamptz, 'server_verified', null, 'RzSZMtsBOHGOsAwBL/1qTvwDEBHWhmk0QNx19fRv0hp2THw5I9MALOHdISEUn9wa2YDyc3/qby+dhDs+AwqgDg=='),
  ('c2000000-0000-4000-8000-000000000008', 'a2000000-0000-4000-8000-000000000002', 'BCH-2611-S02', 'Nasi Ikan Nila Goreng & Sayur Asam', 150, 'MEDIUM', '2026-11-21T13:08:37.000Z'::timestamptz, 'server_verified', null, 'Ofahdz6nollU5SJpfD0tFLxxFI3q4o2g2t8WuAoCBCzL2svFzc2BXAYS7BOnDIuPlPFeMVbWjQCTlBNxs07RAg=='),
  ('c1000000-0000-4000-8000-000000000009', 'a1000000-0000-4000-8000-000000000001', 'BCH-2611-H01', 'Nasi Ayam Goreng & Tumis Buncis', 160, 'MEDIUM', '2026-11-20T11:48:37.000Z'::timestamptz, 'server_verified', null, 'iGRjFI7PQq3avIilUcioWpoACekDqM9dou7SMoeZ2NkZ7lrGHW5oB+ki3GPBtKvJQiaoccgoZMHgSg+bcLXWCg=='),
  ('c1000000-0000-4000-8000-000000000010', 'a1000000-0000-4000-8000-000000000001', 'BCH-2611-H02', 'Nasi Soto Ayam Santan & Pisang', 150, 'HIGH', '2026-11-19T12:48:37.000Z'::timestamptz, 'server_verified', null, '/pqFhKEwOao5dpy5/gpBSGi10nv3AfX8uzinn+nQL+rq8Rp5ZAOCQJv7zM4FsGLE9AQEJJEEZXbZ4zfZjQaSDg=='),
  ('c1000000-0000-4000-8000-000000000011', 'a1000000-0000-4000-8000-000000000001', 'BCH-2611-H03', 'Nasi Telur Balado & Cah Sawi', 155, 'MEDIUM', '2026-11-18T13:48:37.000Z'::timestamptz, 'server_verified', null, 'mYiIUgNjjNX9AutvhytuNZ6dZetO8K6NoSjXdUBCDO9PCSLU4biuW9I0Jzymuo2N6mBs5PiXVDcDCq+SAAohAA=='),
  ('c2000000-0000-4000-8000-000000000012', 'a2000000-0000-4000-8000-000000000002', 'BCH-2611-H04', 'Nasi Semur Daging & Tumis Wortel', 140, 'HIGH', '2026-11-20T10:48:37.000Z'::timestamptz, 'server_verified', null, '16USVWgRZcp0WOABpEKHX1/cxBavbEtYU7GP7TbRTary02E1tXEGoQn/0mzPU8BXM364mLh2QEwoaKZ+F7I+Cg==');

-- 7. School Inspections (7 records: today's RED/YELLOW/GREEN + historical)
insert into public.school_inspections (
  id, batch_id, school_id, scanned_at, elapsed_minutes, bmkg_temp_c, bmkg_source,
  danger_status, gps_within_radius, sample_photo_url, tflite_label, tflite_confidence,
  gemini_summary_json, manual_smell_ok, manual_visual_ok, manual_pack_ok, final_decision, created_at
)
values
  ('d1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000001', '2026-11-21T13:40:00.000Z'::timestamptz, 16, 29.4, 'live', 'GREEN', true, null, 'fresh_likely', 0.945, '{"summary":"Kemasan rapi, roti dan susu UHT dalam kondisi baik dan segar."}'::jsonb, true, true, true, 'APPROVED', '2026-11-21T13:40:00.000Z'::timestamptz),
  ('d1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000002', '2026-11-21T13:35:00.000Z'::timestamptz, 236, 32.6, 'live', 'RED', true, null, 'suspicious_discoloration', 0.780, '{"summary":"Durasi pengiriman 236 menit melewati batas aman makanan bersantan dan kuah agak berlendir."}'::jsonb, false, false, true, 'REJECTED', '2026-11-21T13:35:00.000Z'::timestamptz),
  ('d1000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000008', 'b2000000-0000-4000-8000-000000000003', '2026-11-21T13:42:00.000Z'::timestamptz, 33, 30.2, 'live', 'GREEN', true, null, 'fresh_likely', 0.920, '{"summary":"Ikan nila goreng renyah dan sayur asam masih hangat dan segar."}'::jsonb, true, true, true, 'APPROVED', '2026-11-21T13:42:00.000Z'::timestamptz),
  ('d1000000-0000-4000-8000-000000000004', 'c1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000001', '2026-11-20T12:30:00.000Z'::timestamptz, 41, 31.2, 'live', 'GREEN', true, null, 'fresh_likely', 0.942, '{"summary":"Kondisi makanan segar dan kemasan utuh."}'::jsonb, true, true, true, 'APPROVED', '2026-11-20T12:30:00.000Z'::timestamptz),
  ('d1000000-0000-4000-8000-000000000005', 'c1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000002', '2026-11-20T13:55:00.000Z'::timestamptz, 126, 32.4, 'live', 'YELLOW', true, null, 'fresh_likely', 0.880, '{"summary":"Durasi mulai mendekati batas kuning, perlu dicek ketat sebelum dibagikan."}'::jsonb, true, true, true, 'APPROVED', '2026-11-20T13:55:00.000Z'::timestamptz),
  ('d1000000-0000-4000-8000-000000000006', 'c1000000-0000-4000-8000-000000000010', 'b1000000-0000-4000-8000-000000000001', '2026-11-19T13:35:00.000Z'::timestamptz, 46, 31.8, 'live', 'GREEN', true, null, 'fresh_likely', 0.915, '{"summary":"Kondisi soto segar, suhu pengiriman terjaga."}'::jsonb, true, true, true, 'APPROVED', '2026-11-19T13:35:00.000Z'::timestamptz),
  ('d1000000-0000-4000-8000-000000000007', 'c2000000-0000-4000-8000-000000000012', 'b2000000-0000-4000-8000-000000000003', '2026-11-20T11:30:00.000Z'::timestamptz, 41, 30.8, 'live', 'GREEN', true, null, 'fresh_likely', 0.930, '{"summary":"Semur daging dan tumis wortel layak konsumsi."}'::jsonb, true, true, true, 'APPROVED', '2026-11-20T11:30:00.000Z'::timestamptz);

-- 8. Bank Sampel 48 Jam (4 active samples across schools + 1 disposed older sample)
insert into public.sample_vaults (id, inspection_id, school_id, label_code, stored_at, expires_at, status)
values
  ('f1000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'SMP-2611-21P06', '2026-11-21T13:41:00.000Z'::timestamptz, '2026-11-23T13:41:00.000Z'::timestamptz, 'active'),
  ('f1000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000001', 'SMP-2611-20H01', '2026-11-20T12:32:00.000Z'::timestamptz, '2026-11-22T12:32:00.000Z'::timestamptz, 'active'),
  ('f1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000002', 'SMP-2611-20S02', '2026-11-20T13:57:00.000Z'::timestamptz, '2026-11-22T13:57:00.000Z'::timestamptz, 'active'),
  ('f1000000-0000-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000003', 'SMP-2611-21SKR', '2026-11-21T13:43:00.000Z'::timestamptz, '2026-11-23T13:43:00.000Z'::timestamptz, 'active'),
  ('f1000000-0000-4000-8000-000000000005', 'd1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000001', 'SMP-2611-19H02', '2026-11-19T13:37:00.000Z'::timestamptz, '2026-11-21T13:37:00.000Z'::timestamptz, 'disposed');

-- 9. Plate-Waste Logs (8 records across SPPG Purwokerto Utara & Sokaraja)
insert into public.plate_waste_logs (id, batch_id, school_id, sppg_id, carb_waste_pct, protein_waste_pct, veg_waste_pct, photo_urls, ai_assisted, created_at)
values
  ('e1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 0, 0, 25, '[]'::jsonb, true, '2026-11-21T13:45:00.000Z'::timestamptz),
  ('e1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 25, 0, 50, '[]'::jsonb, true, '2026-11-20T14:15:00.000Z'::timestamptz),
  ('e1000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 25, 25, 75, '[]'::jsonb, true, '2026-11-20T14:40:00.000Z'::timestamptz),
  ('e1000000-0000-4000-8000-000000000004', 'c1000000-0000-4000-8000-000000000010', 'b1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 0, 25, 50, '[]'::jsonb, true, '2026-11-19T14:20:00.000Z'::timestamptz),
  ('e1000000-0000-4000-8000-000000000005', 'c1000000-0000-4000-8000-000000000011', 'b1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 25, 0, 25, '[]'::jsonb, false, '2026-11-18T14:30:00.000Z'::timestamptz),
  ('e1000000-0000-4000-8000-000000000006', 'c1000000-0000-4000-8000-000000000011', 'b1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 50, 25, 75, '[]'::jsonb, true, '2026-11-18T14:45:00.000Z'::timestamptz),
  ('e2000000-0000-4000-8000-000000000007', 'c2000000-0000-4000-8000-000000000008', 'b2000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000002', 0, 0, 25, '[]'::jsonb, true, '2026-11-21T13:47:00.000Z'::timestamptz),
  ('e2000000-0000-4000-8000-000000000008', 'c2000000-0000-4000-8000-000000000012', 'b2000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000002', 25, 25, 50, '[]'::jsonb, true, '2026-11-20T12:15:00.000Z'::timestamptz);

-- 10. Historical Resolved Cluster Alert (so Supervisor Dashboard is populated without blocking School UI on launch)
insert into public.cluster_alerts (
  id, sppg_id, batch_id, reporter_school_id, stage, symptom_count, notes,
  broadcast_enabled, sample_label_code, pdf_dispatched, created_at
)
values
  (
    'a9000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'c1000000-0000-4000-8000-000000000010',
    'b1000000-0000-4000-8000-000000000002',
    'pre_consumption',
    0,
    'Kuah soto tercium sedikit asam saat pengecekan awal, distribusi ditahan sesuai prosedur.',
    true,
    'SMP-2611-19H02',
    true,
    '2026-11-19T12:55:00.000Z'::timestamptz
  );

insert into public.alert_acknowledgements (id, alert_id, school_id, acknowledged_at)
values
  ('a9100000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', '2026-11-19T12:57:00.000Z'::timestamptz);

commit;
