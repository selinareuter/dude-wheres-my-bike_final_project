
-- Dude, Where's My Bike?
-- Core SQL analysis
-- Canonical source: analysis_ready_v2.csv
-- Table: bike_theft

-- 1. Dataset overview
SELECT
    COUNT(*) AS total_reports,
    MIN(DATE(offence_start_date)) AS earliest_date,
    MAX(DATE(offence_start_date)) AS latest_date,
    COUNT(DISTINCT lor) AS planning_areas_represented,
    COUNT(DISTINCT district_id) AS districts_represented
FROM bike_theft;

-- 2. Monthly report counts
SELECT
    STRFTIME('%Y-%m', offence_start_date) AS year_month,
    COUNT(*) AS reported_incidents
FROM bike_theft
GROUP BY
    STRFTIME('%Y-%m', offence_start_date)
ORDER BY
    year_month;

-- 3. Matching 2025–2026 YTD comparison
WITH comparable_reports AS (
    SELECT
        CAST(
            STRFTIME('%Y', offence_start_date)
            AS INTEGER
        ) AS year
    FROM bike_theft
    WHERE
        DATE(offence_start_date)
            BETWEEN '2025-01-01' AND '2025-08-08'
        OR
        DATE(offence_start_date)
            BETWEEN '2026-01-01' AND '2026-08-08'
),

year_counts AS (
    SELECT
        year,
        COUNT(*) AS reported_incidents
    FROM comparable_reports
    GROUP BY year
),

year_comparison AS (
    SELECT
        year,
        reported_incidents,
        LAG(reported_incidents) OVER (
            ORDER BY year
        ) AS previous_year_reports
    FROM year_counts
)

SELECT
    year,
    reported_incidents,
    reported_incidents
        - previous_year_reports AS difference,
    ROUND(
        100.0
        * (reported_incidents - previous_year_reports)
        / previous_year_reports,
        1
    ) AS percentage_change
FROM year_comparison
ORDER BY year;

-- 4. Weekday analysis
WITH daily_counts AS (
    SELECT
        DATE(offence_start_date) AS offence_date,
        CAST(
            STRFTIME('%w', offence_start_date)
            AS INTEGER
        ) AS weekday_number,
        COUNT(*) AS reported_incidents
    FROM bike_theft
    GROUP BY
        DATE(offence_start_date)
)

SELECT
    CASE weekday_number
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS weekday_name,

    COUNT(*) AS calendar_days,
    SUM(reported_incidents) AS total_reports,
    ROUND(
        AVG(reported_incidents),
        1
    ) AS average_reports_per_day

FROM daily_counts

GROUP BY
    weekday_number

ORDER BY
    CASE weekday_number
        WHEN 1 THEN 1
        WHEN 2 THEN 2
        WHEN 3 THEN 3
        WHEN 4 THEN 4
        WHEN 5 THEN 5
        WHEN 6 THEN 6
        WHEN 0 THEN 7
    END;

-- 5. Bicycle-type ranking
WITH completed_reports AS (
    SELECT
        CASE bicycle_type
            WHEN 'Herrenfahrrad'
                THEN 'Men''s bicycle'
            WHEN 'Damenfahrrad'
                THEN 'Women''s bicycle'
            WHEN 'Fahrrad'
                THEN 'Bicycle (unspecified)'
            WHEN 'Mountainbike'
                THEN 'Mountain bike'
            WHEN 'Kinderfahrrad'
                THEN 'Children''s bicycle'
            WHEN 'Rennrad'
                THEN 'Road bicycle'
            WHEN 'diverse Fahrräder'
                THEN 'Various bicycles'
            WHEN 'Trekkingrad'
                THEN 'Trekking bicycle'
            WHEN 'Citybike'
                THEN 'City bicycle'
            WHEN 'Lastenfahrrad'
                THEN 'Cargo bicycle'
            WHEN 'Hollandrad'
                THEN 'Dutch-style bicycle'
            WHEN 'Klapprad'
                THEN 'Folding bicycle'
            WHEN 'BMX'
                THEN 'BMX'
            ELSE bicycle_type
        END AS bicycle_type
    FROM bike_theft
    WHERE attempt = 'Nein'
),

