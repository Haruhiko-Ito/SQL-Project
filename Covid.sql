-- Select Data we are going to be using
-- Note, there is data where location = continent (not country). Get rid of those data
Select location, date, total_cases, new_cases, total_deaths, population
From [covid project]..CovidDeaths
Order by 1, 2;

-- Total Cases vs. Total Deaths
Select location, date, total_cases, total_deaths, (total_deaths/total_cases * 100) as DeathPercentage
FROM [covid project]..CovidDeaths
Where location like '%korea%'
And continent is not null
Order by 1, 2
;

-- Countries with highest infection rate relative to population
Select location, population, MAX(total_cases) as HighestInfectionCount, MAX((total_cases/population) * 100) as PercentPopulationInfected
From [covid project]..CovidDeaths
-- WHERE location like '%korea%'
WHERE continent is not null
Group By location, population
order by PercentPopulationInfected DESC
;

-- Countries with highest death rate relative to population
Select location, MAX(cast(total_deaths as int)) as TotalDeathCount
From [covid project]..CovidDeaths
WHERE continent is not null
Group by location
Order By TotalDeathCount DESC
;



-- Looking at Data based on continent
Select continent, MAX(cast(total_deaths as int)) as TotalDeathCount
From [covid project]..CovidDeaths
WHERE continent is not null
Group by continent
Order By TotalDeathCount DESC
;

-- GLOBAL NUMBERS

Select date,
	SUM(new_cases) as TotalCases,
	SUM(cast(new_deaths as int)) as TotalDeaths,
	SUM(cast(new_deaths as int))/SUM(new_cases) * 100 as PercentDeathPerCase
From [covid project]..CovidDeaths
Where continent is not null
Group By date
Order By 1, 2
;


-- Joining both tables
Select *
From [covid project]..CovidDeaths as cd
Join [covid project]..CovidVaccinations as cv
	ON cd.location = cv.location
	and cd.date = cv.date
;


-- Total Population vs Total Vaccination
Select cd.continent, cd.location, cd.date, cd.population, cv.total_vaccinations
From [covid project]..CovidDeaths as cd
Join [covid project]..CovidVaccinations as cv
	ON cd.location = cv.location
	and cd.date = cv.date
Where cd.continent is not null
Order By 1, 2, 3
;




-- Total Population, Running sum of new vaccinations for each country per day
Select cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
	SUM(convert(int, cv.new_vaccinations)) Over (Partition by cd.location Order by cd.location, cd.date) as CumSumVacc
From [covid project]..CovidDeaths as cd
Join [covid project]..CovidVaccinations as cv
	ON cd.location = cv.location
	and cd.date = cv.date
Where cd.continent is not null
Order By 2, 3
;

-- Want to add column for #ppl vaccinated per population (as percentage)
-- Need to use CumSumVacc, but can't simply add another column on the code above (need to CTE or Temp)
-- USE CTE

With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, CumSumVacc)
as
(
Select cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
	SUM(convert(int, cv.new_vaccinations)) Over (Partition by cd.location Order by cd.location, cd.date) as CumSumVacc
From [covid project]..CovidDeaths as cd
Join [covid project]..CovidVaccinations as cv
	ON cd.location = cv.location
	and cd.date = cv.date
Where cd.continent is not null
--Order By 2, 3
)

Select *, CumSumVacc/population * 100
From PopvsVac
WHERE New_Vaccinations is not null
Order by 1, 2
;

-- Temp Table
DROP Table if exists percentpopulationvaccinated ;

Create Table #percentpopulationvaccinated (
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
CumSumVacc numeric
)
Insert Into #percentpopulationvaccinated
Select cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
	SUM(convert(int, cv.new_vaccinations)) Over (Partition by cd.location Order by cd.location, cd.date) as CumSumVacc
From [covid project]..CovidDeaths as cd
Join [covid project]..CovidVaccinations as cv
	ON cd.location = cv.location
	and cd.date = cv.date
Where cd.continent is not null
--Order By 2, 3

Select *, (CumSumVacc/Population)*100 as Population_Vaccinated
From #percentpopulationvaccinated
WHERE New_vaccinations is not null
Order By 1, 2
;


-- Creating view to store data for later visualization
Drop View percentpopulationvaccinated ;

Create View percentpopulationvaccinated as 
Select cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
	SUM(convert(int, cv.new_vaccinations)) Over (Partition by cd.location Order by cd.location, cd.date) as CumSumVacc
From [covid project]..CovidDeaths as cd
Join [covid project]..CovidVaccinations as cv
	ON cd.location = cv.location
	and cd.date = cv.date
Where cd.continent is not null
	and new_vaccinations is not null
;

-- Now percentpopulationvaccinated is stored permanently. Therefore, can be read separately
Select *
From percentpopulationvaccinated
Order by continent, location
;