-- ================================================================
-- Gökhan Kılıç - Matematik & Geometri Özel Ders Sitesi
-- YENİ ÖZELLİKLER İÇİN GÜNCELLEME SCRİPTİ
-- Bunu Supabase SQL Editor'de "Run" ile çalıştır. Daha önce
-- kurulmuş bir veritabanının üzerine güvenle eklenir, mevcut
-- randevularını silmez.
-- ================================================================

-- 1) Haftalık tekrar eden randevuları takip etmek için yeni sütunlar
alter table public.bookings add column if not exists is_recurring boolean not null default false;
alter table public.bookings add column if not exists recurring_group_id uuid;

-- 2) Öğrencinin kendi randevusunu iptal edebilmesi (dersten 2 gün öncesine kadar)
--    Telefon numarası eşleşmezse veya 2 günden az kaldıysa hata döner.
create or replace function public.cancel_booking(p_id uuid, p_phone text)
returns bookings
language plpgsql security definer set search_path = public as $$
declare
  v_row bookings;
begin
  select * into v_row from bookings where id = p_id and phone = p_phone;

  if v_row.id is null then
    raise exception 'NOT_FOUND';
  end if;

  if v_row.date < (current_date + 2) then
    raise exception 'TOO_LATE';
  end if;

  update bookings set status = 'iptal' where id = p_id
  returning * into v_row;

  return v_row;
end;
$$;
grant execute on function public.cancel_booking(uuid, text) to anon, authenticated;

-- 3) Randevu saatlerini 09:00 - 21:00 arasına genişlet (her gün).
--    Cumartesi/Pazar dahil istemiyorsan, o satırları '[]'::jsonb yap
--    ya da siteye admin girip Müsaitlik sekmesinden elle kapatabilirsin.
insert into public.availability (day, times) values
('pazartesi','["09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00","19:00","20:00","21:00"]'::jsonb),
('sali',     '["09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00","19:00","20:00","21:00"]'::jsonb),
('carsamba', '["09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00","19:00","20:00","21:00"]'::jsonb),
('persembe', '["09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00","19:00","20:00","21:00"]'::jsonb),
('cuma',     '["09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00","19:00","20:00","21:00"]'::jsonb),
('cumartesi','["09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00","19:00","20:00","21:00"]'::jsonb),
('pazar',    '["09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00","19:00","20:00","21:00"]'::jsonb)
on conflict (day) do update set times = excluded.times;

-- ================================================================
-- Tamamlandı. Kontrol için Table Editor > availability tablosuna
-- bak, her günün times sütununda 09:00'dan 21:00'a kadar saatler
-- olmalı. Admin panelinden istemediğin gün/saatleri kapatabilirsin.
-- ================================================================