type_counts AS (
    SELECT
        bicycle_type,
        COUNT(*) AS reported_incidents
    FROM completed_reports
    GROUP BY bicycle_type
)

SELECT
    DENSE_RANK() OVER (
        ORDER BY reported_incidents DESC
    ) AS type_rank,
    bicycle_type,
    reported_incidents,
    ROUND(
        100.0 * reported_incidents
        / SUM(reported_incidents) OVER (),
        1
    ) AS share_pct
FROM type_counts
ORDER BY type_rank;

-- 6. Financial analysis by bicycle type
WITH eligible_reports AS (
    SELECT
        CASE bicycle_type
            WHEN 'Herrenfahrrad'
                THEN 'Men''s bicycle'
            WHEN 'Damenfahrrad'
                THEN 'Women''s bicycle'
            WHEN 'Fahrrad'
                THEN 'Bicycle (unspecified)'
            WHEN 'Mountainbike'
                THEN 'Mountain bike'
            WHEN 'Kinderfahrrad'
                THEN 'Children''s bicycle'
            WHEN 'Rennrad'
                THEN 'Road bicycle'
            WHEN 'diverse Fahrräder'
                THEN 'Various bicycles'
            WHEN 'Trekkingrad'
                THEN 'Trekking bicycle'
            WHEN 'Citybike'
                THEN 'City bicycle'
            WHEN 'Lastenfahrrad'
                THEN 'Cargo bicycle'
            WHEN 'Hollandrad'
                THEN 'Dutch-style bicycle'
            WHEN 'Klapprad'
                THEN 'Folding bicycle'
            WHEN 'BMX'
                THEN 'BMX'
            ELSE bicycle_type
        END AS bicycle_type,

        reported_damage_eur

    FROM bike_theft

    WHERE
        attempt = 'Nein'
        AND is_cellar_burglary = 0
        AND reported_damage_eur > 0
),

ordered_values AS (
    SELECT
        bicycle_type,
        reported_damage_eur,

        ROW_NUMBER() OVER (
            PARTITION BY bicycle_type
            ORDER BY reported_damage_eur
        ) AS value_position,

        COUNT(*) OVER (
            PARTITION BY bicycle_type
        ) AS record_count

    FROM eligible_reports
),

type_summary AS (
    SELECT
        bicycle_type,
        COUNT(*) AS reports,

        ROUND(
            AVG(
                CASE
                    WHEN value_position IN (
                        (record_count + 1) / 2,
                        (record_count + 2) / 2
                    )
                    THEN reported_damage_eur
                END
            ),
            1
        ) AS median_damage_eur,

        ROUND(
            AVG(reported_damage_eur),
            1
        ) AS mean_damage_eur,

        SUM(reported_damage_eur)
            AS total_damage_eur

    FROM ordered_values

    GROUP BY bicycle_type
    HAVING COUNT(*) >= 20
)

SELECT
    DENSE_RANK() OVER (
        ORDER BY median_damage_eur DESC
    ) AS median_rank,

    bicycle_type,
    reports,
    median_damage_eur,
    mean_damage_eur,
    total_damage_eur

FROM type_summary
ORDER BY median_rank;

-- 7. LOR lookup table
DROP TABLE IF EXISTS lor_lookup;

CREATE TABLE lor_lookup AS
SELECT DISTINCT
    lor,
    district_id,
    district_name,
    forecast_area_id,
    forecast_area_name,
    district_region_id,
    district_region_name,
    planning_area_name
FROM bike_theft;

CREATE UNIQUE INDEX
    idx_lor_lookup_code
ON lor_lookup(lor);

-- 8. District ranking through an SQL join
SELECT
    lookup.district_name,
    COUNT(*) AS reported_incidents,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        1
    ) AS share_pct,

    DENSE_RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS report_rank

FROM bike_theft AS incidents

INNER JOIN lor_lookup AS lookup
    ON incidents.lor = lookup.lor

GROUP BY
    lookup.district_name

ORDER BY
    report_rank;
