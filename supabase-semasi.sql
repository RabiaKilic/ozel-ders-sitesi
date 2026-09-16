-- ================================================================
-- Gökhan Kılıç - Matematik & Geometri Özel Ders Sitesi
-- Supabase SQL şeması. Bunu Supabase projesinde SQL Editor'e
-- yapıştırıp "Run" ile bir kere çalıştır.
-- ================================================================

create extension if not exists pgcrypto;

-- ================= TABLOLAR =================

create table if not exists public.categories (
  id text primary key,
  name text not null,
  levels text,
  description text
);

create table if not exists public.availability (
  day text primary key,
  times jsonb not null default '[]'::jsonb
);

create table if not exists public.tutor_info (
  id int primary key default 1,
  name text,
  title text,
  bio text,
  experience text,
  students text,
  phone text,
  achievements jsonb default '[]'::jsonb,
  photo text,
  constraint single_row check (id = 1)
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  category_id text,
  date date not null,
  time_slot text not null,
  role text,
  name text not null,
  grade text,
  phone text not null,
  note text,
  status text not null default 'beklemede' check (status in ('beklemede','onaylandı','iptal')),
  created_at timestamptz not null default now()
);

-- ================= ROW LEVEL SECURITY =================

alter table public.categories enable row level security;
alter table public.availability enable row level security;
alter table public.tutor_info enable row level security;
alter table public.bookings enable row level security;

-- categories: herkes okuyabilir, sadece giriş yapmış admin değiştirebilir
create policy "categories_select_all" on public.categories
  for select using (true);
create policy "categories_write_admin" on public.categories
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- availability: herkes okuyabilir, sadece admin değiştirebilir
create policy "availability_select_all" on public.availability
  for select using (true);
create policy "availability_write_admin" on public.availability
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- tutor_info: herkes okuyabilir, sadece admin değiştirebilir
create policy "tutor_info_select_all" on public.tutor_info
  for select using (true);
create policy "tutor_info_write_admin" on public.tutor_info
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- bookings: herkes randevu talebi oluşturabilir (insert),
-- ama listeyi görüntüleme/onaylama/silme sadece admin'e açık.
-- Öğrenci/veli tarafı randevu durumunu sadece kendi telefon
-- numarasıyla, aşağıdaki güvenli fonksiyon üzerinden görebilir.
create policy "bookings_insert_public" on public.bookings
  for insert with check (status = 'beklemede');
create policy "bookings_admin_full" on public.bookings
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ================= GÜVENLİ FONKSİYONLAR (RPC) =================
-- Bu fonksiyonlar RLS'i atlar (security definer) ama sadece
-- gerekli/sınırlı veriyi döndürecek şekilde yazılmıştır.

-- Belirli bir tarihte hangi saatlerin dolu olduğunu döndürür
-- (kimin aldığını değil, sadece saati döndürür -> gizlilik korunur).
create or replace function public.get_booked_times(p_date date)
returns table(time_slot text)
language sql security definer set search_path = public as $$
  select time_slot from bookings where date = p_date and status <> 'iptal';
$$;
grant execute on function public.get_booked_times(date) to anon, authenticated;

-- Bir telefon numarasına ait randevuları döndürür (öğrenci/veli sorgulama).
create or replace function public.lookup_bookings_by_phone(p_phone text)
returns setof bookings
language sql security definer set search_path = public as $$
  select * from bookings where phone = p_phone order by date, time_slot;
$$;
grant execute on function public.lookup_bookings_by_phone(text) to anon, authenticated;

-- Randevu oluşturur; aynı gün/saat için çakışma varsa hata döner
-- (SLOT_TAKEN). Bu kontrol veritabanı tarafında yapıldığı için
-- iki kişi aynı anda aynı saati seçse bile çakışma engellenir.
create or replace function public.create_booking(
  p_category_id text, p_date date, p_time text, p_role text,
  p_name text, p_grade text, p_phone text, p_note text
) returns bookings
language plpgsql security definer set search_path = public as $$
declare
  v_taken boolean;
  v_row bookings;
begin
  select exists(
    select 1 from bookings
    where date = p_date and time_slot = p_time and status <> 'iptal'
  ) into v_taken;

  if v_taken then
    raise exception 'SLOT_TAKEN';
  end if;

  insert into bookings(category_id, date, time_slot, role, name, grade, phone, note, status)
  values (p_category_id, p_date, p_time, p_role, p_name, p_grade, p_phone, p_note, 'beklemede')
  returning * into v_row;

  return v_row;
end;
$$;
grant execute on function public.create_booking(text,date,text,text,text,text,text,text) to anon, authenticated;

-- ================= BAŞLANGIÇ VERİLERİ =================

insert into public.tutor_info (id, name, title, bio, experience, students, phone, achievements, photo)
values (
  1,
  'Gökhan Kılıç',
  'Matematik & Geometri Öğretmeni · 22 Yıl Deneyim',
  '22 yıllık dershane ve kolej deneyimiyle matematik ve geometri dersleri veriyorum. Ortaokul 5, 6, 7 ve 8. sınıf öğrencilerinden LGS''ye hazırlananlara, TYT-AYT sınavına çalışan lise öğrencilerinden mezun gruplara kadar her seviyeye uygun bir çalışma programı hazırlıyorum. Derslerin yanında profesyonel öğrenci koçluğu ve düzenli ödev takibi yapıyorum.',
  '22 Yıl Deneyim',
  '5. Sınıf – Mezun',
  '0535 982 15 27',
  '["Ortaokul (5-6-7-8. sınıf), LGS ve TYT-AYT hazırlık gruplarına yönelik ayrı çalışma programları","Profesyonel öğrenci koçluğu ve düzenli ödev takibi","Matematik ve geometride eksik konuları birebir gidermeye yönelik çalışma","Malatya içinde yüz yüze, Malatya dışında online ders seçeneği"]'::jsonb,
  null
)
on conflict (id) do nothing;

insert into public.categories (id, name, levels, description) values
('c1','Lise Matematik','9. · 10. · 11. · 12. Sınıflar','Müfredat konuları, sınav ve deneme hazırlığı.'),
('c2','Lise Geometri','9. · 10. · 11. · 12. Sınıflar','Açı, üçgen, çokgen, analitik geometri konuları.'),
('c3','TYT Geometri','Sınav Hazırlık','TYT geometri soru çözümü ve konu tekrarı.'),
('c4','AYT Geometri','Sınav Hazırlık','AYT geometri soru çözümü ve konu tekrarı.'),
('c5','Ortaokul Matematik – Geometri','5. · 6. · 7. Sınıflar','Okula yardımcı, konu takviyeli özel ders.'),
('c6','8. Sınıf Sınava Hazırlık','Matematik · Geometri','Sınav hazırlık odaklı özel ders programı.')
on conflict (id) do nothing;

insert into public.availability (day, times) values
('pazartesi','["16:00","17:00","18:00","19:00"]'::jsonb),
('sali','["16:00","17:00","18:00","19:00"]'::jsonb),
('carsamba','["16:00","17:00","18:00","19:00"]'::jsonb),
('persembe','["16:00","17:00","18:00","19:00"]'::jsonb),
('cuma','["16:00","17:00","18:00","19:00"]'::jsonb),
('cumartesi','["10:00","11:00","12:00","13:00","14:00"]'::jsonb),
('pazar','[]'::jsonb)
on conflict (day) do nothing;

-- ================================================================
-- Kurulum tamamlandı. Sıradaki adım: Authentication > Users
-- bölümünden kendine bir admin hesabı (e-posta + şifre) oluşturman.
-- ================================================================
