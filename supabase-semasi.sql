-- ================================================================
-- Gökhan Kılıç - Matematik & Geometri Özel Ders Sitesi
-- 2. GÜNCELLEME: Öğrencinin randevu tarih/saatini değiştirebilmesi
-- Bunu Supabase SQL Editor'de "Run" ile çalıştır.
-- ================================================================

-- Bir tarihte dolu olan saatleri, belirli bir randevu id'sini
-- hariç tutarak döndürür (randevu değiştirilirken kendi eski
-- saatinin "dolu" görünmemesi için kullanılır).
create or replace function public.get_booked_times_excluding(p_date date, p_exclude_id uuid)
returns table(time_slot text)
language sql security definer set search_path = public as $$
  select time_slot from bookings
  where date = p_date and status <> 'iptal' and id <> p_exclude_id;
$$;
grant execute on function public.get_booked_times_excluding(date, uuid) to anon, authenticated;

-- Öğrencinin kendi randevusunun tarih/saatini değiştirmesi.
-- Kurallar: telefon eşleşmeli, eski randevuya 2 günden az kalmamalı,
-- yeni saat dolu olmamalı. Değişiklik sonrası durum "beklemede"ye
-- döner (hoca yeni saati tekrar onaylamalı).
create or replace function public.reschedule_booking(
  p_id uuid, p_phone text, p_new_date date, p_new_time text
) returns bookings
language plpgsql security definer set search_path = public as $$
declare
  v_row bookings;
  v_taken boolean;
begin
  select * into v_row from bookings where id = p_id and phone = p_phone;

  if v_row.id is null then
    raise exception 'NOT_FOUND';
  end if;

  if v_row.date < (current_date + 2) then
    raise exception 'TOO_LATE';
  end if;

  select exists(
    select 1 from bookings
    where date = p_new_date and time_slot = p_new_time
      and status <> 'iptal' and id <> p_id
  ) into v_taken;

  if v_taken then
    raise exception 'SLOT_TAKEN';
  end if;

  update bookings
  set date = p_new_date, time_slot = p_new_time, status = 'beklemede'
  where id = p_id
  returning * into v_row;

  return v_row;
end;
$$;
grant execute on function public.reschedule_booking(uuid, text, date, text) to anon, authenticated;

-- ================================================================
-- Tamamlandı.
-- ================================================================