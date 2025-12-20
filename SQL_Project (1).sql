create database project;

use project;

-- 1. What is the total emission per country for the most recent year available?

SELECT country, SUM(emission) AS total_emission
FROM emission_3
WHERE year = (SELECT MAX(year) FROM emission_3)
GROUP BY country
ORDER BY total_emission DESC;

-- 2. What are the top 5 countries by GDP in the most recent year?

SELECT country,SUM(value) AS value_sum 
FROM gdp_3
WHERE year=(SELECT MAX(year) FROM gdp_3) 
GROUP BY country 
ORDER BY value_sum DESC limit 5;

-- 3. Compare energy production and consumption by country and year. 

SELECT p.country,p.year,
SUM(p.production) AS total_production,
SUM(c.consumption) AS total_consumption,
(SUM(p.production)-SUM(c.consumption)) AS difference
FROM production_3 AS p 
JOIN consum_3 AS c 
ON p.country = c.country 
AND p.year = c.year
GROUP BY p.country,p.year
ORDER BY p.country,p.year;

-- 4. Which energy types contribute most to emissions across all countries?
alter table emission_3 rename column `energy type` to energy_type;

SELECT energy_type,
SUM(emission) as total_emission
FROM emission_3
GROUP BY energy_type
ORDER BY total_emission DESC;

-- 5. How have global emissions changed year over year?

SELECT year,SUM(emission) AS total_emission,
SUM(emission) - LAG(SUM(emission)) OVER (ORDER BY year) AS year_over_year_change FROM emission_3
GROUP BY year 
ORDER BY total_emission;

-- 6. What is the trend in GDP for each country over the given years?

SELECT country,year,value,
(value-ifnull(LAG(value) over 
(PARTITION BY country ORDER BY year),value)) AS change_in_gdp 
FROM gdp_3
ORDER BY country,year;

-- 7. How has population growth affected total emissions in each country?

SELECT p.countries,p.year,p.value as population,
SUM(e.emission) AS total_emission
FROM population_3 AS p 
JOIN emission_3 AS e 
ON p.countries=e.country AND p.year=e.year 
GROUP BY p.countries,p.year,p.value
ORDER BY p.countries,p.year;

-- 8. Has energy consumption increased or decreased over the years for major economies?

WITH top5_countries AS (
SELECT country
FROM gdp_3
GROUP BY country
ORDER BY sum(value) DESC
LIMIT 5),
consumption_diff AS (
SELECT country,year,
SUM(consumption) AS total_consumption,
SUM(consumption) - LAG(SUM(consumption))
OVER (PARTITION BY country ORDER BY year)
AS yearly_change
FROM consum_3
WHERE country IN (SELECT country FROM top5_countries)
GROUP BY country,year 
HAVING year in (2020,2023)
)
SELECT country,total_consumption,yearly_change,
CASE
WHEN yearly_change > 0 THEN 'Increased'
WHEN yearly_change < 0 THEN 'Decreased'
ELSE 'No Change'
END AS result
FROM consumption_diff
WHERE yearly_change IS NOT NULL;

-- 9. What is the average yearly change in emissions per capita for each country?

SELECT e.country,e.year,e.per_capita_emission,
e.per_capita_emission - ifnull(LAG(e.per_capita_emission) 
OVER (PARTITION BY e.country ORDER BY e.year),e.per_capita_emission) AS change_in_EPC,
avg_table.avg_emission AS average_EPC
FROM emission_3 e
JOIN(
	SELECT country,AVG(per_capita_emission) AS avg_emission 
    FROM emission_3
    GROUP BY country
) avg_table 
ON e.country = avg_table.country
ORDER BY e.country,e.year DESC;

-- 10.What is the emission-to-GDP ratio for each country by year? 

SELECT e.country,
e.year,
e.emission,
g.value,
(e.emission/g.value) AS emission_to_gdp_ratio
FROM emission_3 e
JOIN gdp_3 g
ON e.country=g.country AND e.year=g.year
ORDER BY e.country,e.year;  

-- 11. What is the energy consumption per capita for each country over the last decade?

SELECT c.country,
SUM(c.consumption) AS total_consum,
ROUND(AVG(p.value),0) AS avg_pop,
SUM(c.consumption)/ROUND(AVG(p.value),0)
AS consumption_per_capita
FROM consum_3 c
JOIN population_3 p
ON c.country = p.countries 
GROUP BY c.country
ORDER BY consumption_per_capita DESC;

-- 12. How does energy production per capita vary across countries?

SELECT p.country,p.year,
(p.production/p1.value) AS production_per_capita 
FROM production_3 p 
JOIN population_3 p1
ON p.country = p1.countries AND p.year = p1.year
ORDER BY p.country,p.year;

-- 13. Which countries have the highest energy consumption relative to GDP?

SELECT c.country,c.year,
(c.consumption/g.value) AS consumption_to_gdp_ratio
FROM consum_3 c
JOIN gdp_3 g
ON c.country = g.country AND c.year = g.year
ORDER BY consumption_to_gdp_ratio DESC;

-- 14. What is the correlation between GDP growth and energy production growth?

SELECT g.country,g.year,
(g.value - LAG(g.value) OVER (PARTITION BY g.country ORDER BY g.year)) / 
NULLIF(LAG(g.value) OVER (PARTITION BY g.country ORDER BY g.year),0) AS gdp_growth,
(p.production - lag(p.production) over (PARTITION BY p.country ORDER BY p.year))/
NULLIF(LAG(p.production) OVER (PARTITION BY p.country ORDER BY p.year),0) AS production_growth
FROM gdp_3 g
JOIN production_3 p 
ON g.country = p.country AND g.year = p.year
ORDER BY g.country, g.year;

-- 15. What are the top 10 countries by population and how do their emissions compare?

SELECT p.countries, SUM(p.value) AS total_population,
SUM(e.emission) AS total_emission
FROM population_3 p 
JOIN emission_3 e
ON p.countries = e.country 
GROUP BY p.countries
ORDER BY total_population DESC
LIMIT 10;

-- 16. Which countries have improved (reduced) their per capita emissions the most over the last decade?

WITH yearly_emission AS (
    SELECT 
        country,
        year,
        SUM(per_capita_emission)
 AS total_per_capita
    FROM emission_3
    WHERE year IN (2020, 2023)
    GROUP BY country, year
),
emission_diff AS (
    SELECT
        country,
        year,
        total_per_capita - LAG(total_per_capita)
        OVER (PARTITION BY country ORDER BY year)
        AS diff
    FROM yearly_emission
)
SELECT country
FROM emission_diff
WHERE diff < 0
ORDER BY diff ASC;

-- 17. What is the global share (%) of emissions by country?

SELECT country,
SUM(emission) AS total_emission,
(SUM(emission) *  100.0 / (SELECT SUM(emission) FROM emission_3)) AS global_share_percent
FROM emission_3 
GROUP BY country
ORDER BY global_share_percent DESC;

-- 18. What is the global average GDP, emission, and population by year?

SELECT g.year,
AVG(g.value) AS avg_gdp,
AVG(e.emission) AS avg_emission,
AVG(p.value) AS avg_population
FROM gdp_3 g
JOIN emission_3 e ON g.country = e.country AND g.year = e.year
JOIN population_3 p ON g.country = p.countries AND g.year = p.year
GROUP BY g.year
ORDER BY g.year;
