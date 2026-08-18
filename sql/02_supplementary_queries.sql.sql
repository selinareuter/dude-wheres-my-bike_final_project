
-- Dude, Where's My Bike?
-- Supplementary exploratory SQL queries
-- Canonical source: analysis_ready_v2.csv

-- 1. Summary of rounded reported-damage values
WITH eligible_values AS (
    SELECT
        reported_damage_eur
    FROM bike_theft
    WHERE
        attempt = 'Nein'
        AND is_cellar_burglary = 0
        AND reported_damage_eur > 0
)

SELECT
    COUNT(*) AS positive_value_records,

    SUM(
        CASE
            WHEN reported_damage_eur IN (500, 1000, 1500)
            THEN 1
            ELSE 0
        END
    ) AS records_at_500_1000_1500,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN reported_damage_eur IN (500, 1000, 1500)
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS selected_round_values_pct,

    SUM(
        CASE
            WHEN reported_damage_eur % 100 = 0
            THEN 1
            ELSE 0
        END
    ) AS multiples_of_100,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN reported_damage_eur % 100 = 0
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS multiples_of_100_pct,

    SUM(
        CASE
            WHEN reported_damage_eur % 500 = 0
            THEN 1
            ELSE 0
        END
    ) AS multiples_of_500,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN reported_damage_eur % 500 = 0
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS multiples_of_500_pct

FROM eligible_values;

-- 2. Most common exact reported-damage values
SELECT
    reported_damage_eur,
    COUNT(*) AS records,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        1
    ) AS share_pct
FROM bike_theft
WHERE
    attempt = 'Nein'
    AND is_cellar_burglary = 0
    AND reported_damage_eur > 0
GROUP BY
    reported_damage_eur
ORDER BY
    records DESC
LIMIT 15;

-- 3. Weekend versus weekday patterns by district
WITH RECURSIVE date_bounds AS (
    SELECT
        MIN(DATE(offence_start_date)) AS first_date,
        MAX(DATE(offence_start_date)) AS last_date
    FROM bike_theft
),

calendar(calendar_date) AS (
    SELECT first_date
    FROM date_bounds

    UNION ALL

    SELECT DATE(calendar_date, '+1 day')
    FROM calendar, date_bounds
    WHERE calendar_date < last_date
),

calendar_totals AS (
    SELECT
        SUM(
            CASE
                WHEN STRFTIME('%w', calendar_date)
                    IN ('0', '6')
                THEN 1
                ELSE 0
            END
        ) AS weekend_days,

        SUM(
            CASE
                WHEN STRFTIME('%w', calendar_date)
                    NOT IN ('0', '6')
                THEN 1
                ELSE 0
            END
        ) AS weekday_days
    FROM calendar
),

district_counts AS (
    SELECT
        district_name,

        SUM(
            CASE
                WHEN STRFTIME('%w', offence_start_date)
                    IN ('0', '6')
                THEN 1
                ELSE 0
            END
        ) AS weekend_reports,

        SUM(
            CASE
                WHEN STRFTIME('%w', offence_start_date)
                    NOT IN ('0', '6')
                THEN 1
                ELSE 0
            END
        ) AS weekday_reports

    FROM bike_theft
    GROUP BY district_name
)

SELECT
    district_name,
    weekday_reports,
    weekend_reports,

    ROUND(
        1.0 * weekday_reports / weekday_days,
        1
    ) AS weekday_average,

    ROUND(
        1.0 * weekend_reports / weekend_days,
        1
    ) AS weekend_average,

    ROUND(
        100.0 * (
            1.0 * weekend_reports / weekend_days
            - 1.0 * weekday_reports / weekday_days
        )
        / (1.0 * weekday_reports / weekday_days),
        1
    ) AS weekend_difference_pct

FROM district_counts
CROSS JOIN calendar_totals

ORDER BY weekend_difference_pct DESC;
