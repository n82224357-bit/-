-- Цель проекта — мотивировать людей становиться донорами и делать регулярные донации. Для этого важно понимать, какие факторы влияют на активность доноров и какими могут быть стратегии для их мотивации.

-- Определим регионы с наибольшим количеством зарегистрированных доноров.
select count(id), region
from donorsearch.user_anon_data
group by region
order by count(id) DESC;

--Изучим динамику общего количества донаций в месяц за 2022 и 2023 годы
select count(id), extract(month from donation_date::timestamp) as number_of_month
from donorsearch.donation_anon
where extract(year from donation_date::timestamp) = 2022
group by number_of_month;

select count(id), extract(month from donation_date::timestamp) as number_of_month
from donorsearch.donation_anon
where extract(year from donation_date::timestamp) = 2023
group by number_of_month;

select count(id), extract(month from donation_date::timestamp) as number_of_month
from donorsearch.donation_anon
where donation_date BETWEEN '2022-01-01' AND '2023-12-31'
group by number_of_month
order by number_of_month;

-- Определим наиболее активных доноров в системе, учитывая только данные о зарегистрированных и подтвержденных донациях
select id, confirmed_donations
from donorsearch.user_anon_data
group by id
order by confirmed_donations desc
LIMIT 10;


--Оценим, как система бонусов влияет на зарегистрированные в системе донации
with donor_activity as (
    select 
        user_anon_data.id,
        user_anon_data.confirmed_donations,
        COALESCE(user_anon_bonus.user_bonus_count, 0) AS user_bonus_count
    from donorsearch.user_anon_data
    left join donorsearch.user_anon_bonus on donorsearch.user_anon_data.id = donorsearch.user_anon_bonus.user_id
)
select 
    case 
        WHEN user_bonus_count > 0 THEN 'Получили бонусы'
        ELSE 'Не получали бонусы'
    END AS статус_бонусов,
    COUNT(id) AS количество_доноров,
    AVG(confirmed_donations) AS среднее_количество_донаций
FROM donor_activity
GROUP BY статус_бонусов;


--Исследуем вовлечение новых доноров через социальные сети. Узнаем, сколько по каким каналам пришло доноров, и среднее количество донаций по каждому каналу.
SELECT 
    CASE 
        WHEN autho_vk THEN 'ВКонтакте'
        WHEN autho_ok THEN 'Одноклассники'
        WHEN autho_tg THEN 'Телеграм'
        WHEN autho_yandex THEN 'autho_yandex'
        WHEN autho_google THEN 'Google-аккаунт'
        ELSE 'нет социальной сети'
    END AS социальная_сеть,
    COUNT(id) AS количество_доноров,
    AVG(confirmed_donations) AS среднее_количество_донаций
FROM donorsearch.user_anon_data
GROUP BY социальная_сеть;

-- Сравним активность однократных доноров со средней активностью повторных доноров 
WITH donor_activity AS (
  SELECT user_id,
         COUNT(*) AS total_donations,
         (MAX(donation_date) - MIN(donation_date)) AS activity_duration_days,
         (MAX(donation_date) - MIN(donation_date)) / (COUNT(*) - 1) AS avg_days_between_donations,
         EXTRACT(YEAR FROM MIN(donation_date)) AS first_donation_year,
         EXTRACT(YEAR FROM AGE(CURRENT_DATE, MIN(donation_date))) AS years_since_first_donation
  FROM donorsearch.donation_anon
  GROUP BY user_id
  HAVING COUNT(*) > 1
)
SELECT first_donation_year,
       CASE 
           WHEN total_donations BETWEEN 2 AND 3 THEN '2-3 донации'
           WHEN total_donations BETWEEN 4 AND 5 THEN '4-5 донаций'
           ELSE '6 и более донаций'
       END AS donation_frequency_group,
       COUNT(user_id) AS donor_count,
       AVG(total_donations) AS avg_donations_per_donor,
       AVG(activity_duration_days) AS avg_activity_duration_days,
       AVG(avg_days_between_donations) AS avg_days_between_donations,
       AVG(years_since_first_donation) AS avg_years_since_first_donation
FROM donor_activity
GROUP BY first_donation_year, donation_frequency_group
ORDER BY first_donation_year, donation_frequency_group;
  
-- проанализируем планирования доноров и их реальную активность
WITH planned_donations AS (
  SELECT DISTINCT user_id, donation_date, donation_type
  FROM donorsearch.donation_plan
),
actual_donations AS (
  SELECT DISTINCT user_id, donation_date
  FROM donorsearch.donation_anon
),
planned_vs_actual AS (
  SELECT
    pd.user_id,
    pd.donation_date AS planned_date,
    pd.donation_type,
    CASE WHEN ad.user_id IS NOT NULL THEN 1 ELSE 0 END AS completed
  FROM planned_donations pd
  LEFT JOIN actual_donations ad ON pd.user_id = ad.user_id AND pd.donation_date = ad.donation_date
)
SELECT
  donation_type,
  COUNT(*) AS total_planned_donations,
  SUM(completed) AS completed_donations,
  ROUND(SUM(completed) * 100.0 / COUNT(*), 2) AS completion_rate
FROM planned_vs_actual
GROUP BY donation_type;
